namespace LockIn.Companion.Watch;

/// <summary>
/// Which distraction site a browser tab is on, judged by its address. The page title alone is easy to
/// get past: a Reddit post's title never says "Reddit", and a tab can be renamed. <see cref="BrowserWatch"/>
/// reads the address bars of the open browser windows (every monitor, not only the one in front); it hands over
/// only the site's name here (never the address), and the name is trusted for a few seconds, only for the
/// window it was read from.
/// </summary>
public static class BrowserSites
{
    private static readonly TimeSpan FreshFor = TimeSpan.FromSeconds(5);
    private static readonly object gate = new();
    private static readonly Dictionary<IntPtr, (string? Site, long At)> reads = new();

    /// <param name="Host">A domain: it matches itself and every subdomain (youtube.com matches m.youtube.com).</param>
    /// <param name="Path">Only addresses that start with this path (xbox.com/play).</param>
    /// <param name="Exact">Only this exact host, not its subdomains (roblox.com, but not create.roblox.com).</param>
    private sealed record Site(string Host, string Name, string? Path = null, bool Exact = false);

    private static readonly Site[] Sites =
    {
        // Video and social
        new("youtube.com", "YouTube"), new("youtu.be", "YouTube"), new("tiktok.com", "TikTok"),
        new("reddit.com", "Reddit"), new("redd.it", "Reddit"), new("instagram.com", "Instagram"),
        new("netflix.com", "Netflix"), new("twitch.tv", "Twitch"), new("kick.com", "Kick"),
        new("x.com", "X"), new("twitter.com", "X"),
        new("facebook.com", "Facebook"), new("fb.com", "Facebook"), new("fb.watch", "Facebook"), new("snapchat.com", "Snapchat"),
        new("disneyplus.com", "Disney+"), new("hulu.com", "Hulu"), new("primevideo.com", "Prime Video"),
        // Game portals and browser games
        new("poki.com", "Poki"), new("crazygames.com", "CrazyGames"), new("miniclip.com", "Miniclip"), new("y8.com", "Y8"),
        new("kongregate.com", "Kongregate"), new("newgrounds.com", "Newgrounds"), new("armorgames.com", "Armor Games"),
        new("addictinggames.com", "Addicting Games"), new("coolmathgames.com", "Cool Math Games"), new("friv.com", "Friv"),
        new("kizi.com", "Kizi"), new("silvergames.com", "Silver Games"), new("gamesgames.com", "Games Games"),
        new("arkadium.com", "Arkadium"), new("gamepix.com", "GamePix"), new("pogo.com", "Pogo"),
        new("itch.io", "itch.io"), new("gamejolt.com", "Game Jolt"),
        new("roblox.com", "Roblox", Exact: true), new("now.gg", "now.gg"),
        new("geoguessr.com", "GeoGuessr"), new("chess.com", "Chess.com"), new("lichess.org", "Lichess"),
        new("agar.io", "Agar.io"), new("slither.io", "Slither.io"), new("diep.io", "Diep.io"), new("krunker.io", "Krunker"),
        new("skribbl.io", "Skribbl"), new("shellshock.io", "Shell Shockers"), new("tetr.io", "TETR.IO"),
        new("orteil.dashnet.org", "Cookie Clicker"),
        // Cloud gaming
        new("play.geforcenow.com", "GeForce Now"), new("luna.amazon.com", "Amazon Luna"),
        new("xbox.com", "Xbox Cloud Gaming", Path: "/play"), new("nytimes.com", "NYT Games", Path: "/games"),
    };

    /// <summary>"YouTube", "Reddit" and so on for an address on a distraction site; null for any other page.</summary>
    public static string? NameOf(string? address)
    {
        if (string.IsNullOrWhiteSpace(address)) return null;
        var text = address.Trim();
        if (!text.Contains("://")) text = "https://" + text;
        if (!Uri.TryCreate(text, UriKind.Absolute, out var uri)) return null;
        var host = uri.Host.ToLowerInvariant();
        if (host.StartsWith("www.", StringComparison.Ordinal)) host = host[4..];
        foreach (var site in Sites)
        {
            var hostMatches = host == site.Host || (!site.Exact && host.EndsWith("." + site.Host, StringComparison.Ordinal));
            if (hostMatches && (site.Path is null || PathStartsWith(uri.AbsolutePath, site.Path))) return site.Name;
        }
        // "Unblocked games" sites come and go by the week; the word is the giveaway.
        if (host.Contains("unblocked", StringComparison.Ordinal) || uri.AbsolutePath.Contains("unblocked", StringComparison.OrdinalIgnoreCase))
            return "Unblocked Games";
        return null;
    }

    // Addresses often start with a language: xbox.com/en-US/play is xbox.com/play.
    private static readonly System.Text.RegularExpressions.Regex Language = new(
        @"^/[a-z]{2}(?:-[a-z]{2,4})?(?=/)", System.Text.RegularExpressions.RegexOptions.IgnoreCase | System.Text.RegularExpressions.RegexOptions.CultureInvariant);

    private static bool PathStartsWith(string path, string prefix) =>
        path.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) || Language.Replace(path, "", 1).StartsWith(prefix, StringComparison.OrdinalIgnoreCase);

    /// <summary>Called for each open browser window every second or two: its site (null when it is on any other page).</summary>
    public static void Record(IntPtr window, string? name, long nowMs)
    {
        lock (gate)
        {
            reads[window] = (name, nowMs);
            if (reads.Count > 64)
                foreach (var stale in reads.Where(r => nowMs - r.Value.At > 60_000).Select(r => r.Key).ToList()) reads.Remove(stale);
        }
    }

    public static void Record(IntPtr window, string? name) => Record(window, name, Environment.TickCount64);

    /// <summary>The site read from this window a moment ago, or null (not read, stale, another window, or no distraction).</summary>
    public static string? For(IntPtr window, long nowMs)
    {
        lock (gate)
            return window != IntPtr.Zero && reads.TryGetValue(window, out var r) && nowMs - r.At <= FreshFor.TotalMilliseconds ? r.Site : null;
    }

    public static string? For(IntPtr window) => For(window, Environment.TickCount64);

    /// <summary>Test helper: forget what was read.</summary>
    public static void Clear()
    {
        lock (gate) reads.Clear();
    }
}
