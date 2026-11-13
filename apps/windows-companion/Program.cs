using System.Diagnostics;
using System.Net;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using LockIn.Companion.Watch;
using QRCoder;

// Two doors:
//   http://127.0.0.1:47821   this PC only (kept for local checks and the future tray app)
//   https://0.0.0.0:47822    the local network, for the paired phone. Everything except /health and /pair needs a token.
const int LoopbackPort = 47821;
const int LanPort = 47822;

var stateDir = Environment.GetEnvironmentVariable("LOCKIN_STATE_DIR")
    ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "LockIn");

// Chrome or Edge started this program for the Lock In extension: pass its reports on, nothing else.
if (NativeHost.IsLaunch(args))
{
    Environment.ExitCode = NativeHost.Run(args);
    return;
}
if (args.Contains("--register-browser"))
{
    Console.WriteLine("Chrome and Edge can now reach Lock In. Host file: "
        + BrowserRegistration.Register(stateDir, Environment.ProcessPath!));
    return;
}
if (args.Contains("--unregister-browser"))
{
    BrowserRegistration.Unregister();
    Console.WriteLine("Removed the Chrome and Edge link.");
    return;
}
var stateStore = new CompanionStateStore(stateDir);
var certificate = stateStore.LoadOrCreateCertificate();
var fingerprint = CompanionStateStore.Fingerprint(certificate);
var pairing = new PairingService(stateStore, TimeProvider.System);

var builder = WebApplication.CreateBuilder(args);
builder.WebHost.ConfigureKestrel(kestrel =>
{
    kestrel.Listen(IPAddress.Loopback, LoopbackPort);
    kestrel.Listen(IPAddress.Any, LanPort, listen => listen.UseHttps(certificate));
});
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddSingleton<SessionStore>();
builder.Services.AddSingleton(new AllowStore(stateDir));
builder.Services.AddSingleton(sp => new SessionWatch(sp.GetRequiredService<TimeProvider>(), sp.GetRequiredService<AllowStore>(),
    GuardianOptions.Load(stateDir), stateDir));
builder.Services.AddSingleton(pairing);
var app = builder.Build();

var pairingWindow = TimeSpan.FromMinutes(5);
PairingOffer OpenPairing()
{
    var (code, expires) = pairing.Open(pairingWindow);
    return new PairingOffer(1, LanAddresses.Find(), LanPort, fingerprint, code, expires);
}

static bool IsLoopbackRequest(HttpContext ctx) =>
    ctx.Connection.LocalPort == LoopbackPort
    && ctx.Connection.RemoteIpAddress is { } remote && IPAddress.IsLoopback(remote);

app.Use(async (ctx, next) =>
{
    var onLan = ctx.Connection.LocalPort == LanPort;
    var path = ctx.Request.Path.Value ?? "";
    if (path.StartsWith("/pairing", StringComparison.Ordinal) && !IsLoopbackRequest(ctx))
    {
        ctx.Response.StatusCode = StatusCodes.Status404NotFound;
        return;
    }
    if (onLan && path != "/health" && path != "/pair"
        && !pairing.IsAuthorized(ctx.Request.Headers.Authorization.ToString()))
    {
        ctx.Response.StatusCode = StatusCodes.Status401Unauthorized;
        await ctx.Response.WriteAsJsonAsync(new { error = "unauthorized" });
        return;
    }
    await next();
});

app.MapGet("/health", (HttpContext ctx, SessionStore store, TimeProvider time) =>
{
    var onLan = ctx.Connection.LocalPort == LanPort;
    return Results.Ok(new
    {
        service = "lock-in-windows-companion",
        status = "ready",
        serverTime = time.GetUtcNow(),
        // The session is private to paired phones; the open LAN door shows no session.
        session = onLan ? null : store.Current,
        capabilities = new[] { "loopback-session", "lan-pairing", "session-mirror" }
    });
});

app.MapGet("/session", (SessionStore store, TimeProvider time) =>
    Results.Ok(new { session = store.Current, serverTime = time.GetUtcNow() }));

app.MapPost("/pair", (PairRequest request, PairingService service, SessionWatch watch, TimeProvider time) =>
{
    var result = service.TryPair(request.Code, request.DeviceName);
    if (result.Ok) watch.Greet(BuddyWords.Paired);
    if (result.Ok)
        return Results.Ok(new
        {
            deviceId = result.DeviceId,
            token = result.Token,
            serverTime = time.GetUtcNow(),
            capabilities = new[] { "session-mirror" }
        });
    return result.Error == "pairing-closed"
        ? Results.Json(new { error = result.Error }, statusCode: StatusCodes.Status403Forbidden)
        : Results.Json(new { error = result.Error }, statusCode: StatusCodes.Status401Unauthorized);
});

// Loopback only (see middleware): open a pairing window, list paired phones, remove one.
app.MapPost("/pairing/open", () => Results.Ok(OpenPairing()));
app.MapGet("/pairing/devices", () =>
    Results.Ok(stateStore.Devices().Select(d => new { d.Id, d.Name, d.PairedAt })));
app.MapDelete("/pairing/devices/{id}", (string id) =>
    stateStore.RemoveDevice(id) ? Results.NoContent() : Results.NotFound());

app.MapPost("/session/start", (StartSessionRequest request, SessionStore store, SessionWatch watch, TimeProvider time) =>
{
    if (request.DurationSeconds is < 60 or > 86400)
        return Results.BadRequest(new { error = "durationSeconds must be between 60 and 86400" });
    var id = request.Id ?? Guid.NewGuid().ToString("N");
    if (!Regex.IsMatch(id, "^[A-Za-z0-9-]{1,64}$"))
        return Results.BadRequest(new { error = "id must be 1-64 letters, digits or dashes" });
    var startedAt = request.StartedAt ?? time.GetUtcNow();

    var outcome = store.TryStart(id, request.DurationSeconds, startedAt, out var session);
    if (outcome is StartOutcome.Started or StartOutcome.Existing)
        watch.Begin(session.Id, request.Buddy, session.StartedAt ?? time.GetUtcNow(), session.DurationSeconds, request.Task, request.Allow, request.GuardianSeconds);
    return outcome switch
    {
        StartOutcome.Started or StartOutcome.Existing => Results.Ok(session),
        StartOutcome.Conflict => Results.Conflict(new { error = "A focus session is already active.", session }),
        StartOutcome.TooLate => Results.BadRequest(new { error = "That session is already over." }),
        _ => Results.BadRequest(new { error = "startedAt is too far in the future." })
    };
});

app.MapPost("/session/stop", ([FromBody(EmptyBodyBehavior = EmptyBodyBehavior.Allow)] StopSessionRequest? request,
    SessionStore store, SessionWatch watch) =>
{
    var session = store.Stop(request?.Id);
    watch.End(request?.Id);
    return Results.Ok(session);
});

// What the phone shows before a session, under "OK on my PC today": the few apps the buddy could ask
// about, with the ones this task already allowed in earlier sessions first and marked. Names only.
app.MapGet("/session/choices", (string? task, AllowStore store) =>
{
    var remembered = store.For(task);
    var known = Distractions.Choices.Select(c => new { key = c.Key, name = c.Name, remembered = remembered.Contains(c.Key) });
    var extra = remembered.Where(r => Distractions.Choices.All(c => c.Key != r))
        .Select(r => new { key = r, name = Distractions.FriendlyName(r), remembered = true });
    return Results.Ok(new { task, choices = extra.Concat(known).OrderByDescending(c => c.remembered).ToArray() });
});

// What the phone polls every 15 s: the front app, whether it is on task, and the nudge count.
app.MapPost("/session/status", (SessionStatusRequest request, SessionWatch watch) =>
{
    var status = request.Id is null ? null : watch.StatusFor(request.Id);
    if (status is null) return Results.NotFound(new { error = "unknown-session" });
    return Results.Ok(new
    {
        app = status.Value.App,
        onTask = status.Value.OnTask,
        nudges = status.Value.Nudges,
        asking = status.Value.Asking
    });
});

if (args.Contains("--draw-poses"))
{
    // Test helper: writes still brain poses (look, keen, cheer) and exits.
    BuddyPictures.WritePoses(Path.Combine(stateDir, "poses"));
    return;
}

if (args.Contains("--draw-buddy"))
{
    // Test helper: writes the buddy pictures and exits. Nothing else runs.
    BuddyPictures.Write(Path.Combine(stateDir, "buddy"));
    return;
}

if (args.Contains("--pair"))
{
    app.Lifetime.ApplicationStarted.Register(() => ShowPairingQr(OpenPairing(), stateDir));
}

// Browser activity arrives through a private pipe, not through either HTTP door.
var sessionWatch = app.Services.GetRequiredService<SessionWatch>();
using var guardianPipe = new GuardianPipe(sessionWatch.Report, sessionWatch.Heartbeat);

app.Run();

static void ShowPairingQr(PairingOffer offer, string dir)
{
    var payload = JsonSerializer.Serialize(offer, new JsonSerializerOptions(JsonSerializerDefaults.Web));
    using var generator = new QRCodeGenerator();
    using var data = generator.CreateQrCode(payload, QRCodeGenerator.ECCLevel.L);
    var png = new PngByteQRCode(data).GetGraphic(12);
    Directory.CreateDirectory(dir);
    var path = Path.Combine(dir, "pair-phone.png");
    File.WriteAllBytes(path, png);
    Console.WriteLine();
    Console.WriteLine("Pair your phone: scan the QR code in this picture with the Lock In app.");
    Console.WriteLine(path);
    Console.WriteLine($"It works for 5 minutes and one phone. Addresses: {string.Join(", ", offer.Hosts)}");
    try { Process.Start(new ProcessStartInfo(path) { UseShellExecute = true }); }
    catch (Exception) { /* no picture viewer: the path above is enough */ }
}

// Task, Buddy and Allow come from the phone (all optional; old phones send none of them).
// Allow: apps or sites already known to be fine for this session, e.g. ["youtube", "discord"].
// GuardianSeconds: the phone's "remind me after" slider, how long steady scrolling lasts before the buddy speaks.
public sealed record StartSessionRequest(int DurationSeconds, string? Id = null, DateTimeOffset? StartedAt = null,
    string? Task = null, bool Buddy = false, string[]? Allow = null, int? GuardianSeconds = null);

public sealed record StopSessionRequest(string? Id);

public sealed record PairRequest(string? Code, string? DeviceName);

public sealed record SessionStatusRequest(string? Id);

public sealed record FocusSession(
    string Id,
    string State,
    int DurationSeconds,
    DateTimeOffset? StartedAt,
    DateTimeOffset? EndsAt);

public enum StartOutcome { Started, Existing, Conflict, TooLate, FromFuture }

public sealed class SessionStore
{
    /// <summary>How far ahead of this PC's clock a phone's start time may be (clock drift allowance).</summary>
    public static readonly TimeSpan FutureTolerance = TimeSpan.FromSeconds(60);

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

    public bool TryStart(int durationSeconds, out FocusSession session) =>
        TryStart(Guid.NewGuid().ToString("N"), durationSeconds, clock.GetUtcNow(), out session) == StartOutcome.Started;

    /// <summary>
    /// Start (or mirror) a session with a caller-chosen id and start time. Repeating the same id
    /// is safe: it returns the session that is already running.
    /// </summary>
    public StartOutcome TryStart(string id, int durationSeconds, DateTimeOffset startedAt, out FocusSession session)
    {
        lock (gate)
        {
            ExpireIfNeeded();
            if (current.State is "starting" or "active")
            {
                session = current;
                return current.Id == id ? StartOutcome.Existing : StartOutcome.Conflict;
            }
            var now = clock.GetUtcNow();
            var endsAt = startedAt.AddSeconds(durationSeconds);
            session = current;
            if (startedAt - now > FutureTolerance) return StartOutcome.FromFuture;
            if (endsAt <= now) return StartOutcome.TooLate;
            current = new(id, "active", durationSeconds, startedAt, endsAt);
            session = current;
            return StartOutcome.Started;
        }
    }

    /// <summary>Stop the session. With an id, only that session is stopped, so a late message cannot end a newer one.</summary>
    public FocusSession Stop(string? id = null)
    {
        lock (gate)
        {
            if (id is not null && current.Id != id) return current;
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
