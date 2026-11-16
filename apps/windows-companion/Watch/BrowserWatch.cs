using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Automation;

namespace LockIn.Companion.Watch;

/// <summary>
/// Watches the browser in front without any extension, and feeds the same <see cref="GuardianSignal"/>
/// the extension would send. Every second it reads the front browser's address bar through Windows
/// accessibility (UI Automation). On a feed (YouTube Shorts, a Reddit feed) it counts new addresses (a new
/// Short, a new page) and how far the page scrolled; when the page's scroll position cannot be read, mouse
/// wheel notches stand in for it. Every 15 seconds the counts go to the scroll guard. It never stores or
/// sends an address: each one is only matched against the feed list and then dropped.
/// </summary>
public sealed class BrowserWatch : IDisposable
{
    private static readonly TimeSpan Tick = TimeSpan.FromSeconds(1);
    private const int ReportEveryTicks = 15;
    /// <summary>A wheel notch moves about 100 px; a screen is about 900 px.</summary>
    private const double ScreensPerNotch = 0.11;

    private readonly Action<GuardianSignal> report;
    private readonly Action<string>? log;
    private readonly CancellationTokenSource stop = new();
    private readonly Thread loop;
    private readonly WheelCounter wheel = new();

    // Cached per front window: walking a browser's accessibility tree is slow, so it is done once.
    private IntPtr cachedWindow;
    private AutomationElement? addressBar;
    private AutomationElement? document;

    private string? lastSite;
    private string? lastAddress;
    private double? lastScroll;
    private int scrolls;
    private double screens;
    private int items;
    private int ticks;

    /// <param name="log">Test helper only: one line per second about what was seen (site and counts, never the address).</param>
    public BrowserWatch(Action<GuardianSignal> report, Action<string>? log = null)
    {
        this.report = report;
        this.log = log;
        loop = new Thread(Run) { IsBackground = true, Name = "Nogbox browser watch" };
        loop.SetApartmentState(ApartmentState.MTA);
        loop.Start();
    }

    private void Run()
    {
        while (!stop.IsCancellationRequested)
        {
            try { Step(); }
            catch (Exception e) when (e is ElementNotAvailableException or COMException or InvalidOperationException)
            {
                Forget(); // the window closed or the tree changed under us; look again next second
            }
            stop.Token.WaitHandle.WaitOne(Tick);
        }
    }

    private void Step()
    {
        var notches = wheel.Take();
        var front = GetForegroundWindow();
        var site = front != IntPtr.Zero && IsBrowser(front) ? Classify(ReadAddress(front)) : null;

        log?.Invoke($"front={(front != IntPtr.Zero && IsBrowser(front) ? "browser" : "other")} site={site ?? "-"} addressRead={lastAddressRead is not null} notches={notches}");
        if (site is null)
        {
            Flush();
            lastSite = null;
            lastAddress = null;
            lastScroll = null;
            return;
        }

        var address = lastAddressRead;
        if (site != lastSite) { Flush(); lastAddress = address; lastScroll = null; }
        else if (address != lastAddress) { items++; lastAddress = address; lastScroll = null; }
        lastSite = site;

        var moved = ScreensMoved();
        if (moved is { } m) screens += m;
        else screens += notches * ScreensPerNotch;
        scrolls += notches;

        log?.Invoke($"  items={items} screens={screens:F2} scrollReadable={moved is not null}");
        if (++ticks >= ReportEveryTicks) Flush();
    }

    /// <summary>Sends what was counted since the last report (if a feed was in front) and starts over.</summary>
    private void Flush()
    {
        if (lastSite is { } site && ticks > 0)
            report(new GuardianSignal(site, Math.Min(scrolls, 200), Math.Min(screens, 50), Math.Min(items, 30), false));
        scrolls = 0;
        screens = 0;
        items = 0;
        ticks = 0;
    }

    private string? lastAddressRead;

    private string? ReadAddress(IntPtr window)
    {
        if (window != cachedWindow) Forget();
        cachedWindow = window;
        addressBar ??= FindAddressBar(AutomationElement.FromHandle(window));
        lastAddressRead = addressBar?.TryGetCurrentPattern(ValuePattern.Pattern, out var p) == true
            ? ((ValuePattern)p).Current.Value
            : null;
        return lastAddressRead;
    }

    /// <summary>
    /// The address bar is the first text box in the browser's own toolbar. Firefox names it "urlbar-input";
    /// Chromium browsers (Chrome, Edge, Brave, Vivaldi, Opera) put it before any text box of the page.
    /// </summary>
    private static AutomationElement? FindAddressBar(AutomationElement window)
    {
        var firefox = window.FindFirst(TreeScope.Descendants,
            new PropertyCondition(AutomationElement.AutomationIdProperty, "urlbar-input"));
        if (firefox is not null) return firefox;
        return window.FindFirst(TreeScope.Descendants, new AndCondition(
            new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Edit),
            new PropertyCondition(AutomationElement.IsValuePatternAvailableProperty, true)));
    }

    /// <summary>How many screens the page moved since the last second, or null when the page's scroll cannot be read.</summary>
    private double? ScreensMoved()
    {
        if (cachedWindow == IntPtr.Zero) return null;
        document ??= AutomationElement.FromHandle(cachedWindow).FindFirst(TreeScope.Descendants,
            new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Document));
        if (document is null || !document.TryGetCurrentPattern(ScrollPattern.Pattern, out var p)) return null;
        var scroll = (ScrollPattern)p;
        if (!scroll.Current.VerticallyScrollable) return null;
        var percent = scroll.Current.VerticalScrollPercent;
        var view = scroll.Current.VerticalViewSize; // the visible part, as a percent of the whole page
        var before = lastScroll;
        lastScroll = percent;
        if (before is null || view <= 0 || view >= 100) return 0;
        // The scrollable range is (100 / view - 1) screens long.
        return ScrollMath.Screens(before.Value, percent, view);
    }

    private void Forget()
    {
        cachedWindow = IntPtr.Zero;
        addressBar = null;
        document = null;
    }

    private static bool IsBrowser(IntPtr window)
    {
        GetWindowThreadProcessId(window, out var pid);
        try
        {
            using var process = Process.GetProcessById((int)pid);
            return Distractions.IsBrowserProcess(process.ProcessName);
        }
        catch (ArgumentException) { return false; }
        catch (InvalidOperationException) { return false; }
    }

    /// <summary>Same rules as the extension: "youtube-shorts", "reddit-feed", or null for every other page.</summary>
    public static string? Classify(string? address)
    {
        if (string.IsNullOrWhiteSpace(address)) return null;
        var text = address.Trim();
        if (!text.Contains("://")) text = "https://" + text;
        if (!Uri.TryCreate(text, UriKind.Absolute, out var uri)) return null;
        var host = uri.Host.ToLowerInvariant();
        var path = uri.AbsolutePath;
        if (host == "youtube.com" || host.EndsWith(".youtube.com"))
            return path.StartsWith("/shorts/", StringComparison.OrdinalIgnoreCase) ? "youtube-shorts" : null;
        if (host == "reddit.com" || host.EndsWith(".reddit.com"))
        {
            if (path.Contains("/comments/", StringComparison.OrdinalIgnoreCase)) return null; // reading one post is not a feed
            return RedditFeed.IsMatch(path) ? "reddit-feed" : null;
        }
        return null;
    }

    private static readonly System.Text.RegularExpressions.Regex RedditFeed = new(
        @"^\/(?:(?:best|hot|new|top|rising)\/?)?$|^\/r\/[^/]+\/?(?:(?:best|hot|new|top|rising)\/?)?$",
        System.Text.RegularExpressions.RegexOptions.IgnoreCase | System.Text.RegularExpressions.RegexOptions.CultureInvariant);

    public void Dispose()
    {
        stop.Cancel();
        wheel.Dispose();
    }

    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);

    /// <summary>
    /// Counts mouse wheel notches anywhere (a low-level mouse hook on its own thread). Only the count is kept:
    /// no position, no clicks, no keys.
    /// </summary>
    private sealed class WheelCounter : IDisposable
    {
        private const int WhMouseLl = 14;
        private const int WmMouseWheel = 0x020A;
        private const uint WmQuit = 0x0012;
        private readonly HookProc proc;
        private readonly Thread thread;
        private uint threadId;
        private int notches;

        public WheelCounter()
        {
            proc = Hook;
            thread = new Thread(() =>
            {
                threadId = GetCurrentThreadId();
                var hook = SetWindowsHookEx(WhMouseLl, proc, GetModuleHandle(null), 0);
                while (GetMessage(out var msg, IntPtr.Zero, 0, 0) > 0) { TranslateMessage(ref msg); DispatchMessage(ref msg); }
                if (hook != IntPtr.Zero) UnhookWindowsHookEx(hook);
            }) { IsBackground = true, Name = "Nogbox wheel count" };
            thread.Start();
        }

        public int Take() => Interlocked.Exchange(ref notches, 0);

        private IntPtr Hook(int code, IntPtr wParam, IntPtr lParam)
        {
            if (code >= 0 && wParam == WmMouseWheel)
            {
                var data = Marshal.PtrToStructure<MsLlHookStruct>(lParam);
                var delta = (short)(data.MouseData >> 16);
                Interlocked.Add(ref notches, Math.Max(1, Math.Abs(delta) / 120));
            }
            return CallNextHookEx(IntPtr.Zero, code, wParam, lParam);
        }

        public void Dispose()
        {
            if (threadId != 0) PostThreadMessage(threadId, WmQuit, IntPtr.Zero, IntPtr.Zero);
        }

        private delegate IntPtr HookProc(int code, IntPtr wParam, IntPtr lParam);

        [StructLayout(LayoutKind.Sequential)]
        private struct MsLlHookStruct { public int X, Y; public uint MouseData, Flags, Time; public IntPtr ExtraInfo; }

        [StructLayout(LayoutKind.Sequential)]
        private struct Msg { public IntPtr Hwnd; public uint Message; public IntPtr WParam, LParam; public uint Time; public int X, Y; }

        [DllImport("user32.dll")] private static extern IntPtr SetWindowsHookEx(int id, HookProc proc, IntPtr module, uint threadId);
        [DllImport("user32.dll")] private static extern bool UnhookWindowsHookEx(IntPtr hook);
        [DllImport("user32.dll")] private static extern IntPtr CallNextHookEx(IntPtr hook, int code, IntPtr wParam, IntPtr lParam);
        [DllImport("user32.dll")] private static extern int GetMessage(out Msg msg, IntPtr window, uint min, uint max);
        [DllImport("user32.dll")] private static extern bool TranslateMessage(ref Msg msg);
        [DllImport("user32.dll")] private static extern IntPtr DispatchMessage(ref Msg msg);
        [DllImport("user32.dll")] private static extern bool PostThreadMessage(uint threadId, uint message, IntPtr wParam, IntPtr lParam);
        [DllImport("kernel32.dll")] private static extern uint GetCurrentThreadId();
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] private static extern IntPtr GetModuleHandle(string? name);
    }
}

/// <summary>Turns two scroll positions into screens moved. Kept apart so it is easy to test.</summary>
public static class ScrollMath
{
    /// <param name="before">Scroll position before, 0 to 100.</param>
    /// <param name="after">Scroll position now, 0 to 100.</param>
    /// <param name="viewPercent">The visible part as a percent of the page (0 to 100).</param>
    public static double Screens(double before, double after, double viewPercent)
    {
        if (viewPercent <= 0 || viewPercent >= 100 || before < 0 || after < 0) return 0;
        var range = 100.0 / viewPercent - 1; // screens between the top and the bottom
        return Math.Abs(after - before) / 100.0 * range;
    }
}
