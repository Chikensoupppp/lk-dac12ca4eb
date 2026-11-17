using System.Runtime.InteropServices;
using System.Security.Cryptography;



/// <summary>
/// "Find nearby PC": the phone sees this PC on the Wi-Fi (Bonjour, _nogbox._tcp), asks to pair, and
/// the PC owner clicks Allow. The ask carries a 4-digit code that the phone shows too, so the owner
/// can see it is their phone. Allow opens a normal one-time pairing offer and hands it to the phone;
/// from there it is the same pairing as the QR code. Only one ask waits at a time, for one minute.
/// </summary>
public static class NearbyPairing
{
    public sealed class Ask
    {
        public required string Id { get; init; }
        public required string Device { get; init; }
        public required string Code { get; init; }
        public required DateTimeOffset Expires { get; init; }
        public string State { get; set; } = "pending";
        public PairingOffer? Offer { get; set; }
    }

    private static readonly object Gate = new();
    private static readonly Dictionary<string, Ask> Asks = new();
    public static readonly TimeSpan AskTime = TimeSpan.FromMinutes(1);

    /// <summary>Raised when a phone asks; the PC window shows Allow / Don't allow.</summary>
    public static event Action<Ask>? Asked;

    /// <summary>Starts an ask. Null when another ask is still waiting, or the input is not valid.</summary>
    public static Ask? Start(string? device, string? code, DateTimeOffset now)
    {
        if (string.IsNullOrWhiteSpace(device) || code is null || code.Length != 4 || !code.All(char.IsAsciiDigit))
            return null;
        var name = new string(device.Trim().Where(c => !char.IsControl(c)).Take(40).ToArray());
        Ask ask;
        lock (Gate)
        {
            foreach (var old in Asks.Values.Where(a => a.State == "pending" && now >= a.Expires).ToList())
                old.State = "expired";
            if (Asks.Values.Any(a => a.State == "pending")) return null;
            ask = new Ask
            {
                Id = Convert.ToHexString(RandomNumberGenerator.GetBytes(12)),
                Device = name, Code = code, Expires = now + AskTime
            };
            Asks[ask.Id] = ask;
            // Keep the list short: answers older than ten minutes go.
            foreach (var k in Asks.Where(a => now - a.Value.Expires > TimeSpan.FromMinutes(10)).Select(a => a.Key).ToList())
                Asks.Remove(k);
        }
        Asked?.Invoke(ask);
        return ask;
    }

    public static Ask? Status(string? id, DateTimeOffset now)
    {
        if (id is null) return null;
        lock (Gate)
        {
            if (!Asks.TryGetValue(id, out var ask)) return null;
            if (ask.State == "pending" && now >= ask.Expires) ask.State = "expired";
            return ask;
        }
    }

    /// <summary>The owner's answer. Allow opens a pairing offer for the phone to collect.</summary>
    public static void Answer(string id, bool allow, Func<PairingOffer> openPairing, DateTimeOffset now)
    {
        lock (Gate)
        {
            if (!Asks.TryGetValue(id, out var ask) || ask.State != "pending") return;
            if (now >= ask.Expires) { ask.State = "expired"; return; }
            if (!allow) { ask.State = "denied"; return; }
            ask.Offer = openPairing();
            ask.State = "allowed";
        }
    }

    /// <summary>Hands the offer over once, then forgets it.</summary>
    public static PairingOffer? TakeOffer(Ask ask)
    {
        lock (Gate)
        {
            var offer = ask.Offer;
            ask.Offer = null;
            if (offer is not null) ask.State = "done";
            return offer;
        }
    }
}

public sealed record NearbyAskRequest(string? Device, string? Code);
public sealed record NearbyStatusRequest(string? Id);

/// <summary>
/// Announces this PC on the local network with Windows' own mDNS (DnsServiceRegister, Windows 10
/// 1809 and later), so the phone can list it under "Find nearby PC". The TXT record carries what the
/// phone needs to talk to the PC safely: its addresses, port and certificate fingerprint. No secret is
/// in it; pairing still needs the owner's Allow.
/// </summary>
public sealed class BonjourAdvertiser : IDisposable
{
    private const uint DnsQueryRequestVersion1 = 1;
    private const uint DnsRequestPending = 9506;

    [StructLayout(LayoutKind.Sequential)]
    private struct RegisterRequest
    {
        public uint Version;
        public uint InterfaceIndex;
        public IntPtr ServiceInstance;
        public IntPtr Callback;
        public IntPtr Context;
        public IntPtr Credentials;
        public int UnicastEnabled;
    }

    private delegate void RegisterComplete(uint status, IntPtr context, IntPtr instance);

    [DllImport("dnsapi.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr DnsServiceConstructInstance(string serviceName, string hostName, IntPtr ip4, IntPtr ip6,
        ushort port, ushort priority, ushort weight, uint propertyCount,
        [MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.LPWStr)] string[] keys,
        [MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.LPWStr)] string[] values);
    [DllImport("dnsapi.dll")] private static extern uint DnsServiceRegister(ref RegisterRequest request, IntPtr cancel);
    [DllImport("dnsapi.dll")] private static extern uint DnsServiceDeRegister(ref RegisterRequest request, IntPtr cancel);
    [DllImport("dnsapi.dll")] private static extern void DnsServiceFreeInstance(IntPtr instance);

    // Kept alive for as long as Windows may call it.
    private static readonly RegisterComplete Done = (_, _, instance) => { };
    private RegisterRequest request;
    private IntPtr instance;
    public bool Active { get; private set; }

    public BonjourAdvertiser(string pcName, int port, string fingerprint, string[] hosts)
    {
        try
        {
            var label = new string(pcName.Where(c => char.IsLetterOrDigit(c) || c == '-').Take(40).ToArray());
            if (label.Length == 0) label = "Nogbox-PC";
            var keys = new[] { "v", "name", "fp", "hosts", "port" };
            var values = new[] { "1", pcName.Length > 40 ? pcName[..40] : pcName, fingerprint, string.Join(",", hosts.Take(4)), port.ToString() };
            instance = DnsServiceConstructInstance($"{label}._nogbox._tcp.local", $"{Environment.MachineName}.local",
                IntPtr.Zero, IntPtr.Zero, (ushort)port, 0, 0, (uint)keys.Length, keys, values);
            if (instance == IntPtr.Zero) return;
            request = new RegisterRequest
            {
                Version = DnsQueryRequestVersion1,
                ServiceInstance = instance,
                Callback = Marshal.GetFunctionPointerForDelegate(Done)
            };
            Active = DnsServiceRegister(ref request, IntPtr.Zero) == DnsRequestPending;
        }
        catch (Exception e) when (e is DllNotFoundException or EntryPointNotFoundException)
        {
            // Older Windows: no mDNS API. The QR code still works.
        }
    }

    public void Dispose()
    {
        if (Active) { try { DnsServiceDeRegister(ref request, IntPtr.Zero); } catch (Exception) { } }
        if (instance != IntPtr.Zero) { DnsServiceFreeInstance(instance); instance = IntPtr.Zero; }
        Active = false;
    }
}
