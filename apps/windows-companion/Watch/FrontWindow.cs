using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

namespace LockIn.Companion.Watch;

/// <summary>
/// Reads the window the user is looking at. Only reads names; never reads what is on screen.
/// </summary>
public static class FrontWindow
{
    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")] private static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern bool ShowWindow(IntPtr hWnd, int cmd);
    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool attach);
    [DllImport("kernel32.dll")] private static extern uint GetCurrentThreadId();
    private const int SwRestore = 9;

    public sealed record Snapshot(IntPtr Handle, int ProcessId, string Process, string Title);

    public static Snapshot? Current()
    {
        var handle = GetForegroundWindow();
        if (handle == IntPtr.Zero) return null;
        GetWindowThreadProcessId(handle, out var pid);
        var sb = new StringBuilder(256);
        GetWindowText(handle, sb, sb.Capacity);
        string process;
        try { process = Process.GetProcessById((int)pid).ProcessName; }
        catch (Exception) { process = ""; }
        return new Snapshot(handle, (int)pid, process, sb.ToString());
    }

    /// <summary>
    /// Brings a window back to the front (restoring it if it was minimized). Windows only lets a program
    /// take the front when the user just used it; a click on the buddy normally counts. If Windows still
    /// says no, the input of the two threads is joined for a moment, the usual way around that rule.
    /// Returns true when the window ended up in front. Never closes anything.
    /// </summary>
    public static bool BringToFront(IntPtr handle)
    {
        if (handle == IntPtr.Zero || !IsWindow(handle)) return false;
        if (IsIconic(handle)) ShowWindow(handle, SwRestore);
        if (SetForegroundWindow(handle) || GetForegroundWindow() == handle) return true;

        var front = GetForegroundWindow();
        var frontThread = front == IntPtr.Zero ? 0 : GetWindowThreadProcessId(front, out _);
        var me = GetCurrentThreadId();
        if (frontThread == 0 || frontThread == me) return false;
        AttachThreadInput(me, frontThread, true);
        try
        {
            BringWindowToTop(handle);
            SetForegroundWindow(handle);
        }
        finally { AttachThreadInput(me, frontThread, false); }
        return GetForegroundWindow() == handle;
    }
}

/// <summary>
/// Remembers the last window the user worked in (an editor, Word, a browser tab on Docs), so
/// "Back to work" has somewhere to go. Pure bookkeeping: the watcher feeds it every second.
/// </summary>
public sealed class WorkWindowMemory
{
    /// <summary>Seconds (watcher ticks) a window must stay in front before it counts, so passing flashes do not.</summary>
    public const int DwellTicks = 3;

    private FrontWindow.Snapshot? candidate;
    private int candidateTicks;

    public FrontWindow.Snapshot? Last { get; private set; }

    public void Clear()
    {
        Last = candidate = null;
        candidateTicks = 0;
    }

    /// <summary>Called once a second with the front window. It becomes the work window after staying in front.</summary>
    public void Seen(FrontWindow.Snapshot? front, int ownProcessId)
    {
        if (!Distractions.IsWorkWindow(front, ownProcessId))
        {
            candidate = null;
            candidateTicks = 0;
            return;
        }
        if (candidate is not null && candidate.Handle == front!.Handle) candidateTicks++;
        else { candidate = front; candidateTicks = 1; }
        if (candidateTicks >= DwellTicks) Last = front;
    }

    /// <summary>
    /// The window to bring back, or null. When the work window IS the window in front (the same browser
    /// window, now on a Shorts tab), bringing it forward would change nothing, so there is no target.
    /// </summary>
    public IntPtr? TargetFor(FrontWindow.Snapshot? front) =>
        Last is null || (front is not null && front.Handle == Last.Handle) ? null : Last.Handle;
}
