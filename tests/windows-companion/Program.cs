using LockIn.Companion.Watch;

var completionStart = new DateTimeOffset(2026, 1, 1, 0, 1, 0, TimeSpan.Zero);
var cheerUntil = completionStart + CompletionTiming.CheerDuration;
Check(CompletionTiming.Evaluate(completionStart.AddTicks(-1), completionStart, null) == CompletionTiming.Phase.Running,
    "buddy remains active before session end");
Check(CompletionTiming.Evaluate(completionStart, completionStart, null) == CompletionTiming.Phase.StartCheer,
    "buddy cheers at the session end");
Check(CompletionTiming.Evaluate(cheerUntil.AddTicks(-1), completionStart, cheerUntil) == CompletionTiming.Phase.Cheering,
    "buddy keeps cheering before the six-second boundary");
Check(CompletionTiming.Evaluate(cheerUntil, completionStart, cheerUntil) == CompletionTiming.Phase.Hide,
    "buddy hides at the six-second boundary");

var clock = new TestClock(new DateTimeOffset(2026, 1, 1, 0, 0, 0, TimeSpan.Zero));
var store = new SessionStore(clock);
Check(store.Current.State == "idle", "starts idle");
Check(store.TryStart(60, out var first), "starts session");
Check(first.EndsAt == clock.GetUtcNow().AddSeconds(60), "sets end timestamp");
Check(!store.TryStart(60, out var conflict) && conflict.Id == first.Id, "rejects duplicate start");
clock.Advance(TimeSpan.FromSeconds(59));
Check(store.Current.State == "active", "active before end");
clock.Advance(TimeSpan.FromSeconds(1));
Check(store.Current.State == "idle", "expires at exact end");
Check(store.TryStart(60, out var second) && second.Id != first.Id, "starts after expiry");
Check(store.Stop().State == "idle", "stops early");
Check(store.Stop().State == "idle", "repeated stop is safe");

var race = new SessionStore(clock);
var winners = 0;
Parallel.For(0, 32, index =>
{
    if (race.TryStart(60, out _))
        Interlocked.Increment(ref winners);
});
Check(winners == 1, "only one simultaneous start succeeds");

// Phone-supplied session id and start time (mirroring).
var mirrorClock = new TestClock(new DateTimeOffset(2026, 1, 1, 12, 0, 0, TimeSpan.Zero));
var mirror = new SessionStore(mirrorClock);
var phoneStart = mirrorClock.GetUtcNow();
Check(mirror.TryStart("phone-1", 900, phoneStart, out var mirrored) == StartOutcome.Started
      && mirrored.Id == "phone-1" && mirrored.EndsAt == phoneStart.AddSeconds(900), "mirrors the phone's id and times");
Check(mirror.TryStart("phone-1", 900, phoneStart, out var again) == StartOutcome.Existing && again.Id == "phone-1",
    "repeating the same id is safe");
Check(mirror.TryStart("phone-2", 900, phoneStart, out _) == StartOutcome.Conflict, "a different id conflicts");
Check(mirror.Stop("phone-2").State == "active", "a stale stop cannot end a newer session");
Check(mirror.Stop("phone-1").State == "idle", "stop with the right id ends it");
mirrorClock.Advance(TimeSpan.FromSeconds(300));
Check(mirror.TryStart("phone-3", 900, mirrorClock.GetUtcNow().AddSeconds(-120), out var late) == StartOutcome.Started
      && late.EndsAt == mirrorClock.GetUtcNow().AddSeconds(780), "joins a session that began earlier");
mirror.Stop();
Check(mirror.TryStart("phone-4", 60, mirrorClock.GetUtcNow().AddSeconds(-60), out _) == StartOutcome.TooLate,
    "refuses a session that is already over");
Check(mirror.TryStart("phone-5", 900, mirrorClock.GetUtcNow().AddSeconds(61), out _) == StartOutcome.FromFuture,
    "refuses a start time too far ahead");
Check(mirror.TryStart("phone-6", 900, mirrorClock.GetUtcNow().AddSeconds(60), out _) == StartOutcome.Started,
    "allows small clock drift ahead");

// Pairing and tokens.
var pairDir = Path.Combine(Path.GetTempPath(), "lockin-checks-" + Guid.NewGuid().ToString("N"));
try
{
    var pairClock = new TestClock(new DateTimeOffset(2026, 1, 1, 12, 0, 0, TimeSpan.Zero));
    var pairStore = new CompanionStateStore(pairDir);
    using (var cert1 = pairStore.LoadOrCreateCertificate())
    using (var cert2 = new CompanionStateStore(pairDir).LoadOrCreateCertificate())
        Check(CompanionStateStore.Fingerprint(cert1) == CompanionStateStore.Fingerprint(cert2),
            "the same certificate comes back after a restart");

    var pairing = new PairingService(pairStore, pairClock);
    Check(!pairing.TryPair("x", "iPhone").Ok && !pairing.IsOpen, "pairing is closed until opened");
    var (code, _) = pairing.Open(TimeSpan.FromMinutes(5));
    Check(pairing.IsOpen, "pairing opens");
    Check(pairing.TryPair("wrong", "iPhone").Error == "bad-code", "a wrong code is refused");
    var paired = pairing.TryPair(code, "  Brandon's iPhone  ");
    Check(paired.Ok && paired.Token is not null, "the right code pairs");
    Check(!pairing.TryPair(code, "iPhone").Ok, "a code works only once");
    Check(pairing.IsAuthorized("Bearer " + paired.Token), "the new token is accepted");
    Check(!pairing.IsAuthorized("Bearer nope") && !pairing.IsAuthorized(null) && !pairing.IsAuthorized(paired.Token),
        "bad, missing or malformed tokens are refused");
    Check(pairStore.Devices().Single().Name == "Brandon's iPhone", "the device name is trimmed");
    Check(!File.ReadAllText(Path.Combine(pairDir, "companion-state.json")).Contains(paired.Token!),
        "the token itself is never stored");
    Check(pairStore.RemoveDevice(paired.DeviceId!) && !pairing.IsAuthorized("Bearer " + paired.Token),
        "removing a phone revokes its token");

    var (code2, _) = pairing.Open(TimeSpan.FromMinutes(5));
    for (var i = 0; i < 5; i++) pairing.TryPair("guess" + i, "iPhone");
    Check(!pairing.IsOpen && !pairing.TryPair(code2, "iPhone").Ok, "five wrong guesses close the window");

    var (code3, _) = pairing.Open(TimeSpan.FromMinutes(5));
    pairClock.Advance(TimeSpan.FromMinutes(5));
    Check(pairing.TryPair(code3, "iPhone").Error == "pairing-closed", "the window expires");
}
finally
{
    if (Directory.Exists(pairDir)) Directory.Delete(pairDir, recursive: true);
}

// ---- Focus Guardian ----------------------------------------------------------------------
{
    var t0 = new DateTimeOffset(2026, 1, 1, 9, 0, 0, TimeSpan.Zero);
    GuardianSignal Shorts(int items = 1) => new("youtube-shorts", 10, 0, items, true);
    GuardianSignal Feed(double screens = 4, int items = 0) => new("reddit-feed", 20, screens, items, false);
    GuardianSignal Lecture() => new("youtube-shorts", 0, 0, 0, true);

    // One report in each 30 s bucket for the given seconds; returns the time after them.
    DateTimeOffset Feed30(ScrollGuard g, DateTimeOffset from, int seconds, Func<GuardianSignal?> signal)
    {
        for (var s = 0; s < seconds; s += 30)
            if (signal() is { } x) g.Report(from.AddSeconds(s + 5), x);
        return from.AddSeconds(seconds);
    }

    var guard = new ScrollGuard();
    guard.Reset(t0);
    var t = Feed30(guard, t0, 150, () => Shorts());
    Check(!guard.ShouldRemind(t), "2.5 minutes of Shorts is not enough yet");
    t = Feed30(guard, t, 30, () => Shorts());
    Check(guard.ShouldRemind(t), "3 minutes of swiping Shorts asks for a reminder");
    guard.Reminded(t);
    Check(!guard.ShouldRemind(t) && guard.Cooling(t), "after a reminder it stays quiet");
    t = Feed30(guard, t, 9 * 60, () => Shorts());
    Check(!guard.ShouldRemind(t), "still quiet 9 minutes later (cooldown is 10)");
    t = Feed30(guard, t, 90, () => Shorts());
    Check(guard.ShouldRemind(t), "after the cooldown, steady scrolling is noticed again");

    guard.Reset(t0);
    t = Feed30(guard, t0, 20 * 60, Lecture);
    Check(!guard.ShouldRemind(t) && guard.Sustained(t) == TimeSpan.Zero, "a 20 minute video that plays on is never a reminder");

    guard.Reset(t0);
    t = Feed30(guard, t0, 10 * 60, () => null);
    Check(!guard.ShouldRemind(t), "YouTube or Reddit open with no scrolling reports is never a reminder");

    guard.Reset(t0);
    t = Feed30(guard, t0, 4 * 60, () => Feed(screens: 1));
    Check(!guard.ShouldRemind(t), "slow reading on Reddit (one screen per 30 s) is not doomscrolling");
    t = Feed30(guard, t, 3 * 60, () => Feed());
    Check(guard.ShouldRemind(t), "3 minutes of fast Reddit feed scrolling asks for a reminder");

    guard.Reset(t0);
    var flip = false;
    t = Feed30(guard, t0, 4 * 60, () => (flip = !flip) ? Shorts() : null);
    Check(guard.ShouldRemind(t), "one quiet bucket between Shorts is forgiven (a slow Short)");

    guard.Reset(t0);
    t = Feed30(guard, t0, 120, () => Shorts());
    t = Feed30(guard, t, 60, () => null);
    t = Feed30(guard, t, 90, () => Shorts());
    Check(!guard.ShouldRemind(t), "a full minute away breaks the run");

    guard.Reset(t0);
    t = Feed30(guard, t0, 180, () => Shorts());
    guard.Answered(t, backToWork: true);
    Check(!guard.ShouldRemind(t.AddMinutes(4)), "Back to work: quiet for 5 minutes");
    guard.Answered(t, backToWork: false);
    Check(guard.Cooling(t.AddMinutes(9)) && !guard.Cooling(t.AddMinutes(10)), "Not now: quiet for 10 minutes");

    guard.Reset(t0);
    t = Feed30(guard, t0, 170, () => Shorts());
    guard.Reset(t);
    t = Feed30(guard, t, 30, () => Shorts());
    Check(!guard.ShouldRemind(t), "a new session starts from zero");

    guard.Reset(t0, thresholdSeconds: 5 * 60);
    t = Feed30(guard, t0, 4 * 60, () => Shorts());
    Check(!guard.ShouldRemind(t), "the phone's 5 minute setting: 4 minutes is not enough");
    t = Feed30(guard, t, 60, () => Shorts());
    Check(guard.ShouldRemind(t), "the phone's 5 minute setting: 5 minutes asks for a reminder");
    guard.Reset(t0, thresholdSeconds: 5);
    Check(guard.ThresholdSeconds == 60, "the phone cannot set less than 1 minute");
    guard.Reset(t0);
    Check(guard.ThresholdSeconds == 180, "the next session without a setting goes back to 3 minutes");

    var fast = new ScrollGuard(new GuardianOptions(ThresholdSeconds: 60, BucketSeconds: 10));
    fast.Reset(t0);
    for (var s = 0; s < 60; s += 10) fast.Report(t0.AddSeconds(s + 1), Shorts());
    Check(fast.ShouldRemind(t0.AddSeconds(60)), "the threshold can be set shorter");

    var optionsDir = Path.Combine(Path.GetTempPath(), "lockin-guardian-" + Guid.NewGuid().ToString("N"));
    Directory.CreateDirectory(optionsDir);
    try
    {
        Check(GuardianOptions.Load(optionsDir) == new GuardianOptions(), "no settings file gives the defaults");
        File.WriteAllText(Path.Combine(optionsDir, "guardian.json"), "{\"thresholdSeconds\": 240}");
        Check(GuardianOptions.Load(optionsDir).ThresholdSeconds == 240, "guardian.json sets the threshold");
        File.WriteAllText(Path.Combine(optionsDir, "guardian.json"), "{\"thresholdSeconds\": 1}");
        Check(GuardianOptions.Load(optionsDir).ThresholdSeconds == 60, "a silly threshold is raised to two buckets");
        File.WriteAllText(Path.Combine(optionsDir, "guardian.json"), "not json");
        Check(GuardianOptions.Load(optionsDir) == new GuardianOptions(), "a broken settings file gives the defaults");
    }
    finally { Directory.Delete(optionsDir, recursive: true); }

    Check(GuardianSignal.Parse("{\"v\":1,\"site\":\"reddit-feed\",\"scrolls\":5,\"screens\":2.5,\"items\":1,\"playing\":false,\"focused\":true}")
        == new GuardianSignal("reddit-feed", 5, 2.5, 1, false), "a report is read");
    Check(GuardianSignal.Parse("{\"v\":1,\"site\":\"example.com\",\"focused\":true}") is null, "an unknown site is ignored");
    Check(GuardianSignal.Parse("{\"v\":1,\"site\":\"reddit-feed\",\"focused\":false}") is null, "a tab in the background is ignored");
    Check(GuardianSignal.Parse("{\"v\":2,\"site\":\"reddit-feed\",\"focused\":true}") is null, "an unknown version is ignored");
    Check(GuardianSignal.Parse("[1,2]") is null && GuardianSignal.Parse("{") is null, "junk is ignored");
    Check(GuardianSignal.Parse("{\"v\":1,\"site\":\"youtube-shorts\",\"items\":99999,\"screens\":1e9,\"focused\":true}") is { Items: 30, Screens: 50 },
        "huge numbers are capped");

    using (var frame = new MemoryStream())
    {
        NativeMessages.Write(frame, "{\"ok\":true}");
        frame.Position = 0;
        Check(NativeMessages.Read(frame) == "{\"ok\":true}" && NativeMessages.Read(frame) is null, "native message frames round-trip");
    }
    using (var big = new MemoryStream(BitConverter.GetBytes(NativeMessages.MaxBytes + 1)))
        Check(NativeMessages.Read(big) is null, "an oversized native message is refused");
    Check(NativeHost.IsLaunch(new[] { NativeHost.AllowedOrigin, "--parent-window=0" }) && !NativeHost.IsLaunch(new[] { "--pair" }),
        "a browser launch is recognized");

    var me = Environment.ProcessId;
    FrontWindow.Snapshot Win(int h, string proc, string title, int pid = 1) => new(h, pid, proc, title);
    Check(Distractions.IsWorkWindow(Win(1, "Code", "main.cs - Visual Studio Code"), me), "VS Code is work");
    Check(Distractions.IsWorkWindow(Win(2, "chrome", "Essay - Google Docs - Google Chrome"), me), "Google Docs is work");
    Check(!Distractions.IsWorkWindow(Win(3, "chrome", "#shorts - YouTube - Google Chrome"), me), "YouTube is not a work window");
    Check(!Distractions.IsWorkWindow(Win(4, "explorer", "Program Manager"), me), "the desktop is not a work window");
    Check(!Distractions.IsWorkWindow(Win(5, "notepad", ""), me), "an untitled window is not a work window");
    Check(!Distractions.IsWorkWindow(Win(6, "LockIn.Companion", "Lock In", me), me), "the buddy itself is not a work window");

    Check(!Distractions.IsWorkWindow(Win(7, "chrome", "Untitled - Google Chrome"), me)
        && !Distractions.IsWorkWindow(Win(7, "msedge", "New Tab - Personal - Microsoft Edge"), me),
        "a browser still loading (Untitled, New Tab) is not a work window");

    var memory = new WorkWindowMemory();
    void SeenFor(int seconds, FrontWindow.Snapshot w) { for (var i = 0; i < seconds; i++) memory.Seen(w, me); }
    Check(memory.TargetFor(Win(9, "chrome", "x - YouTube")) is null, "no work seen yet: nothing to bring back");
    SeenFor(5, Win(1, "WINWORD", "Report.docx - Word"));
    SeenFor(1, Win(9, "chrome", "Untitled - Google Chrome"));
    SeenFor(10, Win(9, "chrome", "Shorts - YouTube - Google Chrome"));
    Check(memory.TargetFor(Win(9, "chrome", "Shorts - YouTube")) == 1,
        "Back to work goes to Word, not the browser that flashed 'Untitled' while loading");
    SeenFor(2, Win(5, "Code", "notes.md - Visual Studio Code"));
    Check(memory.TargetFor(Win(9, "chrome", "Shorts - YouTube")) == 1, "a window in front for under 3 seconds does not count");
    SeenFor(3, Win(9, "chrome", "Essay - Google Docs"));
    Check(memory.TargetFor(Win(9, "chrome", "Shorts - YouTube")) is null,
        "work in the same browser window: no window to switch to (it is a tab)");
    memory.Clear();
    Check(memory.Last is null, "a new session forgets the work window");

    // ---- every browser must have the extension ----
    var guardDir = Path.Combine(Path.GetTempPath(), "lockin-browsers-" + Guid.NewGuid().ToString("N"));
    Directory.CreateDirectory(guardDir);
    try
    {
        var b = new BrowserGuard(TimeSpan.FromSeconds(60), guardDir);
        Check(b.Check(t0, "chrome").Problem == BrowserGuard.Problem.None && !b.Required,
            "before the extension was ever set up, no browser is touched");
        b.Heartbeat(t0, new BrowserHeartbeat("chrome", Incognito: true));
        Check(b.Required && File.Exists(Path.Combine(guardDir, "browser-extension-seen")), "the first heartbeat makes the extension required");
        Check(new BrowserGuard(TimeSpan.FromSeconds(60), guardDir).Required, "required stays on after a restart");
        Check(b.Check(t0.AddSeconds(10), "chrome").Problem == BrowserGuard.Problem.None, "Chrome with the extension is fine");
        var edge = b.Check(t0.AddSeconds(10), "msedge");
        Check(edge.Problem == BrowserGuard.Problem.Missing && !edge.Paused && edge.SecondsLeft == 60, "Edge without it gets a warning first");
        Check(b.Check(t0.AddSeconds(69), "msedge") is { Paused: false, SecondsLeft: 1 }, "the warning lasts the grace time");
        Check(b.Check(t0.AddSeconds(70), "msedge").Paused, "then Edge is paused");
        Check(b.Check(t0.AddSeconds(70), "firefox").Problem == BrowserGuard.Problem.Missing, "a browser that never reported is not covered");
        Check(b.Check(t0.AddSeconds(56), "chrome").Problem == BrowserGuard.Problem.Missing, "no heartbeat for 45 s: the extension counts as off");
        b.Heartbeat(t0.AddSeconds(80), new BrowserHeartbeat("msedge", Incognito: false));
        Check(b.Check(t0.AddSeconds(80), "msedge").Problem == BrowserGuard.Problem.PrivateOff, "extension on but not in private windows is not enough");
        b.Heartbeat(t0.AddSeconds(90), new BrowserHeartbeat("msedge", Incognito: true));
        Check(b.Check(t0.AddSeconds(90), "msedge") is { Problem: BrowserGuard.Problem.None, Paused: false }, "turning it on ends the pause at once");
        Check(b.Check(t0.AddSeconds(91), "brave").SecondsLeft == 60, "each browser gets its own grace time");
        b.ResetWarnings();
        Check(b.Check(t0.AddSeconds(200), "brave").SecondsLeft == 60, "a new session starts the grace time again");
    }
    finally { Directory.Delete(guardDir, recursive: true); }

    Check(BrowserHeartbeat.Parse("{\"v\":1,\"kind\":\"alive\",\"browser\":\"MSEdge\",\"incognito\":true}") == new BrowserHeartbeat("msedge", true),
        "a heartbeat line is read");
    Check(BrowserHeartbeat.Parse("{\"v\":1,\"site\":\"reddit-feed\",\"focused\":true}") is null, "a scrolling report is not a heartbeat");
    Check(BrowserHeartbeat.IncognitoFromExtension("{\"v\":1,\"kind\":\"alive\",\"incognito\":false}") == false
        && BrowserHeartbeat.IncognitoFromExtension("{\"v\":1}") is null, "the extension's alive message is read");
    Check(NativeHost.IsLaunch(new[] { @"C:\x\native-host-firefox.json", NativeHost.FirefoxId }), "a Firefox launch is recognized");
}

Console.WriteLine("All session checks passed.");

static void Check(bool condition, string description)
{
    if (!condition) throw new InvalidOperationException("Failed: " + description);
    Console.WriteLine("PASS: " + description);
}

sealed class TestClock(DateTimeOffset now) : TimeProvider
{
    private DateTimeOffset current = now;
    public override DateTimeOffset GetUtcNow() => current;
    public void Advance(TimeSpan amount) => current = current.Add(amount);
}
