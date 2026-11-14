using System.Security.Cryptography;
using System.Text.Json;
using System.Text;

namespace LockIn.Companion.Watch;

public sealed record LaterItem(string Url, DateTimeOffset SavedAt);

/// <summary>Only explicitly saved YouTube/Reddit links. Encrypted for this Windows user, never synced.</summary>
public sealed class LaterStore(string directory)
{
    private readonly string path = Path.Combine(directory, "later.dat");
    private readonly object gate = new();
    private readonly string mutexName = @"Local\LockIn.Later." + Convert.ToHexString(SHA256.HashData(
        Encoding.UTF8.GetBytes(Path.GetFullPath(Path.Combine(directory, "later.dat")).ToUpperInvariant())));
    public const int Capacity = 200;

    public static string? CleanUrl(string? value)
    {
        if (value is null || value.Length > 2048 || !Uri.TryCreate(value, UriKind.Absolute, out var uri)
            || uri.Scheme != "https" || !string.IsNullOrEmpty(uri.UserInfo) || !uri.IsDefaultPort) return null;
        var host = uri.IdnHost.ToLowerInvariant();
        if (host is not ("youtube.com" or "www.youtube.com" or "m.youtube.com" or "youtu.be"
            or "reddit.com" or "www.reddit.com" or "old.reddit.com")) return null;
        return uri.AbsoluteUri;
    }

    public IReadOnlyList<LaterItem> Read()
    {
        return Locked(() => TryRead(out var items) ? items : Array.Empty<LaterItem>(), Array.Empty<LaterItem>());
    }

    private bool TryRead(out IReadOnlyList<LaterItem> items)
    {
        items = Array.Empty<LaterItem>();
        try
        {
            if (!File.Exists(path)) return true;
            var bytes = ProtectedData.Unprotect(File.ReadAllBytes(path), null, DataProtectionScope.CurrentUser);
            var decoded = JsonSerializer.Deserialize<LaterItem[]>(bytes);
            if (decoded is null) return false;
            items = decoded.Where(item => item is not null && CleanUrl(item.Url) is not null).Take(Capacity).ToArray();
            return true;
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or JsonException or CryptographicException)
        { return false; }
    }

    public bool Save(string url, DateTimeOffset now)
    {
        var clean = CleanUrl(url);
        if (clean is null) return false;
        return Locked(() =>
        {
            if (!TryRead(out var current)) return false;
            var items = current.Where(item => item.Url != clean).ToList();
            if (items.Count >= Capacity) return false;
            items.Insert(0, new LaterItem(clean, now));
            return Write(items.Take(Capacity));
        }, false);
    }

    public bool Remove(string url)
    {
        return Locked(() => TryRead(out var items) && Write(items.Where(item => item.Url != url)), false);
    }

    private T Locked<T>(Func<T> action, T fallback)
    {
        lock (gate)
        {
            using var mutex = new Mutex(false, mutexName);
            var acquired = false;
            try
            {
                try { acquired = mutex.WaitOne(TimeSpan.FromSeconds(2)); }
                catch (AbandonedMutexException) { acquired = true; }
                return acquired ? action() : fallback;
            }
            finally { if (acquired) mutex.ReleaseMutex(); }
        }
    }

    private bool Write(IEnumerable<LaterItem> items)
    {
        try
        {
            Directory.CreateDirectory(directory);
            var bytes = ProtectedData.Protect(JsonSerializer.SerializeToUtf8Bytes(items), null, DataProtectionScope.CurrentUser);
            File.WriteAllBytes(path + ".tmp", bytes);
            File.Move(path + ".tmp", path, overwrite: true);
            return true;
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or CryptographicException) { return false; }
    }
}

/// <summary>A five-second, single-use request, bound to the session and foreground browser window.</summary>
public sealed class LaterCapture
{
    private sealed record Pending(string Token, string Session, string Browser, IntPtr Window, string? Site, DateTimeOffset At);
    private Pending? pending;
    public void Clear() => pending = null;
    public bool Expired(DateTimeOffset now) => pending is { } p && now - p.At > TimeSpan.FromSeconds(5);

    public bool Request(string session, FrontWindow.Snapshot? front, DateTimeOffset now)
    {
        var site = Distractions.KeyOf(front);
        if (!Distractions.IsBrowser(front) || site is not ("youtube" or "reddit")) return false;
        pending = new(Guid.NewGuid().ToString("N"), session, front!.Process.ToLowerInvariant(), front.Handle, site, now);
        return true;
    }

    public string? Poll(string browser, DateTimeOffset now) => pending is { } p
        && p.Browser == browser && now >= p.At && now - p.At <= TimeSpan.FromSeconds(5) ? p.Token : null;

    public string? Complete(string browser, string token, string url, string? session, FrontWindow.Snapshot? front, DateTimeOffset now)
    {
        var clean = LaterStore.CleanUrl(url);
        if (pending is not { } p || p.Token != token || p.Session != session || clean is null
            || Poll(browser, now) is null || front?.Handle != p.Window || front.Process.ToLowerInvariant() != p.Browser
            || Distractions.KeyOf(front) != p.Site) return null;
        var site = new Uri(clean).Host.Contains("youtu", StringComparison.Ordinal) ? "youtube" : "reddit";
        if (site != p.Site) return null;
        pending = null;
        return clean;
    }
}

public sealed record LaterMessage(string Kind, string? Request, string? Url)
{
    public static LaterMessage? Parse(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            var r = doc.RootElement;
            if (r.ValueKind != JsonValueKind.Object || !r.TryGetProperty("v", out var v) || !v.TryGetInt32(out var version) || version != 1
                || !r.TryGetProperty("kind", out var k) || k.ValueKind != JsonValueKind.String) return null;
            if (k.GetString() == "later-poll") return new("later-poll", null, null);
            if (k.GetString() != "later-save" || !r.TryGetProperty("request", out var request) || request.ValueKind != JsonValueKind.String
                || !Guid.TryParseExact(request.GetString(), "N", out _) || !r.TryGetProperty("url", out var url)
                || url.ValueKind != JsonValueKind.String || LaterStore.CleanUrl(url.GetString()) is not { } clean) return null;
            return new("later-save", request.GetString(), clean);
        }
        catch (JsonException) { return null; }
        catch (InvalidOperationException) { return null; }
    }
}
