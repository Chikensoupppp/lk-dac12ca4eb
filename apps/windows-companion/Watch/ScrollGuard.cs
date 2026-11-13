using System.Text.Json;

namespace LockIn.Companion.Watch;

/// <summary>
/// What the browser extension reports every few seconds while a Shorts page or a Reddit feed is the
/// focused tab. Counts only: no URLs, titles, text or pictures.
/// </summary>
/// <param name="Site">"youtube-shorts" or "reddit-feed".</param>
/// <param name="Scrolls">Scroll events in this report (the extension sends at most a few per second).</param>
/// <param name="Screens">How far the page moved, in screen heights.</param>
/// <param name="Items">Shorts or posts that changed (a new Short, a new page).</param>
/// <param name="Playing">A video was playing during this report.</param>
public sealed record GuardianSignal(string Site, int Scrolls, double Screens, int Items, bool Playing)
{
    public static readonly string[] Sites = { "youtube-shorts", "reddit-feed" };

    /// <summary>
    /// Reads one message from the extension. Anything odd (unknown site, missing fields, not JSON,
    /// not focused) gives null and is ignored. Numbers are clamped so one bad report cannot fake minutes.
    /// </summary>
    public static GuardianSignal? Parse(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            if (root.ValueKind != JsonValueKind.Object) return null;
            if (!root.TryGetProperty("v", out var v) || v.ValueKind != JsonValueKind.Number || v.GetInt32() != 1) return null;
            var site = root.TryGetProperty("site", out var s) && s.ValueKind == JsonValueKind.String ? s.GetString() : null;
            if (site is null || !Sites.Contains(site)) return null;
            if (!root.TryGetProperty("focused", out var f) || f.ValueKind != JsonValueKind.True) return null;
            return new GuardianSignal(site,
                (int)Math.Clamp(Number(root, "scrolls"), 0, 200),
                Math.Clamp(Number(root, "screens"), 0, 50),
                (int)Math.Clamp(Number(root, "items"), 0, 30),
                root.TryGetProperty("playing", out var p) && p.ValueKind == JsonValueKind.True);
        }
        catch (JsonException) { return null; }
        catch (FormatException) { return null; }
        catch (InvalidOperationException) { return null; }
    }

    private static double Number(JsonElement root, string name) =>
        root.TryGetProperty(name, out var n) && n.ValueKind == JsonValueKind.Number && n.TryGetDouble(out var d) && double.IsFinite(d) ? d : 0;
}

/// <summary>Guardian settings. Defaults: 3 minutes of steady scrolling, then 10 minutes of quiet after a reminder.</summary>
public sealed record GuardianOptions(
    int ThresholdSeconds = 180,
    int BucketSeconds = 30,
    int CooldownMinutes = 10,
    int CooldownAfterBackMinutes = 5,
    int BrowserGraceSeconds = 60)
{
    /// <summary>
    /// Reads <c>guardian.json</c> from the state folder, for example <c>{"thresholdSeconds": 240}</c>.
    /// Missing or broken file: the defaults. Values are kept in sane ranges.
    /// </summary>
    public static GuardianOptions Load(string stateDir)
    {
        var options = new GuardianOptions();
        try
        {
            var path = Path.Combine(stateDir, "guardian.json");
            if (File.Exists(path))
                options = JsonSerializer.Deserialize<GuardianOptions>(File.ReadAllText(path),
                    new JsonSerializerOptions(JsonSerializerDefaults.Web)) ?? options;
        }
        catch (JsonException) { }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
        var bucket = Math.Clamp(options.BucketSeconds, 5, 120);
        return new GuardianOptions(
            Math.Clamp(options.ThresholdSeconds, bucket * 2, 3600),
            bucket,
            Math.Clamp(options.CooldownMinutes, 1, 120),
            Math.Clamp(options.CooldownAfterBackMinutes, 1, 120),
            Math.Clamp(options.BrowserGraceSeconds, 5, 600));
    }
}

/// <summary>
/// Decides when the buddy should say "Looks like you've been scrolling for a bit". Plain rules, no AI,
/// no Windows calls, so it can be tested with a fake clock.
///
/// Time is cut into buckets (30 s by default). A bucket is "busy" when it shows feed-like movement:
/// on Shorts, a new Short; on a Reddit feed, two new pages or posts, or three screens of scrolling.
/// One video playing (a lecture, one Short on loop) changes nothing, so it never counts. The run is the
/// stretch of busy buckets up to now; single quiet buckets inside it are forgiven (a slow Short, a pause
/// to read), two quiet buckets in a row end it. When the run reaches the threshold (3 minutes), it is
/// time for a reminder. Having YouTube or Reddit open is never enough: no reports means quiet.
/// After a reminder nothing more is said until the cooldown ends.
/// </summary>
public sealed class ScrollGuard
{
    private readonly GuardianOptions options;
    private readonly Dictionary<long, (int Items, double Screens, bool Shorts)> buckets = new();
    private DateTimeOffset origin;
    private DateTimeOffset quietUntil = DateTimeOffset.MinValue;
    private int? thresholdForSession;

    public ScrollGuard(GuardianOptions? options = null) => this.options = options ?? new GuardianOptions();

    public GuardianOptions Options => options;

    /// <summary>How long steady scrolling must last: the phone's choice for this session, else the settings file.</summary>
    public int ThresholdSeconds => thresholdForSession ?? options.ThresholdSeconds;

    /// <summary>
    /// Forget everything. Called when a session starts or ends. <paramref name="thresholdSeconds"/> is the
    /// phone's "remind me after" choice for the new session (kept between 1 minute and 1 hour).
    /// </summary>
    public void Reset(DateTimeOffset now, int? thresholdSeconds = null)
    {
        thresholdForSession = thresholdSeconds is { } t ? Math.Clamp(t, Math.Max(60, options.BucketSeconds * 2), 3600) : null;
        buckets.Clear();
        origin = now;
        quietUntil = DateTimeOffset.MinValue;
    }

    public void Report(DateTimeOffset now, GuardianSignal signal)
    {
        if (now < origin) return;
        var key = BucketOf(now);
        buckets.TryGetValue(key, out var b);
        buckets[key] = (b.Items + signal.Items, b.Screens + signal.Screens, b.Shorts || signal.Site == "youtube-shorts");
        // Keep only what the threshold can still need.
        var keep = key - 2 * (ThresholdSeconds / options.BucketSeconds) - 3;
        foreach (var old in buckets.Keys.Where(k => k < keep).ToList()) buckets.Remove(old);
    }

    /// <summary>How long the current run of scrolling has lasted, counting finished buckets only.</summary>
    public TimeSpan Sustained(DateTimeOffset now)
    {
        var last = BucketOf(now) - 1;
        // The run must reach the present: the last finished bucket, or the one before it.
        var end = IsBusy(last) ? last : IsBusy(last - 1) ? last - 1 : -1;
        if (end < 0) return TimeSpan.Zero;
        var start = end;
        for (var k = end - 1; k >= 0; k--)
        {
            if (IsBusy(k)) { start = k; continue; }
            if (!IsBusy(k - 1)) break; // two quiet buckets in a row end the run
        }
        return TimeSpan.FromSeconds((end - start + 1) * options.BucketSeconds);
    }

    /// <summary>True when the buddy should remind now. The caller then calls <see cref="Reminded"/>.</summary>
    public bool ShouldRemind(DateTimeOffset now) =>
        now >= quietUntil && Sustained(now).TotalSeconds >= ThresholdSeconds;

    /// <summary>A reminder was shown. Start the cooldown and the next run from zero.</summary>
    public void Reminded(DateTimeOffset now)
    {
        buckets.Clear();
        quietUntil = now.AddMinutes(options.CooldownMinutes);
    }

    /// <summary>The user answered. "Back to work" gets a shorter quiet time: they did what was asked.</summary>
    public void Answered(DateTimeOffset now, bool backToWork) =>
        quietUntil = now.AddMinutes(backToWork ? options.CooldownAfterBackMinutes : options.CooldownMinutes);

    public bool Cooling(DateTimeOffset now) => now < quietUntil;

    private long BucketOf(DateTimeOffset now) => (long)Math.Floor((now - origin).TotalSeconds / options.BucketSeconds);

    private bool IsBusy(long key) =>
        key >= 0 && buckets.TryGetValue(key, out var b)
        && (b.Shorts ? b.Items >= 1 : b.Items >= 2 || b.Screens >= 3);
}
