namespace LockIn.Companion.Watch;

/// <summary>
/// Decides whether the window in front is a distraction, and what to call it.
/// Browsers are judged by the page title, so Docs stays fine and YouTube does not.
/// </summary>
public static class Distractions
{
    private static readonly string[] Browsers = { "chrome", "msedge", "firefox", "brave", "opera" };
    private static readonly string[] Games = { "steam", "steamwebhelper", "epicgameslauncher", "riotclientux", "leagueclient" };
    private static readonly string[] Chat = { "discord", "telegram", "whatsapp" };

    private static readonly (string Needle, string Name)[] SiteTitles =
    {
        ("youtube", "YouTube"), ("tiktok", "TikTok"), ("reddit", "Reddit"),
        ("instagram", "Instagram"), ("netflix", "Netflix"), ("twitch", "Twitch"),
    };

    /// <summary>A plain name for the front app, for the phone. Null when nothing is in front.</summary>
    public static string? NameOf(FrontWindow.Snapshot? front)
    {
        if (front is null) return null;
        var proc = front.Process.ToLowerInvariant();
        if (Browsers.Contains(proc))
        {
            var title = front.Title.ToLowerInvariant();
            foreach (var (needle, name) in SiteTitles)
                if (title.Contains(needle)) return name;
            return "Browser";
        }
        return front.Process.Length == 0 ? null : front.Process;
    }

    /// <summary>
    /// The apps and sites the buddy may ask about, as the phone shows them before a session: a short
    /// list of chips, not every app on the PC. Keys match <see cref="KeyOf"/>.
    /// </summary>
    public static readonly IReadOnlyList<(string Key, string Name)> Choices = new (string, string)[]
    {
        ("youtube", "YouTube"), ("discord", "Discord"), ("reddit", "Reddit"), ("tiktok", "TikTok"),
        ("instagram", "Instagram"), ("netflix", "Netflix"), ("twitch", "Twitch"), ("steam", "Steam"),
        ("telegram", "Telegram"), ("whatsapp", "WhatsApp"),
    };

    /// <summary>Same app, same key: "YouTube" and "youtube" match, and Steam's helper counts as Steam.</summary>
    private static readonly Dictionary<string, string> Alias = new() { ["steamwebhelper"] = "steam" };

    private static readonly Dictionary<string, string> Friendly = new()
    {
        ["steam"] = "Steam", ["epicgameslauncher"] = "Epic Games", ["riotclientux"] = "Riot Client",
        ["leagueclient"] = "League of Legends", ["discord"] = "Discord", ["telegram"] = "Telegram", ["whatsapp"] = "WhatsApp",
    };

    /// <summary>A stable lower-case name for allow lists ("youtube", "discord"). Null when nothing is in front.</summary>
    public static string? KeyOf(FrontWindow.Snapshot? front)
    {
        var name = NameOf(front)?.ToLowerInvariant();
        return name is not null && Alias.TryGetValue(name, out var canonical) ? canonical : name;
    }

    /// <summary>A name a person would say: "YouTube", "Discord", "Epic Games".</summary>
    public static string FriendlyName(string? name)
    {
        if (name is null) return "this";
        var key = name.ToLowerInvariant();
        if (Alias.TryGetValue(key, out var canonical)) key = canonical;
        return Friendly.TryGetValue(key, out var nice) ? nice : name;
    }

    /// <summary>True when the front window is a distraction (a site, a game or chat).</summary>
    public static bool IsDistraction(FrontWindow.Snapshot? front)
    {
        if (front is null) return false;
        var proc = front.Process.ToLowerInvariant();
        if (Games.Contains(proc) || Chat.Contains(proc)) return true;
        if (!Browsers.Contains(proc)) return false;
        var title = front.Title.ToLowerInvariant();
        return SiteTitles.Any(s => title.Contains(s.Needle));
    }
}
