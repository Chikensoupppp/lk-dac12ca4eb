namespace LockIn.Companion.Watch;

/// <summary>
/// Which distraction site the front browser tab is on, judged by its address. The page title alone is easy to
/// get past: a Reddit post's title never says "Reddit", and a tab can be renamed. <see cref="BrowserWatch"/>
/// already reads the address bar every second; it hands over only the site's name here (never the address),
/// and the name is trusted for a few seconds, only for the window it was read from.
/// </summary>
public static class BrowserSites
{
    private static readonly TimeSpan FreshFor = TimeSpan.FromSeconds(5);
    private static readonly object gate = new();
    private static IntPtr window;
    private static string? site;
    private static long readAt;

    private static readonly (string Host, string Name)[] Hosts =
    {
        ("youtube.com", "YouTube"), ("youtu.be", "YouTube"), ("tiktok.com", "TikTok"),
        ("reddit.com", "Reddit"), ("redd.it", "Reddit"), ("instagram.com", "Instagram"),
        ("netflix.com", "Netflix"), ("twitch.tv", "Twitch"),
    };

    /// <summary>"YouTube", "Reddit" and so on for an address on a distraction site; null for any other page.</summary>
    public static string? NameOf(string? address)
    {
        if (string.IsNullOrWhiteSpace(address)) return null;
        var text = address.Trim();
        if (!text.Contains("://")) text = "https://" + text;
        if (!Uri.TryCreate(text, UriKind.Absolute, out var uri)) return null;
        var host = uri.Host.ToLowerInvariant();
        foreach (var (name, label) in Hosts)
            if (host == name || host.EndsWith("." + name, StringComparison.Ordinal)) return label;
        return null;
    }

    /// <summary>Called every second for the front browser window: its site (null when it is on any other page).</summary>
    public static void Record(IntPtr front, string? name, long nowMs)
    {
        lock (gate) { window = front; site = name; readAt = nowMs; }
    }

    public static void Record(IntPtr front, string? name) => Record(front, name, Environment.TickCount64);

    /// <summary>The site read from this window a moment ago, or null (not read, stale, another window, or no distraction).</summary>
    public static string? For(IntPtr front, long nowMs)
    {
        lock (gate) return front != IntPtr.Zero && front == window && nowMs - readAt <= FreshFor.TotalMilliseconds ? site : null;
    }

    public static string? For(IntPtr front) => For(front, Environment.TickCount64);

    /// <summary>Test helper: forget what was read.</summary>
    public static void Clear()
    {
        lock (gate) { window = IntPtr.Zero; site = null; readAt = 0; }
    }
}
