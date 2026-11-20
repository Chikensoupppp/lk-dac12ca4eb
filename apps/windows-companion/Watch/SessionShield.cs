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
        // A task left over from a session that is long over: remove it and leave.
        if (ShieldFile.ReadActive(stateDir) is null) { ShieldTask.Remove(); return; }
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

/// <summary>
/// Notices the PC clock being moved to run a Locked session out. The clock is compared with a counter the
/// clock cannot change, and the difference is added up since the last correction, so many small steps
/// (a few seconds each, every tick) add up to a correction just like one big step does.
/// </summary>
public sealed class ClockDrift
{
    public static readonly TimeSpan Threshold = TimeSpan.FromSeconds(10);

    private DateTimeOffset? wall;
    private long ticks;

    /// <summary>Forget the starting point (no Locked session is running).</summary>
    public void Reset() => wall = null;

    /// <param name="nowWall">The PC clock.</param>
    /// <param name="nowTicks">Milliseconds from a counter that ignores clock changes (Environment.TickCount64).</param>
    /// <returns>How far the clock moved (positive = forward) once it is more than the threshold; otherwise null.</returns>
    public TimeSpan? Observe(DateTimeOffset nowWall, long nowTicks)
    {
        if (wall is not { } start)
        {
            wall = nowWall;
            ticks = nowTicks;
            return null;
        }
        var drift = (nowWall - start) - TimeSpan.FromMilliseconds(nowTicks - ticks);
        if (drift.Duration() <= Threshold) return null;
        wall = nowWall;
        ticks = nowTicks;
        return drift;
    }
}

/// <summary>Runs inside the app: mirrors the Locked session into shield.json and applies the protection.</summary>
public sealed class ShieldController : IDisposable
{
    /// <summary>How often (in 2 s ticks) the watchdog task and the startup entry are checked while Locked.</summary>
    private const int RepairEveryTicks = 15;

    private readonly ShieldFile file;
    private readonly Func<ShieldState?> snapshot;
    private readonly Action<TimeSpan> onClockJump;
    private readonly System.Threading.Timer timer;
    private readonly ClockDrift drift = new();
    private bool active;
    private int repairTicks;

    /// <param name="onClockJump">Called with how far the PC clock moved against real elapsed time (positive = forward).</param>
    public ShieldController(string stateDir, Func<ShieldState?> snapshot, Action<TimeSpan> onClockJump)
    {
        file = new ShieldFile(stateDir);
        this.snapshot = snapshot;
        this.onClockJump = onClockJump;
        timer = new System.Threading.Timer(_ => Tick(), null, TimeSpan.Zero, TimeSpan.FromSeconds(2));
    }

    private void Tick()
    {
        try
        {
            var state = snapshot();
            // Environment.TickCount64 keeps counting through sleep and ignores clock changes, so wall time
            // moving faster or slower than it means someone changed the clock to run the session out.
            if (state is null) drift.Reset();
            else if (drift.Observe(DateTimeOffset.UtcNow, Environment.TickCount64) is { } jump) onClockJump(jump);

            state = snapshot();
            file.Write(state);
            if (state is not null)
            {
                if (!active) { ShieldTask.Install(); repairTicks = 0; }
                else if (++repairTicks >= RepairEveryTicks) { repairTicks = 0; Repair(); }
                active = true;
                ProcessShield.Protect(true);
                ProcessShield.EnsureWatchdog();
            }
            else if (active)
            {
                active = false;
                ProcessShield.Protect(false);
                ShieldTask.Remove();
            }
        }
        catch (Exception) { }
    }

    /// <summary>
    /// Someone may delete the watchdog task or switch the startup entry off during a Locked session, so a
    /// restart would not bring the app back. Put both back (the task is the stronger of the two).
    /// </summary>
    private static void Repair()
    {
        if (!ShieldTask.Exists()) ShieldTask.Install();
        if (Environment.ProcessPath is { } exe && Installer.IsInstalledCopy(exe) && !Installer.StartsWithWindows())
            Installer.SetStartWithWindows(true);
    }

    public void Dispose() { timer.Dispose(); file.Dispose(); }
}

/// <summary>
/// A per-user Scheduled Task that starts the watchdog every minute, so the guard also comes
/// back after a restart even if the Startup entry is switched off. Added when a Locked session starts and
/// removed when it ends. Runs as the user, no admin, and also on battery.
/// </summary>
public static class ShieldTask
{
    private const string Name = "SwipeLater Watchdog";

    /// <summary>Returns what schtasks said, for checks.</summary>
    public static string Install()
    {
        try
        {
            var xml = $"""
                <?xml version="1.0" encoding="UTF-16"?>
                <Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
                  <Triggers>
                    <TimeTrigger>
                      <Repetition><Interval>PT1M</Interval><StopAtDurationEnd>false</StopAtDurationEnd></Repetition>
                      <StartBoundary>2020-01-01T00:00:00</StartBoundary><Enabled>true</Enabled>
                    </TimeTrigger>
                  </Triggers>
                  <Principals><Principal id="Author"><LogonType>InteractiveToken</LogonType><RunLevel>LeastPrivilege</RunLevel></Principal></Principals>
                  <Settings>
                    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
                    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
                    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
                    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
                    <StartWhenAvailable>true</StartWhenAvailable>
                    <Hidden>true</Hidden>
                  </Settings>
                  <Actions Context="Author"><Exec><Command>{System.Security.SecurityElement.Escape(Environment.ProcessPath!)}</Command><Arguments>--watchdog</Arguments></Exec></Actions>
                </Task>
                """;
            var path = Path.Combine(Path.GetTempPath(), "swipelater-watchdog.xml");
            File.WriteAllText(path, xml, System.Text.Encoding.Unicode);
            var said = Run($"/Create /TN \"{Name}\" /XML \"{path}\" /F");
            try { File.Delete(path); } catch (Exception) { }
            return said;
        }
        catch (Exception e) { return e.Message; }
    }

    public static void Remove() => Run($"/Delete /TN \"{Name}\" /F");

    /// <summary>True when the task is registered (schtasks exits with 0).</summary>
    public static bool Exists()
    {
        try
        {
            using var p = Process.Start(new ProcessStartInfo("schtasks.exe", $"/Query /TN \"{Name}\"")
            { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true });
            if (p is null) return true; // cannot ask: do not churn the task
            p.StandardOutput.ReadToEnd();
            p.StandardError.ReadToEnd();
            if (!p.WaitForExit(10000)) return true;
            return p.ExitCode == 0;
        }
        catch (Exception) { return true; }
    }

    private static string Run(string arguments)
    {
        try
        {
            using var p = Process.Start(new ProcessStartInfo("schtasks.exe", arguments)
            { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true });
            if (p is null) return "";
            var text = p.StandardOutput.ReadToEnd() + p.StandardError.ReadToEnd();
            p.WaitForExit(10000);
            return text;
        }
        catch (Exception e) { return e.Message; }
    }
}
