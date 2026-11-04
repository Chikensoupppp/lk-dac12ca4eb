using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Text.Json;

public sealed record PairedDevice(string Id, string Name, string TokenHash, DateTimeOffset PairedAt);

/// <summary>What the QR code carries. The phone pins <c>Fingerprint</c> and sends <c>Code</c> once to /pair.</summary>
public sealed record PairingOffer(int V, string[] Hosts, int Port, string Fp, string Code, DateTimeOffset ExpiresAt);

public sealed record PairResult(bool Ok, string? Error, string? DeviceId, string? Token);

/// <summary>
/// Keeps the PC's HTTPS certificate and the list of paired phones on disk (per Windows user).
/// The certificate key is protected with DPAPI. Only a hash of each phone's token is stored.
/// </summary>
public sealed class CompanionStateStore
{
    private const string PfxPassword = "lockin-companion"; // the blob is DPAPI-protected as a whole
    private readonly string dir;
    private readonly string file;
    private readonly object gate = new();

    public CompanionStateStore(string dir)
    {
        this.dir = dir;
        file = Path.Combine(dir, "companion-state.json");
    }

    private sealed class StateFile
    {
        public string? ProtectedPfx { get; set; }
        public List<PairedDevice> Devices { get; set; } = new();
    }

    private StateFile Read()
    {
        if (!File.Exists(file)) return new StateFile();
        try { return JsonSerializer.Deserialize<StateFile>(File.ReadAllText(file)) ?? new StateFile(); }
        catch (JsonException) { return new StateFile(); }
    }

    private void Write(StateFile state)
    {
        Directory.CreateDirectory(dir);
        var temp = file + ".tmp";
        File.WriteAllText(temp, JsonSerializer.Serialize(state));
        File.Move(temp, file, overwrite: true);
    }

    public X509Certificate2 LoadOrCreateCertificate()
    {
        lock (gate)
        {
            var state = Read();
            if (state.ProtectedPfx is not null)
            {
                try
                {
                    var pfx = ProtectedData.Unprotect(Convert.FromBase64String(state.ProtectedPfx), null, DataProtectionScope.CurrentUser);
                    return X509CertificateLoader.LoadPkcs12(pfx, PfxPassword, X509KeyStorageFlags.Exportable);
                }
                catch (CryptographicException) { /* unreadable: make a new one; phones must pair again */ }
                catch (FormatException) { }
                state.Devices.Clear();
            }

            using var key = ECDsa.Create(ECCurve.NamedCurves.nistP256);
            var request = new CertificateRequest("CN=Lock In Companion", key, HashAlgorithmName.SHA256);
            var names = new SubjectAlternativeNameBuilder();
            names.AddDnsName("localhost");
            names.AddDnsName(Environment.MachineName);
            request.CertificateExtensions.Add(names.Build());
            request.CertificateExtensions.Add(new X509KeyUsageExtension(X509KeyUsageFlags.DigitalSignature, critical: false));
            request.CertificateExtensions.Add(new X509EnhancedKeyUsageExtension(
                new OidCollection { new Oid("1.3.6.1.5.5.7.3.1") }, critical: false));
            var now = DateTimeOffset.UtcNow;
            using var created = request.CreateSelfSigned(now.AddDays(-1), now.AddYears(10));
            var bytes = created.Export(X509ContentType.Pfx, PfxPassword);
            state.ProtectedPfx = Convert.ToBase64String(ProtectedData.Protect(bytes, null, DataProtectionScope.CurrentUser));
            Write(state);
            return X509CertificateLoader.LoadPkcs12(bytes, PfxPassword, X509KeyStorageFlags.Exportable);
        }
    }

    public IReadOnlyList<PairedDevice> Devices()
    {
        lock (gate) return Read().Devices.ToList();
    }

    public void AddDevice(PairedDevice device)
    {
        lock (gate)
        {
            var state = Read();
            state.Devices.Add(device);
            Write(state);
        }
    }

    public bool RemoveDevice(string id)
    {
        lock (gate)
        {
            var state = Read();
            var removed = state.Devices.RemoveAll(d => d.Id == id) > 0;
            if (removed) Write(state);
            return removed;
        }
    }

    public static string Fingerprint(X509Certificate2 cert) => Convert.ToHexString(SHA256.HashData(cert.RawData));
}

/// <summary>
/// One-time pairing and bearer-token checks. A pairing window gives out one single-use code.
/// Five wrong guesses close the window. Tokens are random; only their SHA-256 is stored.
/// </summary>
public sealed class PairingService
{
    private const int MaxFailures = 5;
    private readonly CompanionStateStore store;
    private readonly TimeProvider clock;
    private readonly object gate = new();
    private string? code;
    private DateTimeOffset expiresAt;
    private int failures;

    public PairingService(CompanionStateStore store, TimeProvider clock)
    {
        this.store = store;
        this.clock = clock;
    }

    public (string Code, DateTimeOffset ExpiresAt) Open(TimeSpan window)
    {
        lock (gate)
        {
            code = Base64Url(RandomNumberGenerator.GetBytes(16));
            expiresAt = clock.GetUtcNow().Add(window);
            failures = 0;
            return (code, expiresAt);
        }
    }

    public void Close()
    {
        lock (gate) code = null;
    }

    public bool IsOpen
    {
        get { lock (gate) return code is not null && clock.GetUtcNow() < expiresAt; }
    }

    public PairResult TryPair(string? provided, string? deviceName)
    {
        lock (gate)
        {
            if (code is null || clock.GetUtcNow() >= expiresAt)
                return new(false, "pairing-closed", null, null);

            var expected = System.Text.Encoding.UTF8.GetBytes(code);
            var actual = System.Text.Encoding.UTF8.GetBytes(provided ?? "");
            if (expected.Length != actual.Length || !CryptographicOperations.FixedTimeEquals(expected, actual))
            {
                if (++failures >= MaxFailures) code = null;
                return new(false, "bad-code", null, null);
            }

            code = null; // single use
            var token = Base64Url(RandomNumberGenerator.GetBytes(32));
            var id = Guid.NewGuid().ToString("N");
            var name = string.IsNullOrWhiteSpace(deviceName) ? "iPhone" : deviceName.Trim();
            if (name.Length > 40) name = name[..40];
            store.AddDevice(new PairedDevice(id, name, Hash(token), clock.GetUtcNow()));
            return new(true, null, id, token);
        }
    }

    public bool IsAuthorized(string? authorizationHeader)
    {
        const string prefix = "Bearer ";
        if (authorizationHeader is null || !authorizationHeader.StartsWith(prefix, StringComparison.Ordinal))
            return false;
        var presented = Convert.FromHexString(Hash(authorizationHeader[prefix.Length..].Trim()));
        var match = false;
        foreach (var device in store.Devices())
        {
            // Check every device so timing does not reveal which one matched.
            match |= CryptographicOperations.FixedTimeEquals(presented, Convert.FromHexString(device.TokenHash));
        }
        return match;
    }

    private static string Hash(string token) => Convert.ToHexString(SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(token)));

    private static string Base64Url(byte[] bytes) =>
        Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
}

public static class LanAddresses
{
    /// <summary>Private IPv4 addresses of connected, non-virtual adapters. The phone tries them in order.</summary>
    public static string[] Find()
    {
        var found = new List<string>();
        foreach (var nic in NetworkInterface.GetAllNetworkInterfaces())
        {
            if (nic.OperationalStatus != OperationalStatus.Up) continue;
            if (nic.NetworkInterfaceType is NetworkInterfaceType.Loopback or NetworkInterfaceType.Tunnel) continue;
            var label = nic.Name + " " + nic.Description;
            if (label.Contains("vEthernet", StringComparison.OrdinalIgnoreCase)
                || label.Contains("VirtualBox", StringComparison.OrdinalIgnoreCase)
                || label.Contains("VMware", StringComparison.OrdinalIgnoreCase)
                || label.Contains("Hyper-V", StringComparison.OrdinalIgnoreCase)
                || label.Contains("WSL", StringComparison.OrdinalIgnoreCase))
                continue;
            foreach (var unicast in nic.GetIPProperties().UnicastAddresses)
            {
                if (unicast.Address.AddressFamily != AddressFamily.InterNetwork) continue;
                if (IsPrivate(unicast.Address)) found.Add(unicast.Address.ToString());
            }
        }
        return found.Distinct().ToArray();
    }

    public static bool IsPrivate(IPAddress address)
    {
        var b = address.GetAddressBytes();
        return b[0] == 10 || (b[0] == 172 && b[1] is >= 16 and <= 31) || (b[0] == 192 && b[1] == 168);
    }
}
