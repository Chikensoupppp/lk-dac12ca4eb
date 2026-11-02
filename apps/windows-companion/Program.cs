using System.Collections.Concurrent;

var builder = WebApplication.CreateBuilder(args);
builder.WebHost.UseUrls("http://127.0.0.1:47821");
builder.Services.AddSingleton<SessionStore>();
var app = builder.Build();

app.MapGet("/health", (SessionStore store) => Results.Ok(new
{
    service = "lock-in-windows-companion",
    status = "ready",
    session = store.Current,
    capabilities = new[] { "loopback-session", "workspace-launcher-placeholder" }
}));

app.MapPost("/session/start", (StartSessionRequest request, SessionStore store) =>
{
    if (request.DurationSeconds is < 60 or > 86400)
        return Results.BadRequest(new { error = "durationSeconds must be between 60 and 86400" });
    return Results.Ok(store.Start(request.DurationSeconds));
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
    private FocusSession current = new("none", "idle", 0, null, null);
    public FocusSession Current { get { lock (gate) return current; } }

    public FocusSession Start(int durationSeconds)
    {
        lock (gate)
        {
            if (current.State is "starting" or "active")
                throw new InvalidOperationException("A focus session is already active.");
            var now = DateTimeOffset.UtcNow;
            current = new(Guid.NewGuid().ToString("N"), "active", durationSeconds, now, now.AddSeconds(durationSeconds));
            return current;
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
}
