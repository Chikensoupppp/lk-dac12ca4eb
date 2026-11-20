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
        "floorp", "zen", "arc", "thorium", "iexplore", "palemoon", "seamonkey", "maxthon", "whale",
        "slimjet", "iridium", "wavebox", "sidekick",
    };
    // Game launchers and the games people most often leave running: process name (lower case, no ".exe") to the
    // name the buddy says. Editors and engines (Unity, Unreal, Godot, Blender, Roblox Studio) are work, not here.
    private static readonly Dictionary<string, string> GameNames = new()
    {
        // Launchers and stores
        ["steam"] = "Steam", ["steamwebhelper"] = "Steam", ["epicgameslauncher"] = "Epic Games", ["riotclientux"] = "Riot Client",
        ["leagueclient"] = "League of Legends", ["battle.net"] = "Battle.net", ["eadesktop"] = "EA app",
        ["ubisoftconnect"] = "Ubisoft Connect", ["upc"] = "Ubisoft Connect", ["galaxyclient"] = "GOG Galaxy", ["xboxpcapp"] = "Xbox app",
        // Shooters and battle royales
        ["cs2"] = "Counter-Strike 2", ["csgo"] = "CS:GO", ["valorant-win64-shipping"] = "Valorant", ["r5apex"] = "Apex Legends",
        ["r5apex_dx12"] = "Apex Legends", ["overwatch"] = "Overwatch", ["rainbowsix"] = "Rainbow Six Siege",
        ["rainbowsix_vulkan"] = "Rainbow Six Siege", ["tslgame"] = "PUBG", ["cod"] = "Call of Duty",
        ["fortniteclient-win64-shipping"] = "Fortnite", ["marvelrivals-win64-shipping"] = "Marvel Rivals", ["destiny2"] = "Destiny 2",
        ["left4dead2"] = "Left 4 Dead 2", ["bf6"] = "Battlefield 6", ["bf2042"] = "Battlefield 2042", ["bfv"] = "Battlefield V",
        ["bf1"] = "Battlefield 1", ["helldivers2"] = "Helldivers 2", ["fallguys_client_game"] = "Fall Guys",
        // Strategy, MOBAs and card games
        ["dota2"] = "Dota 2", ["league of legends"] = "League of Legends", ["heroesofthestorm"] = "Heroes of the Storm",
        ["sc2"] = "StarCraft II", ["sc2_x64"] = "StarCraft II", ["civilizationvi"] = "Civilization VI",
        ["civilizationvi_dx12"] = "Civilization VI", ["stellaris"] = "Stellaris", ["eu4"] = "Europa Universalis IV",
        ["hoi4"] = "Hearts of Iron IV", ["ck3"] = "Crusader Kings III", ["aoe2de_s"] = "Age of Empires II", ["aoe4"] = "Age of Empires IV",
        ["hearthstone"] = "Hearthstone",
        // Sandbox, survival and sim
        ["minecraftlauncher"] = "Minecraft", ["minecraft.windows"] = "Minecraft", ["robloxplayerbeta"] = "Roblox",
        ["terraria"] = "Terraria", ["stardew valley"] = "Stardew Valley", ["valheim"] = "Valheim", ["rustclient"] = "Rust",
        ["factorio"] = "Factorio", ["factorygame-win64-shipping"] = "Satisfactory", ["rimworldwin64"] = "RimWorld",
        ["palworld-win64-shipping"] = "Palworld", ["nms"] = "No Man's Sky", ["seaofthieves"] = "Sea of Thieves",
        ["lethal company"] = "Lethal Company", ["phasmophobia"] = "Phasmophobia", ["ts4_x64"] = "The Sims 4",
        ["eurotrucks2"] = "Euro Truck Simulator 2", ["among us"] = "Among Us", ["deadbydaylight-win64-shipping"] = "Dead by Daylight",
        ["fivem"] = "FiveM", ["gta5"] = "GTA V", ["rdr2"] = "Red Dead Redemption 2", ["davethediver"] = "Dave the Diver",
        // RPGs and online worlds
        ["eldenring"] = "Elden Ring", ["sekiro"] = "Sekiro", ["darksoulsiii"] = "Dark Souls III", ["witcher3"] = "The Witcher 3",
        ["cyberpunk2077"] = "Cyberpunk 2077", ["bg3"] = "Baldur's Gate 3", ["bg3_dx11"] = "Baldur's Gate 3",
        ["hogwartslegacy"] = "Hogwarts Legacy", ["diablo iv"] = "Diablo IV", ["wow"] = "World of Warcraft",
        ["wowclassic"] = "World of Warcraft", ["pathofexile"] = "Path of Exile", ["pathofexile_x64"] = "Path of Exile",
        ["pathofexilesteam"] = "Path of Exile", ["lostark"] = "Lost Ark", ["ffxiv_dx11"] = "Final Fantasy XIV",
        ["gw2-64"] = "Guild Wars 2", ["warframe.x64"] = "Warframe", ["skyrimse"] = "Skyrim", ["fallout4"] = "Fallout 4",
        ["starfield"] = "Starfield", ["genshinimpact"] = "Genshin Impact", ["starrail"] = "Honkai: Star Rail",
        ["zenlesszonezero"] = "Zenless Zone Zero", ["hollow_knight"] = "Hollow Knight",
        // Sports, racing and arcade
        ["rocketleague"] = "Rocket League", ["fc26"] = "EA Sports FC", ["fc25"] = "EA Sports FC", ["fc24"] = "EA Sports FC",
        ["forzahorizon5"] = "Forza Horizon 5", ["osu!"] = "osu!", ["geometrydash"] = "Geometry Dash", ["balatro"] = "Balatro",
        // Emulators
        ["retroarch"] = "RetroArch", ["dolphin"] = "Dolphin", ["ryujinx"] = "Ryujinx", ["rpcs3"] = "RPCS3", ["cemu"] = "Cemu",
        ["pcsx2-qt"] = "PCSX2", ["ppssppwindows"] = "PPSSPP",
        // Android emulators and game streaming
        ["hd-player"] = "BlueStacks", ["bluestacks"] = "BlueStacks", ["bluestacksx"] = "BlueStacks", ["dnplayer"] = "LDPlayer",
        ["mumuplayer"] = "MuMu Player", ["nemuplayer"] = "MuMu Player", ["noxplayer"] = "Nox", ["nox"] = "Nox", ["memu"] = "MEmu",
        ["geforcenow"] = "GeForce Now", ["moonlight"] = "Moonlight",
        // Desktop apps of video and social sites (the same names the browser sites use)
        ["netflix"] = "Netflix", ["tiktok"] = "TikTok", ["instagram"] = "Instagram", ["disneyplus"] = "Disney+",
        ["primevideo"] = "Prime Video", ["twitch"] = "Twitch", ["hulu"] = "Hulu",
    };
    private static readonly string[] Chat = { "discord", "telegram", "whatsapp", "signal", "viber", "messenger" };

    // The title is only the fallback when the address bar cannot be read, so only names that rarely turn up in
    // a work document's title are listed here. Sites such as X are caught by their address (BrowserSites).
    private static readonly (string Needle, string Name)[] SiteTitles =
    {
        ("youtube", "YouTube"), ("tiktok", "TikTok"), ("reddit", "Reddit"),
        ("instagram", "Instagram"), ("netflix", "Netflix"), ("twitch", "Twitch"),
        ("facebook", "Facebook"), ("snapchat", "Snapchat"), ("disney+", "Disney+"), ("hulu", "Hulu"),
        // Game portals: titles like "Subway Surfers - Play on CrazyGames".
        ("crazygames", "CrazyGames"), ("miniclip", "Miniclip"), ("newgrounds", "Newgrounds"), ("kongregate", "Kongregate"),
        ("coolmathgames", "Cool Math Games"), ("unblocked games", "Unblocked Games"), ("free online games", "Online Games"),
        ("on poki", "Poki"), ("chess.com", "Chess.com"), ("on itch.io", "itch.io"),
    };

    /// <summary>Store apps (Netflix, TikTok...) run inside "ApplicationFrameHost", so their window title is the only name there is.</summary>
    private static readonly string[] AppTitleNames = { "Netflix", "Disney+", "Prime Video", "TikTok", "Instagram", "Twitch", "Facebook", "Hulu" };

    private static string? StoreApp(string proc, string title)
    {
        if (proc != "applicationframehost") return null;
        foreach (var name in AppTitleNames)
            if (title.Equals(name, StringComparison.OrdinalIgnoreCase)
                || (title.StartsWith(name, StringComparison.OrdinalIgnoreCase) && title.Length > name.Length && " -|:".Contains(title[name.Length])))
                return name;
        return null;
    }

    /// <summary>Minecraft Java runs as a plain "javaw" whose window is titled "Minecraft 1.21...". Other Java programs are left alone.</summary>
    private static string? JavaGame(string proc, string title) =>
        proc is "javaw" or "java" && title.StartsWith("Minecraft", StringComparison.OrdinalIgnoreCase) ? "Minecraft" : null;

    /// <summary>A plain name for the front app, for the phone. Null when nothing is in front.</summary>
    public static string? NameOf(FrontWindow.Snapshot? front)
    {
        if (front is null) return null;
        var proc = front.Process.ToLowerInvariant();
        if (Browsers.Contains(proc))
        {
            // The address wins over the title: a Reddit post's title never says "Reddit".
            if (BrowserSites.For(front.Handle) is { } bySite) return bySite;
            var title = front.Title.ToLowerInvariant();
            foreach (var (needle, name) in SiteTitles)
                if (title.Contains(needle)) return name;
            return "Browser";
        }
        if ((StoreApp(proc, front.Title) ?? JavaGame(proc, front.Title)) is { } known) return known;
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
        ("telegram", "Telegram"), ("whatsapp", "WhatsApp"), ("x", "X"), ("facebook", "Facebook"), ("snapchat", "Snapchat"),
    };

    /// <summary>Same app, same key: "YouTube" and "youtube" match, and Steam's helper counts as Steam.</summary>
    private static readonly Dictionary<string, string> Alias = new() { ["steamwebhelper"] = "steam" };

    private static readonly Dictionary<string, string> Friendly = new()
    {
        ["chrome"] = "Chrome", ["msedge"] = "Edge", ["firefox"] = "Firefox", ["brave"] = "Brave", ["opera"] = "Opera",
        ["vivaldi"] = "Vivaldi", ["discord"] = "Discord", ["telegram"] = "Telegram", ["whatsapp"] = "WhatsApp",
        ["signal"] = "Signal", ["viber"] = "Viber", ["messenger"] = "Messenger",
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
        if (Friendly.TryGetValue(key, out var nice) || GameNames.TryGetValue(key, out nice)) return nice;
        return GameDetector.NameFor(key) ?? name;
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
    public static bool IsBrowserProcess(string processName) => Browsers.Contains(processName.ToLowerInvariant());

    public static bool IsBrowser(FrontWindow.Snapshot? front) =>
        front is not null && Browsers.Contains(front.Process.ToLowerInvariant());

    /// <summary>True when the front window is a distraction (a site, a game or chat).</summary>
    public static bool IsDistraction(FrontWindow.Snapshot? front)
    {
        if (front is null) return false;
        var proc = front.Process.ToLowerInvariant();
        if (GameNames.ContainsKey(proc) || Chat.Contains(proc)) return true;
        if (StoreApp(proc, front.Title) is not null || JavaGame(proc, front.Title) is not null) return true;
        if (!Browsers.Contains(proc)) return GameDetector.IsGame(front); // a game that is not named above
        if (BrowserSites.For(front.Handle) is not null) return true;
        var title = front.Title.ToLowerInvariant();
        return SiteTitles.Any(s => title.Contains(s.Needle));
    }
}
