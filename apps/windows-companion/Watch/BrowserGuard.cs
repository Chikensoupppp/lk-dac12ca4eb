using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text.Json;

namespace LockIn.Companion.Watch;

/// <summary>"The Lock In extension is running in this browser", sent every 15 s by each browser that has it.</summary>
/// <param name="Browser">Process name of the browser that started the host ("chrome", "msedge", "firefox").</param>
/// <param name="Incognito">The extension may also run in private windows.</param>
public sealed record BrowserHeartbeat(string Browser, bool Incognito)
{
    /// <summary>Reads the line the host passes to the companion. Null when it is not a heartbeat.</summary>
    public static BrowserHeartbeat? Parse(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            if (root.ValueKind != JsonValueKind.Object) return null;
            if (!root.TryGetProperty("kind", out var k) || k.ValueKind != JsonValueKind.String || k.GetString() != "alive") return null;
            var browser = root.TryGetProperty("browser", out var b) && b.ValueKind == JsonValueKind.String ? b.GetString() : null;
            if (string.IsNullOrWhiteSpace(browser) || browser.Length > 64) return null;
            return new BrowserHeartbeat(browser.ToLowerInvariant(), root.TryGetProperty("incognito", out var i) && i.ValueKind == JsonValueKind.True);
        }
        catch (JsonException) { return null; }
    }

    /// <summary>The extension's own message <c>{"v":1,"kind":"alive","incognito":true}</c>: the incognito flag, or null.</summary>
    public static bool? IncognitoFromExtension(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            if (root.ValueKind != JsonValueKind.Object) return null;
            if (!root.TryGetProperty("kind", out var k) || k.ValueKind != JsonValueKind.String || k.GetString() != "alive") return null;
            return root.TryGetProperty("incognito", out var i) && i.ValueKind == JsonValueKind.True;
        }
        catch (JsonException) { return null; }
    }
}

/// <summary>Finds the browser that started the native host (walking past cmd.exe, which Chrome uses on Windows).</summary>
public static class ParentProcess
{
    [StructLayout(LayoutKind.Sequential)]
    private struct BasicInfo
    {
        public IntPtr Reserved1, PebBaseAddress, Reserved2a, Reserved2b, UniqueProcessId, InheritedFromUniqueProcessId;
    }

    [DllImport("ntdll.dll")]
    private static extern int NtQueryInformationProcess(IntPtr process, int infoClass, ref BasicInfo info, int size, out int returned);

    private static int? ParentOf(int pid)
    {
        try
        {
            using var p = Process.GetProcessById(pid);
            var info = new BasicInfo();
            return NtQueryInformationProcess(p.Handle, 0, ref info, Marshal.SizeOf<BasicInfo>(), out _) == 0
                ? info.InheritedFromUniqueProcessId.ToInt32()
                : null;
        }
        catch (Exception e) when (e is ArgumentException or InvalidOperationException or System.ComponentModel.Win32Exception)
        {
            return null;
        }
    }

    /// <summary>Lower-case process name of the first ancestor that is not a shell, or null.</summary>
    public static string? NameOf(int pid)
    {
        var current = pid;
        for (var hop = 0; hop < 4; hop++)
        {
            if (ParentOf(current) is not { } parent || parent <= 0) return null;
            string name;
            try { using var p = Process.GetProcessById(parent); name = p.ProcessName.ToLowerInvariant(); }
            catch (ArgumentException) { return null; }
            if (name is not ("cmd" or "conhost")) return name;
            current = parent;
        }
        return null;
    }
}

/// <summary>
/// Makes sure every browser used during a session has the Lock In extension running, also in private
/// windows; otherwise the buddy cannot see Shorts or Reddit there and the reminder means nothing.
///
/// Once the extension has been seen on this PC (remembered in the state folder), it is required: a
/// browser in front without a recent heartbeat, or whose extension may not run in private windows,
/// gets a warning, and after the grace time the buddy minimizes that browser while it is in front
/// (never closes it). A browser the extension cannot run in at all is paused the same way. Before the
/// extension was ever seen nothing is enforced, so people who never set it up are not locked out.
/// </summary>
public sealed class BrowserGuard
{
    public enum Problem { None, Missing, PrivateOff }

    public readonly record struct Verdict(Problem Problem, bool Paused, int SecondsLeft);

    public static readonly TimeSpan AliveFor = TimeSpan.FromSeconds(45);

    private readonly TimeSpan grace;
    private readonly string? seenFile;
    private readonly Dictionary<string, (DateTimeOffset At, bool Incognito)> alive = new();
    private readonly Dictionary<string, DateTimeOffset> warnedSince = new();

    public BrowserGuard(TimeSpan grace, string? stateDir = null)
    {
        this.grace = grace;
        seenFile = stateDir is null ? null : Path.Combine(stateDir, "browser-extension-seen");
        Required = seenFile is not null && File.Exists(seenFile);
    }

    /// <summary>True once the extension has ever reported on this PC.</summary>
    public bool Required { get; private set; }

    public void Heartbeat(DateTimeOffset now, BrowserHeartbeat beat)
    {
        alive[beat.Browser] = (now, beat.Incognito);
        if (Required) return;
        Required = true;
        if (seenFile is null) return;
        try { File.WriteAllText(seenFile, now.ToString("O")); }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
    }

    /// <summary>Forget the warnings (a new session). Heartbeats are kept: browsers keep running between sessions.</summary>
    public void ResetWarnings() => warnedSince.Clear();

    /// <summary>The verdict for the browser in front (its lower-case process name).</summary>
    public Verdict Check(DateTimeOffset now, string browser)
    {
        var problem = !Required ? Problem.None
            : !alive.TryGetValue(browser, out var a) || now - a.At > AliveFor ? Problem.Missing
            : !a.Incognito ? Problem.PrivateOff
            : Problem.None;
        if (problem == Problem.None)
        {
            warnedSince.Remove(browser);
            return new Verdict(Problem.None, false, 0);
        }
        if (!warnedSince.TryGetValue(browser, out var since)) warnedSince[browser] = since = now;
        var left = grace - (now - since);
        return new Verdict(problem, left <= TimeSpan.Zero, Math.Max(0, (int)Math.Ceiling(left.TotalSeconds)));
    }
}
