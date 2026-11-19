using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Text.Json;

namespace LockIn.Companion.Watch;

/// <summary>What a Locked session needs to survive a restart.</summary>
public sealed record ShieldState(string Id, DateTimeOffset StartedAt, int DurationSeconds, string? Task, bool Buddy)
{
    public DateTimeOffset EndsAt => StartedAt.AddSeconds(DurationSeconds);
}

/// <summary>
/// Keeps a Locked session on this PC from being ended by killing the app. Three layers, all for this
/// Windows user, no admin and no driver:
///   1. While the session runs, the process refuses terminate/suspend/inject from other processes, so
///      Task Manager's "End task" fails with Access denied.
///   2. A second copy of the exe (--watchdog) watches the first and starts it again if it dies, and the
///      first restarts the watchdog. Both are protected the same way.
///   3. The session lives in shield.json, held open so it cannot be deleted; a restarted app picks the
///      session up again, with the same end time.
/// It always ends on its own: when the session's time is up (or the phone ends it) the file is cleared,
/// the protection comes off and the watchdog exits. An elevated admin can still end it; that is the limit.
/// </summary>
public static class ProcessShield
{
    public const string MainMutexPrefix = "Nogbox.PC.Companion.";
    public static string WatchdogMutexName => "Nogbox.PC.Watchdog." + Environment.UserName;
    public static string MainMutexName => MainMutexPrefix + Environment.UserName;

    [DllImport("kernel32.dll")] private static extern IntPtr GetCurrentProcess();
    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool SetKernelObjectSecurity(IntPtr handle, uint info, byte[] descriptor);
    private const uint DaclSecurityInformation = 4;

    // Deny everyone: terminate, create thread, VM operation/write, suspend/resume, write DACL/owner.
    // Allow: read the owner's DACL, query, wait. OW (owner rights) is listed so the owner does not get the
    // implicit right to rewrite the DACL.
    private const string Protected = "D:(D;;0xC082B;;;WD)(A;;0x20000;;;OW)(A;;0x121410;;;WD)";
    private const string Normal = "D:(A;;0x1FFFFF;;;OW)(A;;0x1FFFFF;;;SY)(A;;0x1FFFFF;;;BA)";

    private static bool applied;

    public static void Protect(bool on)
    {
        if (applied == on) return;
        try
        {
            var bytes = new RawSecurityDescriptor(on ? Protected : Normal);
            var raw = new byte[bytes.BinaryLength];
            bytes.GetBinaryForm(raw, 0);
            // The pseudo handle always carries full rights, whatever the DACL says.
            if (SetKernelObjectSecurity(GetCurrentProcess(), DaclSecurityInformation, raw)) applied = on;
        }
        catch (Exception) { /* a failure leaves the process as it was */ }
    }

    public static bool MutexExists(string name)
    {
        try { using var m = Mutex.OpenExisting(name); return true; }
        catch (WaitHandleCannotBeOpenedException) { return false; }
        catch (UnauthorizedAccessException) { return true; }
        catch (Exception) { return false; }
    }

    /// <summary>Starts the watchdog unless one is already running.</summary>
    public static void EnsureWatchdog()
    {
        if (MutexExists(WatchdogMutexName)) return;
        try
        {
            Process.Start(new ProcessStartInfo(Environment.ProcessPath!, "--watchdog")
            { UseShellExecute = false, CreateNoWindow = true, WorkingDirectory = AppContext.BaseDirectory });
        }
        catch (Exception) { }
    }

    /// <summary>The watchdog's whole life. Returns when there is no Locked session left to guard.</summary>
    public static void RunWatchdog(string stateDir)
    {
        using var mine = new Mutex(true, WatchdogMutexName, out var first);
        if (!first) return;
        Protect(true);
        var missing = 0;
        while (true)
        {
            var state = ShieldFile.ReadActive(stateDir);
            if (state is null || state.EndsAt <= DateTimeOffset.UtcNow) break;
            if (MutexExists(MainMutexName)) missing = 0;
            else if (++missing >= 2)
            {
                missing = 0;
                try
                {
                    Process.Start(new ProcessStartInfo(Environment.ProcessPath!, "--tray")
                    { UseShellExecute = false, WorkingDirectory = AppContext.BaseDirectory });
                }
                catch (Exception) { }
            }
            Thread.Sleep(1000);
        }
        Protect(false);
    }
}

/// <summary>shield.json in the state folder: held open by the app so it cannot be deleted while a Locked session runs.</summary>
public sealed class ShieldFile : IDisposable
{
    private static string PathIn(string dir) => Path.Combine(dir, "shield.json");
    private readonly FileStream stream;
    private string? last;

    public ShieldFile(string dir)
    {
        Directory.CreateDirectory(dir);
        stream = new FileStream(PathIn(dir), FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.Read);
    }

    public void Write(ShieldState? state)
    {
        var json = state is null ? "" : JsonSerializer.Serialize(state);
        if (json == last) return;
        last = json;
        stream.SetLength(0);
        stream.Position = 0;
        var bytes = System.Text.Encoding.UTF8.GetBytes(json);
        stream.Write(bytes, 0, bytes.Length);
        stream.Flush(true);
    }

    /// <summary>The Locked session on file that has not run out, or null. Safe to call from another process.</summary>
    public static ShieldState? ReadActive(string dir)
    {
        try
        {
            using var f = new FileStream(PathIn(dir), FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
            using var reader = new StreamReader(f);
            var text = reader.ReadToEnd();
            if (string.IsNullOrWhiteSpace(text)) return null;
            var state = JsonSerializer.Deserialize<ShieldState>(text);
            return state is not null && state.EndsAt > DateTimeOffset.UtcNow ? state : null;
        }
        catch (Exception) { return null; }
    }

    public void Dispose() => stream.Dispose();
}

/// <summary>Runs inside the app: mirrors the Locked session into shield.json and applies the protection.</summary>
public sealed class ShieldController : IDisposable
{
    private readonly ShieldFile file;
    private readonly Func<ShieldState?> snapshot;
    private readonly System.Threading.Timer timer;
    private bool active;

    public ShieldController(string stateDir, Func<ShieldState?> snapshot)
    {
        file = new ShieldFile(stateDir);
        this.snapshot = snapshot;
        timer = new System.Threading.Timer(_ => Tick(), null, TimeSpan.Zero, TimeSpan.FromSeconds(2));
    }

    private void Tick()
    {
        try
        {
            var state = snapshot();
            file.Write(state);
            if (state is not null)
            {
                active = true;
                ProcessShield.Protect(true);
                ProcessShield.EnsureWatchdog();
            }
            else if (active)
            {
                active = false;
                ProcessShield.Protect(false);
            }
        }
        catch (Exception) { }
    }

    public void Dispose() { timer.Dispose(); file.Dispose(); }
}
