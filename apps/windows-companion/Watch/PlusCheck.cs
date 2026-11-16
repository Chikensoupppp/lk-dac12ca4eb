using System.Net.Http.Headers;
using System.Text.Json;

namespace LockIn.Companion.Watch;

/// <summary>
/// Plus on the PC. The phone sends its RevenueCat user id with a session start; the PC asks
/// RevenueCat itself whether that user has the Plus entitlement, so a phone (or anything on the
/// network) cannot just claim Plus. The answer is cached for a few days, so a PC that is briefly
/// offline keeps a paying user's Plus. No purchase data, only "has Plus until".
/// </summary>
public sealed class PlusCheck
{
    /// <summary>RevenueCat's public Apple SDK key. Public keys are made to ship inside apps.</summary>
    public const string PublicKey = "appl_isEkAeKkQaltkFfNOQNsiZPrjEg";
    public const string Entitlement = "nogbox_pro";
    /// <summary>How long a "yes" from RevenueCat stays good when the PC cannot reach it again.</summary>
    public static readonly TimeSpan OfflineGrace = TimeSpan.FromDays(3);

    private readonly HttpClient http;
    private readonly TimeProvider clock;
    private readonly string? cachePath;

    public PlusCheck(TimeProvider clock, string? stateDir, HttpClient? http = null)
    {
        this.clock = clock;
        this.http = http ?? new HttpClient { Timeout = TimeSpan.FromSeconds(4) };
        cachePath = stateDir is null ? null : Path.Combine(stateDir, "plus.json");
    }

    /// <summary>True when RevenueCat says this user has Plus now (or said so recently, when offline).</summary>
    public async Task<bool> HasPlusAsync(string? userId)
    {
        if (string.IsNullOrWhiteSpace(userId) || userId.Length > 200) return false;
        var now = clock.GetUtcNow();
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Get,
                "https://api.revenuecat.com/v1/subscribers/" + Uri.EscapeDataString(userId));
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", PublicKey);
            using var response = await http.SendAsync(request);
            if (response.IsSuccessStatusCode)
            {
                var json = await response.Content.ReadAsStringAsync();
                var active = IsActive(json, now);
                Save(new Cached(userId, active, now));
                return active;
            }
        }
        catch (Exception) { /* offline or blocked: fall back to the last answer */ }
        var cached = Load();
        return cached is not null && cached.UserId == userId && cached.Plus && now - cached.CheckedAt <= OfflineGrace;
    }

    /// <summary>
    /// Reads RevenueCat's subscriber JSON: the Plus entitlement is active when it exists and has no
    /// expiry (lifetime) or an expiry in the future.
    /// </summary>
    public static bool IsActive(string subscriberJson, DateTimeOffset now)
    {
        try
        {
            using var doc = JsonDocument.Parse(subscriberJson);
            if (!doc.RootElement.TryGetProperty("subscriber", out var subscriber)
                || !subscriber.TryGetProperty("entitlements", out var entitlements)
                || !entitlements.TryGetProperty(Entitlement, out var plus)) return false;
            if (!plus.TryGetProperty("expires_date", out var expires) || expires.ValueKind == JsonValueKind.Null) return true;
            return expires.ValueKind == JsonValueKind.String
                && DateTimeOffset.TryParse(expires.GetString(), out var until) && until > now;
        }
        catch (JsonException)
        {
            return false;
        }
    }

    private sealed record Cached(string UserId, bool Plus, DateTimeOffset CheckedAt);

    private void Save(Cached value)
    {
        if (cachePath is null) return;
        try { File.WriteAllText(cachePath, JsonSerializer.Serialize(value)); } catch (Exception) { }
    }

    private Cached? Load()
    {
        if (cachePath is null || !File.Exists(cachePath)) return null;
        try { return JsonSerializer.Deserialize<Cached>(File.ReadAllText(cachePath)); } catch (Exception) { return null; }
    }
}
