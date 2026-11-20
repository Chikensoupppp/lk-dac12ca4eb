using System.Collections.Concurrent;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;

namespace LockIn.Companion.Watch;

/// <summary>
/// Spots a game that is not on the named list in <see cref="Distractions"/>. Four signals, cheapest first,
/// and any one is enough:
///  1. the program lives in a game library (Steam, Epic, Riot, Xbox, GOG, EA, Ubisoft, itch, a "Games" folder);
///  2. a game launcher started it (Steam, Epic, Battle.net, EA, Ubisoft, GOG, Riot, Xbox);
///  3. a game SDK or engine file sits next to the program (steam_api64.dll, EOSSDK, UnityPlayer.dll, DLSS...);
///  4. Windows says a Direct3D exclusive full-screen program is running and this window covers the screen.
/// Signals 1-3 are read once per window and remembered. Nothing is read from the screen.
///
/// Anti-cheat safe on purpose: the game's own process is never opened for reading or writing. The only handle
/// ever asked of it is PROCESS_QUERY_LIMITED_INFORMATION, to learn its file path (what Task Manager asks); the
/// launcher chain comes from a process list snapshot (no handle at all), and the SDK check looks at files on
/// disk. Do not add Process.Modules, Process.Handle or any VM_READ access here.
///
/// Work tools that sit in game libraries (Blender, Godot, Unreal Editor...) are listed as never games, and
/// anything this gets wrong can still be let through with the buddy's "It's for work".
/// </summary>
public static class GameDetector
{
    public static readonly string[] LibraryMarkers =
    {
        @"\steamapps\common\", @"\steamlibrary\", @"\epic games\", @"\riot games\", @"\xboxgames\", @"\gog games\",
        @"\gog galaxy\games\", @"\ea games\", @"\ubisoft game launcher\games\", @"\itch\apps\", @"\games\", @"\.minecraft\",
    };

    /// <summary>Paths inside a library marker that are tools, not games (the Unreal Engine editor lives in "Epic Games").</summary>
    public static readonly string[] LibraryExceptions = { @"\epic games\ue_", @"\epic games\launcher\", @"\epic games\epicwebhelper" };

    public static readonly string[] Launchers =
    {
        "steam", "epicgameslauncher", "battle.net", "eadesktop", "ealauncher", "ubisoftconnect", "upc",
        "galaxyclient", "riotclientservices", "xboxpcapp", "itch", "minecraftlauncher", "prismlauncher", "multimc",
        "curseforge", "lunarclient",
    };

    /// <summary>Files that ship with a game, looked for next to its program (and one folder up). Lower case.</summary>
    public static readonly string[] SdkFiles =
    {
        "steam_api64.dll", "steam_api.dll", "steam_appid.txt", "eossdk-win64-shipping.dll", "eossdk-win32-shipping.dll",
        "unityplayer.dll", "gameassembly.dll", "galaxy64.dll", "galaxy.dll", "nvngx_dlss.dll", "openvr_api.dll",
        "bink2w64.dll", "binkw64.dll",
    };

    /// <summary>Process names that are work even when they sit in a game library or were started by a launcher.</summary>
    public static readonly string[] NeverGames =
    {
        "blender", "godot", "krita", "aseprite", "unity", "unityhub", "unrealeditor", "ue4editor", "ue5editor", "wallpaper32",
        "wallpaper64", "ui32", "obs64", "obs32", "robloxstudiobeta", "steamerrorreporter", "crashreportclient",
    };

    private static readonly string[] GenericProductNames =
    {
        "unity", "unreal engine", "unrealengine", "ue4", "ue5", "microsoft® windows® operating system", "java(tm) platform se binary",
    };

    private sealed record Verdict(bool IsGame, string? Name);

    private static readonly ConcurrentDictionary<(int Pid, IntPtr Window), Verdict> Seen = new();
    private static readonly ConcurrentDictionary<string, string> Names = new();

    // ---- the rules, as plain functions so they can be checked without a running game ----

    public static bool InLibrary(string? path)
    {
        if (string.IsNullOrEmpty(path)) return false;
        var p = path.Replace('/', '\\').ToLowerInvariant();
        return LibraryMarkers.Any(p.Contains) && !LibraryExceptions.Any(p.Contains);
    }

    public static bool IsLauncher(string name) => Launchers.Contains(name.ToLowerInvariant());

    public static bool IsSdkFile(string fileName) => SdkFiles.Contains(fileName.ToLowerInvariant());

    /// <summary>True when a game SDK or engine file sits in the program's folder or the one above it. Looks at disk only.</summary>
    public static bool SdkFilesNear(string? exePath)
    {
        try
        {
            if (string.IsNullOrEmpty(exePath)) return false;
            var dir = Path.GetDirectoryName(exePath);
            for (var level = 0; level < 2 && !string.IsNullOrEmpty(dir); level++, dir = Path.GetDirectoryName(dir))
                if (SdkFiles.Any(f => File.Exists(Path.Combine(dir, f)))) return true;
        }
        catch (Exception) { /* an unreadable folder is just "no" */ }
        return false;
    }

    public static bool CoversScreen(int left, int top, int right, int bottom, int monLeft, int monTop, int monRight, int monBottom) =>
        left <= monLeft && top <= monTop && right >= monRight && bottom >= monBottom;

    /// <summary>"Cyberpunk2077" or "Some Game-Win64-Shipping" -> a name to say: drops build suffixes, keeps the rest.</summary>
    public static string CleanName(string exeName)
    {
        var name = exeName;
        foreach (var suffix in new[] { "-win64-shipping", "-win32-shipping", "_x64", "_dx12", "_dx11", "_vulkan", "-shipping", "64" })
            if (name.EndsWith(suffix, StringComparison.OrdinalIgnoreCase) && name.Length > suffix.Length + 2)
                name = name[..^suffix.Length];
        return name.Replace('_', ' ').Replace('-', ' ').Trim();
    }

    public static bool UsableProductName(string? product) =>
        !string.IsNullOrWhiteSpace(product) && product.Trim().Length >= 2 && !GenericProductNames.Contains(product.Trim().ToLowerInvariant());

    // ---- what Distractions asks ----

    /// <summary>True when the front window is a game this list does not name. False for anything it cannot read.</summary>
    public static bool IsGame(FrontWindow.Snapshot? front)
    {
        if (front is null || front.ProcessId <= 0 || front.Process.Length == 0 || front.ProcessId == Environment.ProcessId) return false;
        var proc = front.Process.ToLowerInvariant();
        if (NeverGames.Contains(proc)) return false;
        if (Assess(front.ProcessId, front.Handle, proc).IsGame) return true;
        if (!FullScreenGame(front.Handle)) return false;
        if (!Names.ContainsKey(proc)) Names[proc] = NameFromFile(PathOf(front.ProcessId), proc);
        return true;
    }

    /// <summary>The name to say for a game found by <see cref="IsGame"/> (its product name, else its exe name). Null when unknown.</summary>
    public static string? NameFor(string processLower) => Names.TryGetValue(processLower, out var n) ? n : null;

    // Keyed by process and window, so no handle is opened on the game again once it was judged (a game is in front
    // every second for hours), and a reused process id with a new window is judged afresh.
    private static Verdict Assess(int pid, IntPtr window, string proc)
    {
        if (Seen.TryGetValue((pid, window), out var known)) return known;
        var verdict = Judge(pid, proc);
        if (Seen.Count > 400) Seen.Clear(); // a long session sees many programs; a few rereads are cheaper than a leak
        Seen[(pid, window)] = verdict;
        if (verdict.IsGame && verdict.Name is not null) Names.TryAdd(proc, verdict.Name);
        return verdict;
    }

    private static Verdict Judge(int pid, string proc)
    {
        var path = PathOf(pid);
        var game = InLibrary(path) || SdkFilesNear(path) || Ancestors(pid, 3).Any(IsLauncher);
        return game ? new Verdict(true, NameFromFile(path, proc)) : new Verdict(false, null);
    }

    private static string NameFromFile(string? path, string proc)
    {
        try
        {
            if (path is not null)
            {
                var product = FileVersionInfo.GetVersionInfo(path).ProductName;
                if (UsableProductName(product)) return product!.Trim();
                return CleanName(Path.GetFileNameWithoutExtension(path));
            }
        }
        catch (Exception) { /* no version info: the exe name is enough */ }
        return CleanName(proc);
    }

    // ---- Windows calls ----

    [DllImport("kernel32.dll", SetLastError = true)] private static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll")] private static extern bool CloseHandle(IntPtr handle);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool QueryFullProcessImageName(IntPtr process, int flags, System.Text.StringBuilder name, ref int size);
    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("shell32.dll")] private static extern int SHQueryUserNotificationState(out int state);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hWnd, out Rect rect);
    [DllImport("user32.dll")] private static extern IntPtr MonitorFromWindow(IntPtr hWnd, uint flags);
    [DllImport("user32.dll")] private static extern bool GetMonitorInfo(IntPtr monitor, ref MonitorInfo info);

    [StructLayout(LayoutKind.Sequential)] private struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] private struct MonitorInfo { public int Size; public Rect Monitor, Work; public uint Flags; }

    private const uint ProcessQueryLimitedInformation = 0x1000; // the least access there is: a path and a name
    private const int D3DFullScreen = 3; // QUNS_RUNNING_D3D_FULL_SCREEN

    private static string? PathOf(int pid)
    {
        var handle = OpenProcess(ProcessQueryLimitedInformation, false, pid);
        if (handle == IntPtr.Zero) return null;
        try
        {
            var sb = new System.Text.StringBuilder(1024);
            var size = sb.Capacity;
            return QueryFullProcessImageName(handle, 0, sb, ref size) ? sb.ToString() : null;
        }
        finally { CloseHandle(handle); }
    }

    /// <summary>Lower-case names (no ".exe") of up to <paramref name="hops"/> ancestors, nearest first. From a process list: no handle to any process.</summary>
    public static IReadOnlyList<string> Ancestors(int pid, int hops) => ProcessList.Ancestors(ProcessList.Snapshot(), pid, hops);

    private static bool FullScreenGame(IntPtr window)
    {
        try
        {
            // Exclusive full screen is always the window in front, so no other window needs asking.
            if (window == IntPtr.Zero || GetForegroundWindow() != window) return false;
            if (SHQueryUserNotificationState(out var state) != 0 || state != D3DFullScreen) return false;
            if (!GetWindowRect(window, out var r)) return false;
            var info = new MonitorInfo { Size = Marshal.SizeOf<MonitorInfo>() };
            if (!GetMonitorInfo(MonitorFromWindow(window, 2), ref info)) return false;
            return CoversScreen(r.Left, r.Top, r.Right, r.Bottom, info.Monitor.Left, info.Monitor.Top, info.Monitor.Right, info.Monitor.Bottom);
        }
        catch (Exception) { return false; }
    }
}
