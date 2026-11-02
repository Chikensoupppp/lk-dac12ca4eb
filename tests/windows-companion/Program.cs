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
