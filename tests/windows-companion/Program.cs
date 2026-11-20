using LockIn.Companion.Watch;

LaterChecks.Run(Check);

// Plus on the PC: RevenueCat's subscriber JSON decides, never the phone's word.
var plusNow = new DateTimeOffset(2026, 11, 16, 12, 0, 0, TimeSpan.Zero);
Check(PlusCheck.IsActive("{\"subscriber\":{\"entitlements\":{\"nogbox_pro\":{\"expires_date\":\"2027-11-16T12:00:00Z\"}}}}", plusNow),
    "plus: entitlement with a future expiry is active");
Check(!PlusCheck.IsActive("{\"subscriber\":{\"entitlements\":{\"nogbox_pro\":{\"expires_date\":\"2026-11-01T12:00:00Z\"}}}}", plusNow),
    "plus: an expired entitlement is not active");
Check(PlusCheck.IsActive("{\"subscriber\":{\"entitlements\":{\"nogbox_pro\":{\"expires_date\":null}}}}", plusNow),
    "plus: no expiry (lifetime) is active");
Check(!PlusCheck.IsActive("{\"subscriber\":{\"entitlements\":{}}}", plusNow), "plus: no entitlement is not active");
Check(!PlusCheck.IsActive("not json", plusNow), "plus: bad JSON is not active");
Check(!new PlusCheck(TimeProvider.System, null).HasPlusAsync(null).GetAwaiter().GetResult(), "plus: no user id means no Plus");

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

    // Judged by address, not by title: a Reddit post's title never says "Reddit".
    Check(BrowserSites.NameOf("https://www.reddit.com/r/aww/comments/abc/funny_cat/") == "Reddit"
        && BrowserSites.NameOf("old.reddit.com/r/all") == "Reddit"
        && BrowserSites.NameOf("https://m.youtube.com/watch?v=x") == "YouTube"
        && BrowserSites.NameOf("youtu.be/abc") == "YouTube"
        && BrowserSites.NameOf("https://www.twitch.tv/somebody") == "Twitch",
        "sites are recognized by their address");
    Check(BrowserSites.NameOf("https://docs.google.com/document/d/1") is null
        && BrowserSites.NameOf("https://notreddit.com/") is null
        && BrowserSites.NameOf("https://youtube.com.example.org/") is null
        && BrowserSites.NameOf("") is null && BrowserSites.NameOf(null) is null,
        "look-alike and other addresses are not mistaken for a distraction site");
    var postTab = Win(50, "chrome", "Funny cat : r/aww - Google Chrome");
    Check(Distractions.IsWorkWindow(postTab, me), "a Reddit post page passes as work when only its title is read");
    BrowserSites.Record(50, "Reddit", 1_000);
    Check(BrowserSites.For(50, 3_000) == "Reddit" && BrowserSites.For(51, 3_000) is null && BrowserSites.For(50, 7_000) is null,
        "the site read from the address counts for 5 s, for that window only");
    BrowserSites.Record(50, "Reddit");
    Check(Distractions.IsDistraction(postTab) && !Distractions.IsWorkWindow(postTab, me)
        && Distractions.NameOf(postTab) == "Reddit" && Distractions.KeyOf(postTab) == "reddit",
        "a Reddit post page is a distraction once its address is read");
    BrowserSites.Record(50, null);
    Check(Distractions.IsWorkWindow(Win(50, "chrome", "Essay - Google Docs - Google Chrome"), me),
        "a work page stays work after its address is read");
    BrowserSites.Clear();
    Check(Distractions.IsBrowserProcess("palemoon") && Distractions.IsBrowserProcess("Whale") && !Distractions.IsBrowserProcess("notepad"),
        "more browsers are known by process name");

    // The wider list: more sites by address, more chat apps and the common games.
    Check(BrowserSites.NameOf("https://x.com/home") == "X" && BrowserSites.NameOf("mobile.twitter.com/someone") == "X"
        && BrowserSites.NameOf("https://www.facebook.com/reel/1") == "Facebook" && BrowserSites.NameOf("fb.watch/abc") == "Facebook"
        && BrowserSites.NameOf("https://www.snapchat.com/") == "Snapchat" && BrowserSites.NameOf("https://www.disneyplus.com/home") == "Disney+"
        && BrowserSites.NameOf("https://www.hulu.com/watch/1") == "Hulu" && BrowserSites.NameOf("https://www.primevideo.com/") == "Prime Video",
        "more sites are recognized by their address");
    Check(BrowserSites.NameOf("https://box.com/") is null && BrowserSites.NameOf("https://notx.com/") is null
        && BrowserSites.NameOf("https://x.com.example.org/") is null && BrowserSites.NameOf("https://fb.com.example.org/") is null,
        "look-alikes of the new sites are not mistaken for them");
    Check(Distractions.IsDistraction(Win(61, "cs2", "Counter-Strike 2")) && Distractions.IsDistraction(Win(62, "RobloxPlayerBeta", "Roblox"))
        && Distractions.IsDistraction(Win(63, "Signal", "Signal")) && Distractions.IsDistraction(Win(64, "League of Legends", "League of Legends (TM) Client"))
        && Distractions.FriendlyName("cs2") == "Counter-Strike 2" && Distractions.FriendlyName("RobloxPlayerBeta") == "Roblox",
        "common games and one more chat app count as distractions, with plain names");
    Check(Distractions.IsWorkWindow(Win(65, "RobloxStudioBeta", "Place1 - Roblox Studio"), me)
        && Distractions.IsWorkWindow(Win(66, "Code", "Program.cs - Visual Studio Code"), me),
        "a game maker's editor stays work");
    Check(new[] { "UnrealEditor", "Unity", "blender", "godot", "Code", "EXCEL" }
            .Select((p, i) => Win(70 + i, p, "Project - " + p)).All(w => Distractions.IsWorkWindow(w, me)),
        "game engines, editors and office apps are work");
    var moreGames = new (string Proc, string Name)[]
    {
        ("tslgame", "PUBG"), ("cod", "Call of Duty"), ("RainbowSix", "Rainbow Six Siege"), ("Terraria", "Terraria"),
        ("Stardew Valley", "Stardew Valley"), ("Cyberpunk2077", "Cyberpunk 2077"), ("bg3", "Baldur's Gate 3"),
        ("Wow", "World of Warcraft"), ("FC26", "EA Sports FC"), ("osu!", "osu!"), ("retroarch", "RetroArch"),
        ("FactoryGame-Win64-Shipping", "Satisfactory"), ("XboxPcApp", "Xbox app"), ("steamwebhelper", "Steam"),
    };
    Check(moreGames.Select((g, i) => (g, w: Win(80 + i, g.Proc, g.Proc))).All(x =>
            Distractions.IsDistraction(x.w) && !Distractions.IsWorkWindow(x.w, me) && Distractions.FriendlyName(x.g.Proc) == x.g.Name),
        "more games are distractions, each with its plain name");

    // Any game, not just the named ones: the rules behind GameDetector (the signals themselves are checked live).
    Check(GameDetector.InLibrary(@"D:\SteamLibrary\steamapps\common\Hades\Hades.exe")
        && GameDetector.InLibrary(@"C:\Program Files\Epic Games\Fortnite\FortniteGame\Binaries\Win64\FortniteClient-Win64-Shipping.exe")
        && GameDetector.InLibrary("D:/Games/Foo/foo.exe") && GameDetector.InLibrary(@"C:\XboxGames\Halo\Gamelaunch.exe"),
        "a program inside a game library counts as a game");
    Check(!GameDetector.InLibrary(@"C:\Program Files\Epic Games\UE_5.4\Engine\Binaries\Win64\UnrealEditor.exe")
        && !GameDetector.InLibrary(@"C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE")
        && !GameDetector.InLibrary(@"C:\Users\me\Documents\Notes\todo.exe") && !GameDetector.InLibrary(null) && !GameDetector.InLibrary(""),
        "work programs, the Unreal editor and empty paths are not in a game library");
    Check(GameDetector.IsLauncher("Steam") && GameDetector.IsLauncher("EpicGamesLauncher") && GameDetector.IsLauncher("Battle.net")
        && GameDetector.IsLauncher("RiotClientServices") && !GameDetector.IsLauncher("explorer") && !GameDetector.IsLauncher("chrome"),
        "game launchers are known, ordinary parents are not");
    Check(GameDetector.IsSdkFile("Steam_API64.dll") && GameDetector.IsSdkFile("UnityPlayer.dll") && GameDetector.IsSdkFile("EOSSDK-Win64-Shipping.dll")
        && !GameDetector.IsSdkFile("kernel32.dll") && !GameDetector.IsSdkFile("d3d11.dll"),
        "game SDK files are known, system and graphics libraries are not");
    var sdkRoot = Path.Combine(Path.GetTempPath(), "sdkfiles-" + Guid.NewGuid().ToString("N")[..8]);
    try
    {
        var sdkBin = Path.Combine(sdkRoot, "bin", "deep");
        Directory.CreateDirectory(sdkBin);
        var plain = Path.Combine(sdkRoot, "plain");
        Directory.CreateDirectory(plain);
        File.WriteAllText(Path.Combine(sdkRoot, "bin", "steam_api64.dll"), "x");
        Check(GameDetector.SdkFilesNear(Path.Combine(sdkRoot, "bin", "game.exe")) && GameDetector.SdkFilesNear(Path.Combine(sdkBin, "game.exe")),
            "a game SDK file next to the program, or one folder up, marks a game");
        Check(!GameDetector.SdkFilesNear(Path.Combine(plain, "tool.exe")) && !GameDetector.SdkFilesNear(Path.Combine(sdkBin, "deeper", "x", "tool.exe"))
            && !GameDetector.SdkFilesNear(null) && !GameDetector.SdkFilesNear(""),
            "no SDK file near, two folders away, or no path: not a game");
    }
    finally { try { Directory.Delete(sdkRoot, true); } catch (IOException) { } }
    var chain = GameDetector.Ancestors(Environment.ProcessId, 3);
    Check(chain.Count > 0 && chain.All(n => n == n.ToLowerInvariant() && !n.EndsWith(".exe")) && GameDetector.Ancestors(-5, 3).Count == 0,
        "the launcher chain is read from a process list, lower case, and is empty for a process that does not exist");
    Check(GameDetector.CoversScreen(0, 0, 1920, 1080, 0, 0, 1920, 1080) && GameDetector.CoversScreen(-8, -8, 1928, 1088, 0, 0, 1920, 1080)
        && !GameDetector.CoversScreen(100, 100, 1500, 900, 0, 0, 1920, 1080) && !GameDetector.CoversScreen(0, 0, 1920, 1040, 0, 0, 1920, 1080),
        "only a window that covers the whole monitor counts as full screen");
    Check(GameDetector.CleanName("FortniteClient-Win64-Shipping") == "FortniteClient" && GameDetector.CleanName("Some_Game_x64") == "Some Game"
        && GameDetector.CleanName("hades") == "hades" && !GameDetector.UsableProductName("Unity") && !GameDetector.UsableProductName(null)
        && GameDetector.UsableProductName("Hades"),
        "an unknown game gets a readable name");
    Check(!Distractions.IsDistraction(Win(90, "blender", "Blender"))
        && !Distractions.IsDistraction(Win(91, "notepad", "Untitled - Notepad", Environment.ProcessId)),
        "work programs and Lock In itself are never taken for games");
    Check(Distractions.IsDistraction(Win(67, "chrome", "Reels | Facebook - Google Chrome")) && Distractions.NameOf(Win(67, "chrome", "Reels | Facebook - Google Chrome")) == "Facebook",
        "a Facebook tab is caught by its title when the address cannot be read");
    Check(new[] { "x", "facebook", "snapchat" }.All(k => Distractions.Choices.Any(c => c.Key == k))
        && Distractions.Choices.Select(c => c.Key).Distinct().Count() == Distractions.Choices.Count,
        "the phone chips include the new sites once each");

    // Browser games, by address.
    Check(BrowserSites.NameOf("https://poki.com/en/g/subway-surfers") == "Poki" && BrowserSites.NameOf("https://www.crazygames.com/game/x") == "CrazyGames"
        && BrowserSites.NameOf("https://somebody.itch.io/jam-game") == "itch.io" && BrowserSites.NameOf("https://krunker.io/") == "Krunker"
        && BrowserSites.NameOf("https://www.roblox.com/games/1/x") == "Roblox" && BrowserSites.NameOf("https://www.chess.com/play/online") == "Chess.com"
        && BrowserSites.NameOf("https://lichess.org/") == "Lichess" && BrowserSites.NameOf("https://play.geforcenow.com/mall/") == "GeForce Now",
        "browser game sites and portals are recognized by address");
    Check(BrowserSites.NameOf("https://www.xbox.com/en-US/play") == "Xbox Cloud Gaming" && BrowserSites.NameOf("https://www.xbox.com/en-US/games/store") is null
        && BrowserSites.NameOf("https://www.nytimes.com/games/wordle/index.html") == "NYT Games" && BrowserSites.NameOf("https://www.nytimes.com/section/world") is null,
        "a site is matched on its path where only part of it is a game (cloud gaming, news games)");
    Check(BrowserSites.NameOf("https://create.roblox.com/dashboard") is null && BrowserSites.NameOf("https://devforum.roblox.com/") is null
        && BrowserSites.NameOf("https://www.notpoki.com/") is null && BrowserSites.NameOf("https://poki.com.example.org/") is null
        && BrowserSites.NameOf("https://github.com/itch-io/x") is null,
        "game site look-alikes and Roblox's developer sites are not taken for games");
    Check(BrowserSites.NameOf("https://some-unblocked-games.example.org/") == "Unblocked Games"
        && BrowserSites.NameOf("https://sites.google.com/view/unblocked-games-77") == "Unblocked Games"
        && BrowserSites.NameOf("https://docs.example.org/blocked-ips") is null,
        "'unblocked games' sites are caught by the word, the rest of the web is not");

    // Two browser windows: each keeps its own site (the work page in front, a game on the other monitor).
    BrowserSites.Record(300, null, 1_000);
    BrowserSites.Record(301, "Poki", 1_200);
    Check(BrowserSites.For(300, 2_000) is null && BrowserSites.For(301, 2_000) == "Poki" && BrowserSites.For(302, 2_000) is null,
        "each browser window keeps its own site: a game on the other monitor does not leak onto the work window");
    var gameTab = Win(301, "msedge", "Subway Surfers - Play Online - Personal - Microsoft Edge");
    var workTab = Win(300, "msedge", "Essay - Google Docs - Personal - Microsoft Edge");
    BrowserSites.Record(300, null);
    BrowserSites.Record(301, "Poki");
    Check(Distractions.IsDistraction(gameTab) && Distractions.NameOf(gameTab) == "Poki" && !Distractions.IsDistraction(workTab),
        "a game tab whose title does not say so is a distraction once its address is read; the other window stays work");
    BrowserSites.Clear();

    // Store apps and Minecraft, which only show up through a title.
    Check(Distractions.IsDistraction(Win(310, "ApplicationFrameHost", "Netflix")) && Distractions.NameOf(Win(310, "ApplicationFrameHost", "Netflix")) == "Netflix"
        && Distractions.IsDistraction(Win(311, "ApplicationFrameHost", "TikTok")) && !Distractions.IsDistraction(Win(312, "ApplicationFrameHost", "Settings")),
        "a Store app window titled Netflix or TikTok is a distraction, Settings is not");
    Check(Distractions.IsDistraction(Win(313, "javaw", "Minecraft 1.21.4 - Singleplayer")) && Distractions.NameOf(Win(313, "javaw", "Minecraft 1.21.4")) == "Minecraft"
        && !Distractions.IsDistraction(Win(314, "javaw", "IntelliJ IDEA")),
        "Minecraft running in Java is a game, other Java programs are not");
    Check(new[] { "bluestacks", "dnplayer", "geforcenow", "moonlight" }.Select((p, i) => Win(320 + i, p, p)).All(Distractions.IsDistraction),
        "Android emulators and game streaming apps are distractions");

    // Which parts of a window show, on any monitor (pure rectangle math).
    var whole = new Box(0, 0, 1000, 1000);
    Check(VisibleWindows.VisibleArea(whole, Array.Empty<Box>()) == 1_000_000
        && VisibleWindows.VisibleArea(whole, new[] { new Box(0, 0, 500, 1000) }) == 500_000
        && VisibleWindows.VisibleArea(whole, new[] { new Box(-10, -10, 1100, 1100) }) == 0
        && VisibleWindows.VisibleArea(new Box(5, 5, 5, 50), Array.Empty<Box>()) == 0,
        "visible area: nothing in front, half covered, fully covered, empty window");
    Check(VisibleWindows.VisibleArea(whole, new[] { new Box(0, 0, 600, 500), new Box(400, 0, 1000, 500) }) == 500_000
        && VisibleWindows.VisibleArea(whole, new[] { new Box(0, 0, 500, 500), new Box(0, 0, 500, 500) }) == 750_000,
        "visible area: overlapping windows in front are not counted twice");
    Check(VisibleWindows.VisibleArea(whole, new[] { new Box(2000, 0, 3000, 1000), new Box(-1920, 0, -1, 1080) }) == 1_000_000
        && VisibleWindows.VisibleArea(new Box(1920, 0, 3840, 1080), new[] { new Box(0, 0, 1920, 1080) }) == 1920L * 1080,
        "visible area: a window on another monitor covers nothing");
    Check(VisibleWindows.Prominent(500_000, 1_000_000) && VisibleWindows.Prominent(60_000, 200_000)
        && !VisibleWindows.Prominent(59_999, 100_000) && !VisibleWindows.Prominent(100_000, 1_000_000) && !VisibleWindows.Prominent(0, 0),
        "a window counts as in view with enough of it showing (60,000 px and a quarter of it), not a sliver");
    var tree = new Dictionary<uint, ProcessList.Entry>
    {
        [10] = new(0, "System"), [20] = new(10, "Steam"), [30] = new(20, "Game.exe-host"), [40] = new(30, "Game"), [50] = new(999, "Orphan"),
    };
    Check(ProcessList.Ancestors(tree, 40, 3).SequenceEqual(new[] { "game.exe-host", "steam", "system" })
        && ProcessList.Ancestors(tree, 40, 1).SequenceEqual(new[] { "game.exe-host" })
        && ProcessList.Ancestors(tree, 50, 3).Count == 0 && ProcessList.Ancestors(tree, 77, 3).Count == 0 && ProcessList.Ancestors(tree, 10, 3).Count == 0,
        "ancestors: nearest first, lower case, stops at a missing parent or at the top");
    Check(Distractions.Choices.Any(c => c.Key == "netflix") && Distractions.Choices.Any(c => c.Key == "twitch") && Distractions.Choices.Count == 13,
        "the phone chips are the 13 sites and apps");

    // The PC clock moved in small steps: the steps add up instead of each one passing under the limit.
    var drift = new ClockDrift();
    var driftWall = new DateTimeOffset(2026, 11, 20, 12, 0, 0, TimeSpan.Zero);
    long driftTicks = 1_000_000;
    Check(drift.Observe(driftWall, driftTicks) is null, "clock drift: the first look only sets the start");
    var quiet = true;
    for (var i = 0; i < 30; i++) { driftWall = driftWall.AddSeconds(2); driftTicks += 2000; quiet &= drift.Observe(driftWall, driftTicks) is null; }
    Check(quiet, "clock drift: a clock that keeps time is never flagged");
    TimeSpan? caught = null;
    var steps = 0;
    while (caught is null && steps < 20) { driftWall = driftWall.AddSeconds(2 + 4); driftTicks += 2000; steps++; caught = drift.Observe(driftWall, driftTicks); }
    Check(steps == 3 && caught is { } c1 && c1 > TimeSpan.FromSeconds(10) && c1 < TimeSpan.FromSeconds(14),
        "clock drift: three 4 s steps forward add up to a correction");
    driftWall = driftWall.AddSeconds(2); driftTicks += 2000;
    Check(drift.Observe(driftWall, driftTicks) is null, "clock drift: the correction starts over");
    driftWall = driftWall.AddSeconds(2 - 3600); driftTicks += 2000;
    Check(drift.Observe(driftWall, driftTicks) is { } back && back < TimeSpan.FromMinutes(-59), "clock drift: an hour back is caught at once");
    drift.Reset();
    Check(drift.Observe(driftWall.AddHours(5), driftTicks + 2000) is null, "clock drift: after a reset the next look is the new start");

    // A free session: two short passes, taken only after a moment, that do not come back.
    var pass = new FreePasses();
    var p0 = new DateTimeOffset(2026, 11, 20, 12, 0, 0, TimeSpan.Zero);
    Check(pass.CanAsk && pass.Left == 2 && !pass.IsOpen("youtube", p0), "passes: two to start with, none open");
    Check(!pass.TryUse("youtube", p0.AddSeconds(1), p0, out var toWait) && toWait > TimeSpan.FromSeconds(1.9) && toWait < TimeSpan.FromSeconds(2.1)
        && pass.Left == 2 && !pass.IsOpen("youtube", p0.AddSeconds(1)),
        "passes: a yes right away does not count and says how long to wait");
    Check(pass.TryUse("youtube", p0.AddSeconds(3), p0, out _) && pass.Left == 1 && pass.CanAsk, "passes: a yes after 3 s spends one");
    Check(pass.IsOpen("youtube", p0.AddMinutes(14)) && !pass.IsOpen("youtube", p0.AddMinutes(18)) && !pass.IsOpen("reddit", p0.AddMinutes(1)),
        "passes: a pass opens only that site, for 15 minutes");
    var p1 = p0.AddMinutes(20);
    Check(!pass.TryUse("reddit", p1.AddSeconds(4), p1, out var toWait2) && toWait2 > TimeSpan.FromSeconds(1.9) && pass.Left == 1,
        "passes: the second one makes you wait longer (6 s)");
    Check(pass.TryUse("reddit", p1.AddSeconds(6), p1, out _) && pass.Left == 0 && !pass.CanAsk, "passes: the last pass is spent");
    Check(!pass.TryUse("youtube", p1.AddMinutes(30), p1.AddMinutes(29), out _), "passes: none left means no");
    pass.Reset();
    Check(pass.Left == 2 && pass.CanAsk && !pass.IsOpen("reddit", p1.AddSeconds(7)), "passes: a new session starts with two again");
    Check(BuddyWords.PassGiven("YouTube", 15, 1).Contains("1 pass left") && BuddyWords.PassGiven("YouTube", 15, 0).Contains("last pass")
        && BuddyWords.NoPasses("Reddit").StartsWith("No passes left") && BuddyWords.PassWait(3).Contains("3 s"),
        "passes: the buddy's words");

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
