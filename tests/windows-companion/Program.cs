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
