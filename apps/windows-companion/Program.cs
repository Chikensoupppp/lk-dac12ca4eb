var builder = WebApplication.CreateBuilder(args);
builder.WebHost.UseUrls("http://127.0.0.1:47821");
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddSingleton<SessionStore>();
var app = builder.Build();

app.MapGet("/health", (SessionStore store) => Results.Ok(new
{
    service = "lock-in-windows-companion",
    status = "ready",
    session = store.Current,
    capabilities = new[] { "loopback-session" }
}));

app.MapPost("/session/start", (StartSessionRequest request, SessionStore store) =>
{
    if (request.DurationSeconds is < 60 or > 86400)
        return Results.BadRequest(new { error = "durationSeconds must be between 60 and 86400" });
    return store.TryStart(request.DurationSeconds, out var session)
        ? Results.Ok(session)
        : Results.Conflict(new { error = "A focus session is already active.", session });
});

app.MapPost("/session/stop", (SessionStore store) => Results.Ok(store.Stop()));
app.Run();

public sealed record StartSessionRequest(int DurationSeconds);

public sealed record FocusSession(
    string Id,
    string State,
    int DurationSeconds,
    DateTimeOffset? StartedAt,
    DateTimeOffset? EndsAt);

public sealed class SessionStore
{
    private readonly object gate = new();
    private readonly TimeProvider clock;
    private FocusSession current = new("none", "idle", 0, null, null);
    public SessionStore(TimeProvider clock) => this.clock = clock;
    public FocusSession Current
    {
        get
        {
            lock (gate)
            {
                ExpireIfNeeded();
                return current;
            }
        }
    }

    public bool TryStart(int durationSeconds, out FocusSession session)
    {
        lock (gate)
        {
            ExpireIfNeeded();
            if (current.State is "starting" or "active")
            {
                session = current;
                return false;
            }
            var now = clock.GetUtcNow();
            current = new(Guid.NewGuid().ToString("N"), "active", durationSeconds, now, now.AddSeconds(durationSeconds));
            session = current;
            return true;
        }
    }

    public FocusSession Stop()
    {
        lock (gate)
        {
            current = current with { State = "idle" };
            return current;
        }
    }

    private void ExpireIfNeeded()
    {
        if (current.State == "active" && current.EndsAt <= clock.GetUtcNow())
            current = current with { State = "idle" };
    }
}
