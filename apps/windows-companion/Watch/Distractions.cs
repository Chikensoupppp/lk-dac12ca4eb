namespace LockIn.Companion.Watch;

/// <summary>
/// Decides whether the window in front is a distraction, and what to call it.
/// Browsers are judged by the page title, so Docs stays fine and YouTube does not.
/// </summary>
public static class Distractions
{
    private static readonly string[] Browsers =
    {
        "chrome", "msedge", "firefox", "brave", "opera", "vivaldi", "chromium", "waterfox", "librewolf",
        "floorp", "zen", "arc", "thorium", "iexplore",
    };
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
        ["leagueclient"] = "League of Legends", ["chrome"] = "Chrome", ["msedge"] = "Edge", ["firefox"] = "Firefox",
        ["brave"] = "Brave", ["opera"] = "Opera", ["vivaldi"] = "Vivaldi", ["discord"] = "Discord", ["telegram"] = "Telegram", ["whatsapp"] = "WhatsApp",
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

    /// <summary>Windows that are part of Windows itself, not somewhere the user works.</summary>
    private static readonly string[] Shell =
    {
        "explorer", "searchhost", "searchapp", "startmenuexperiencehost", "shellexperiencehost", "lockapp",
        "applicationframehost", "textinputhost", "systemsettings", "taskmgr", "",
    };

    private static readonly string[] BlankPages = { "Untitled", "New Tab", "New tab", "about:blank" };

    /// <summary>
    /// True when the window looks like work: any normal app or browser tab that is not on the distraction
    /// list, not part of the Windows shell, not untitled, and not Lock In itself.
    /// </summary>
    public static bool IsWorkWindow(FrontWindow.Snapshot? front, int ownProcessId)
    {
        if (front is null || front.Handle == IntPtr.Zero || front.ProcessId == ownProcessId) return false;
        if (string.IsNullOrWhiteSpace(front.Title)) return false;
        var proc = front.Process.ToLowerInvariant();
        if (Shell.Contains(proc) || proc.StartsWith("lockin", StringComparison.Ordinal)) return false;
        // A browser with no page yet (still loading, an empty tab) is not work either.
        if (Browsers.Contains(proc) && BlankPages.Any(b => front.Title.StartsWith(b, StringComparison.OrdinalIgnoreCase)))
            return false;
        return !IsDistraction(front);
    }

    /// <summary>True when the front window is a browser.</summary>
    public static bool IsBrowser(FrontWindow.Snapshot? front) =>
        front is not null && Browsers.Contains(front.Process.ToLowerInvariant());

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
