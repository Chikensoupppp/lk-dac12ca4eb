using System.Runtime.InteropServices;
using System.Text;

namespace LockIn.Companion.Watch;

/// <summary>A window's rectangle on the virtual screen (all monitors together).</summary>
public readonly record struct Box(int Left, int Top, int Right, int Bottom)
{
    public long Area => Math.Max(0, Right - Left) * (long)Math.Max(0, Bottom - Top);
    public Box Clip(Box other) => new(Math.Max(Left, other.Left), Math.Max(Top, other.Top), Math.Min(Right, other.Right), Math.Min(Bottom, other.Bottom));
}

/// <summary>
/// Every window the user can actually see, on every monitor, not only the one in focus. A video playing on
/// the second monitor, a game beside the editor, or a browser window half hidden behind another all count:
/// focus is not the only way to be distracted. A window counts as visible when it is open (not minimized, not
/// on another virtual desktop) and enough of it shows through the windows above it. Reads names and sizes only.
/// </summary>
public static class VisibleWindows
{
    /// <summary>A sliver that shows less than this, or less than a quarter of the window, is not something being watched.</summary>
    public const long MinVisiblePixels = 60_000;
    public const int MinVisiblePercent = 25;

    public sealed record Window(IntPtr Handle, int ProcessId, string Process, string Title, Box Bounds);

    /// <summary>How many pixels of <paramref name="target"/> show once every box in <paramref name="above"/> (the windows in front of it) is cut out.</summary>
    public static long VisibleArea(Box target, IReadOnlyList<Box> above)
    {
        if (target.Area == 0) return 0;
        var covers = new List<Box>();
        var xs = new SortedSet<int> { target.Left, target.Right };
        var ys = new SortedSet<int> { target.Top, target.Bottom };
        foreach (var box in above)
        {
            var c = target.Clip(box);
            if (c.Area == 0) continue;
            covers.Add(c);
            xs.Add(c.Left); xs.Add(c.Right); ys.Add(c.Top); ys.Add(c.Bottom);
        }
        if (covers.Count == 0) return target.Area;
        var x = xs.ToArray();
        var y = ys.ToArray();
        long visible = 0;
        for (var i = 0; i < x.Length - 1; i++)
            for (var j = 0; j < y.Length - 1; j++)
            {
                var covered = false;
                foreach (var c in covers)
                    if (c.Left <= x[i] && c.Right >= x[i + 1] && c.Top <= y[j] && c.Bottom >= y[j + 1]) { covered = true; break; }
                if (!covered) visible += (long)(x[i + 1] - x[i]) * (y[j + 1] - y[j]);
            }
        return visible;
    }

    public static bool Prominent(long visible, long total) =>
        total > 0 && visible >= MinVisiblePixels && visible * 100 >= total * MinVisiblePercent;

    /// <summary>Open windows, front to back. Skips minimized ones, other virtual desktops, tool and overlay windows, and Lock In itself.</summary>
    public static List<Window> Enumerate(int ownProcessId)
    {
        var processes = ProcessList.Snapshot();
        var result = new List<Window>();
        EnumProc each = (handle, _) =>
        {
            try { if (Describe(handle, ownProcessId, processes) is { } w) result.Add(w); }
            catch (Exception) { /* a window that vanished while being read */ }
            return true;
        };
        // This program is system-DPI aware (sized for the main screen's scale), so a window on a monitor with another
        // scale comes back stretched into that scale, and rectangles from two such monitors do not line up (a laptop
        // beside a 4K screen). For this thread only, ask for the real pixels, so "how much of this window shows" is
        // right on every monitor. Nothing else in the app changes.
        var previous = SetThreadDpiAwarenessContext(PerMonitorAwareV2);
        try { EnumWindows(each, IntPtr.Zero); }
        finally { if (previous != IntPtr.Zero) SetThreadDpiAwarenessContext(previous); }
        GC.KeepAlive(each);
        return result;
    }

    private static readonly IntPtr PerMonitorAwareV2 = new(-4); // DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2

    /// <summary>
    /// The distraction windows in view, most important first: the front window when it is one, then the others
    /// by how much of them shows. Lets the watch act on a distraction that is not focused (second monitor).
    /// </summary>
    public static List<FrontWindow.Snapshot> FindDistractions(FrontWindow.Snapshot? front, int ownProcessId)
    {
        var others = new List<(FrontWindow.Snapshot Snap, long Visible)>();
        var above = new List<Box>();
        foreach (var w in Enumerate(ownProcessId))
        {
            if (w.Handle != front?.Handle)
            {
                var snap = new FrontWindow.Snapshot(w.Handle, w.ProcessId, w.Process, w.Title);
                if (Distractions.IsDistraction(snap))
                {
                    var visible = VisibleArea(w.Bounds, above);
                    if (Prominent(visible, w.Bounds.Area)) others.Add((snap, visible));
                }
            }
            above.Add(w.Bounds);
        }
        var result = new List<FrontWindow.Snapshot>();
        if (Distractions.IsDistraction(front)) result.Add(front!);
        result.AddRange(others.OrderByDescending(o => o.Visible).Select(o => o.Snap));
        return result;
    }

    /// <summary>Every open browser window, any monitor.</summary>
    public static List<IntPtr> BrowserWindows(int ownProcessId) =>
        Enumerate(ownProcessId).Where(w => Distractions.IsBrowserProcess(w.Process)).Select(w => w.Handle).ToList();

    private const long WsExToolWindow = 0x80, WsExTransparent = 0x20, WsExNoActivate = 0x08000000;
    private const int GwlExStyle = -20, DwmCloaked = 14;

    private static Window? Describe(IntPtr handle, int ownProcessId, Dictionary<uint, ProcessList.Entry> processes)
    {
        if (!IsWindowVisible(handle) || IsIconic(handle)) return null;
        // Tool windows, click-through and no-activate overlays (Lock In's buddy, game overlays) are not what someone looks at.
        if ((GetWindowLongPtr(handle, GwlExStyle).ToInt64() & (WsExToolWindow | WsExTransparent | WsExNoActivate)) != 0) return null;
        if (DwmGetWindowAttribute(handle, DwmCloaked, out var cloaked, sizeof(int)) == 0 && cloaked != 0) return null; // another virtual desktop
        if (!GetWindowRect(handle, out var r)) return null;
        var bounds = new Box(r.Left, r.Top, r.Right, r.Bottom);
        if (bounds.Area < 400 || MonitorFromRect(ref r, 0) == IntPtr.Zero) return null; // tiny, or off every monitor
        GetWindowThreadProcessId(handle, out var pid);
        if (pid == ownProcessId) return null;
        var length = GetWindowTextLength(handle);
        var title = "";
        if (length > 0)
        {
            var sb = new StringBuilder(length + 1);
            GetWindowText(handle, sb, sb.Capacity);
            title = sb.ToString();
        }
        processes.TryGetValue(pid, out var entry);
        return new Window(handle, (int)pid, entry.Name ?? "", title, bounds);
    }

    private delegate bool EnumProc(IntPtr handle, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)] private struct Rect { public int Left, Top, Right, Bottom; }

    [DllImport("user32.dll")] private static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumProc proc, IntPtr lParam);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr handle);
    [DllImport("user32.dll")] private static extern bool IsIconic(IntPtr handle);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr handle, out Rect rect);
    [DllImport("user32.dll")] private static extern IntPtr MonitorFromRect(ref Rect rect, uint flags);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr handle, out uint processId);
    [DllImport("user32.dll")] private static extern int GetWindowTextLength(IntPtr handle);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetWindowText(IntPtr handle, StringBuilder text, int count);
    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")] private static extern IntPtr GetWindowLongPtr(IntPtr handle, int index);
    [DllImport("dwmapi.dll")] private static extern int DwmGetWindowAttribute(IntPtr handle, int attribute, out int value, int size);
}
