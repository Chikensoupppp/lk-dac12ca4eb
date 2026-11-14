using System.IO.Pipes;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Text;
using System.Text.Json;
using Microsoft.Win32;

namespace LockIn.Companion.Watch;

// How the browser extension reaches the buddy, with no network port at all:
//
//   extension --(Chrome native messaging: stdin/stdout)--> LockIn.Companion.exe started by Chrome
//             --(named pipe, this Windows user only, no network)--> the running companion -> SessionWatch
//
// Chrome only starts the host for the extension ID listed in the host manifest, and passes that ID as
// the first argument; the host checks it again. The pipe only accepts the same Windows user, refuses
// network logons, and the client checks the pipe's owner too (PipeOptions.CurrentUserOnly).

/// <summary>Chrome's native messaging frame: 4-byte little-endian length, then UTF-8 JSON.</summary>
public static class NativeMessages
{
    /// <summary>Extension messages are tiny; anything bigger is not ours.</summary>
    public const int MaxBytes = 4096;

    /// <summary>The next message, or null at the end of the stream or on a bad frame.</summary>
    public static string? Read(Stream input)
    {
        var header = new byte[4];
        if (!ReadExactly(input, header)) return null;
        var length = BitConverter.ToInt32(header, 0);
        if (length <= 0 || length > MaxBytes) return null;
        var body = new byte[length];
        return ReadExactly(input, body) ? Encoding.UTF8.GetString(body) : null;
    }

    public static void Write(Stream output, string json)
    {
        var body = Encoding.UTF8.GetBytes(json);
        output.Write(BitConverter.GetBytes(body.Length));
        output.Write(body);
        output.Flush();
    }

    private static bool ReadExactly(Stream input, byte[] buffer)
    {
        var read = 0;
        while (read < buffer.Length)
        {
            var n = input.Read(buffer, read, buffer.Length - read);
            if (n == 0) return false;
            read += n;
        }
        return true;
    }
}

/// <summary>The program Chrome or Edge starts for the extension. Passes reports on to the running companion.</summary>
public static class NativeHost
{
    public const string Name = "com.lockin.guardian";

    /// <summary>
    /// Fixed by the public "key" in apps/browser-extension/manifest.json. Change both together.
    /// </summary>
    public const string ExtensionId = "aeamejjnehidcalejbnkpgkfkalefeda";

    public static string AllowedOrigin => $"chrome-extension://{ExtensionId}/";

    /// <summary>Firefox names extensions by this ID (manifest browser_specific_settings) and passes it as an argument.</summary>
    public const string FirefoxId = "focus-buddy@lockin.app";

    /// <summary>True when a browser started this program as the native host (Chromium browsers or Firefox).</summary>
    public static bool IsLaunch(string[] args) =>
        args.Any(a => a.StartsWith("chrome-extension://", StringComparison.OrdinalIgnoreCase)
            || a.Equals(FirefoxId, StringComparison.OrdinalIgnoreCase));

    /// <summary>Runs until the browser closes the connection. Returns the exit code.</summary>
    public static int Run(string[] args)
    {
        if (!args.Contains(AllowedOrigin, StringComparer.OrdinalIgnoreCase)
            && !args.Contains(FirefoxId, StringComparer.OrdinalIgnoreCase)) return 1; // not our extension
        // The browser that started us is our parent process: that is how the buddy knows which
        // browser is covered, without the extension having to say (or being able to lie).
        var browser = ParentProcess.NameOf(Environment.ProcessId);
        var stdin = Console.OpenStandardInput();
        var stdout = Console.OpenStandardOutput();
        NamedPipeClientStream? pipe = null;
        try
        {
            while (NativeMessages.Read(stdin) is { } message)
            {
                string? line = null;
                if (GuardianSignal.Parse(message) is { } signal)
                {
                    // Pass on a clean copy, never the raw text.
                    line = JsonSerializer.Serialize(new
                    {
                        v = 1, site = signal.Site, scrolls = signal.Scrolls, screens = signal.Screens,
                        items = signal.Items, playing = signal.Playing, focused = true,
                    });
                }
                else if (browser is not null && BrowserHeartbeat.IncognitoFromExtension(message) is { } incognito)
                {
                    line = JsonSerializer.Serialize(new { v = 1, kind = "alive", browser, incognito });
                }
                else if (browser is not null && LaterMessage.Parse(message) is { } later)
                {
                    line = JsonSerializer.Serialize(new { v = 1, kind = later.Kind, request = later.Request, url = later.Url, browser });
                }
                var response = line is not null ? TrySend(ref pipe, line + "\n") : null;
                // The extension shows nothing; the answer only tells it whether the buddy is running.
                NativeMessages.Write(stdout, response ?? "{\"ok\":false}");
            }
        }
        catch (IOException e) { Console.Error.WriteLine("host: " + e); }
        finally { pipe?.Dispose(); }
        return 0;
    }

    private static string? TrySend(ref NamedPipeClientStream? pipe, string line)
    {
        for (var attempt = 0; attempt < 2; attempt++)
        {
            try
            {
                if (pipe is null || !pipe.IsConnected)
                {
                    pipe?.Dispose();
                    pipe = new NamedPipeClientStream(".", GuardianPipe.Name, PipeDirection.InOut, PipeOptions.CurrentUserOnly | PipeOptions.Asynchronous);
                    pipe.Connect(300);
                }
                var bytes = Encoding.UTF8.GetBytes(line);
                pipe.Write(bytes);
                pipe.Flush();
                using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(2));
                var response = new StringBuilder();
                var next = new byte[1];
                while (response.Length < 256)
                {
                    if (pipe.ReadAsync(next, timeout.Token).AsTask().GetAwaiter().GetResult() == 0) return null;
                    if (next[0] == '\n') return response.ToString();
                    response.Append((char)next[0]);
                }
                return null;
            }
            catch (Exception e) when (e is IOException or TimeoutException or UnauthorizedAccessException or OperationCanceledException)
            {
                Console.Error.WriteLine("send: " + e.GetType().Name + " " + e.Message);
                pipe?.Dispose();
                pipe = null; // companion not running, or restarted: try once more with a fresh connection
            }
        }
        return null;
    }
}

/// <summary>The companion's end of the pipe. Each line is one report from the extension.</summary>
public sealed class GuardianPipe : IDisposable
{
    /// <summary>One pipe per Windows user, so two people on one PC never mix.</summary>
    public static string Name => "LockIn.Guardian." + (WindowsIdentity.GetCurrent().User?.Value ?? "user");

    private const int MaxLine = NativeMessages.MaxBytes;
    private const int Instances = 8; // one connection per open browser (Chrome, Edge, Firefox, ...)
    private readonly Action<GuardianSignal> onSignal;
    private readonly Action<BrowserHeartbeat> onAlive;
    private readonly Func<string, LaterMessage, string?>? onLater;
    private readonly CancellationTokenSource stop = new();

    public GuardianPipe(Action<GuardianSignal> onSignal, Action<BrowserHeartbeat> onAlive,
        Func<string, LaterMessage, string?>? onLater = null)
    {
        this.onSignal = onSignal;
        this.onAlive = onAlive;
        this.onLater = onLater;
        for (var i = 0; i < Instances; i++) _ = Task.Run(ServeAsync);
    }

    private static NamedPipeServerStream Create()
    {
        var security = new PipeSecurity();
        var me = WindowsIdentity.GetCurrent().User!;
        security.AddAccessRule(new PipeAccessRule(new SecurityIdentifier(WellKnownSidType.NetworkSid, null),
            PipeAccessRights.FullControl, AccessControlType.Deny));
        security.AddAccessRule(new PipeAccessRule(me, PipeAccessRights.ReadWrite | PipeAccessRights.CreateNewInstance,
            AccessControlType.Allow));
        return NamedPipeServerStreamAcl.Create(Name, PipeDirection.InOut, Instances, PipeTransmissionMode.Byte,
            PipeOptions.Asynchronous, 0, 0, security);
    }

    private async Task ServeAsync()
    {
        while (!stop.IsCancellationRequested)
        {
            try
            {
                await using var server = Create();
                await server.WaitForConnectionAsync(stop.Token);
                using var reader = new StreamReader(server, Encoding.UTF8);
                var buffer = new StringBuilder();
                var chars = new char[256];
                int n;
                while ((n = await reader.ReadAsync(chars, stop.Token)) > 0)
                {
                    for (var i = 0; i < n; i++)
                    {
                        if (chars[i] != '\n') { buffer.Append(chars[i]); continue; }
                        var text = buffer.ToString();
                        string? request = null;
                        if (GuardianSignal.Parse(text) is { } signal) onSignal(signal);
                        else if (BrowserHeartbeat.Parse(text) is { } alive) onAlive(alive);
                        else if (LaterMessage.Parse(text) is { } later)
                        {
                            using var doc = JsonDocument.Parse(text);
                            if (doc.RootElement.TryGetProperty("browser", out var browser) && browser.ValueKind == JsonValueKind.String
                                && browser.GetString() is { Length: > 0 and <= 64 } name)
                                request = onLater?.Invoke(name, later);
                        }
                        var reply = JsonSerializer.Serialize(new { ok = true, savePage = request }) + "\n";
                        await server.WriteAsync(Encoding.UTF8.GetBytes(reply), stop.Token);
                        await server.FlushAsync(stop.Token);
                        buffer.Clear();
                    }
                    if (buffer.Length > MaxLine) break; // not a report; drop this client
                }
            }
            catch (OperationCanceledException) { return; }
            catch (IOException) { /* client left; wait for the next one */ }
            catch (UnauthorizedAccessException) { await Task.Delay(1000); }
        }
    }

    public void Dispose() => stop.Cancel();
}

/// <summary>
/// One-time setup so Chrome and Edge know where the host is:
/// <c>LockIn.Companion.exe --register-browser</c> (and <c>--unregister-browser</c>). Per user, no admin.
/// </summary>
public static class BrowserRegistration
{
    private static readonly string[] Keys =
    {
        @"Software\Google\Chrome\NativeMessagingHosts\" + NativeHost.Name,
        @"Software\Microsoft\Edge\NativeMessagingHosts\" + NativeHost.Name,
        @"Software\Chromium\NativeMessagingHosts\" + NativeHost.Name,
        @"Software\BraveSoftware\Brave-Browser\NativeMessagingHosts\" + NativeHost.Name,
        @"Software\Vivaldi\NativeMessagingHosts\" + NativeHost.Name,
    };

    /// <summary>Firefox reads its own key, and its host file names the extension by ID instead of by origin.</summary>
    private const string FirefoxKey = @"Software\Mozilla\NativeMessagingHosts\" + NativeHost.Name;

    public static string Register(string stateDir, string exePath)
    {
        Directory.CreateDirectory(stateDir);
        var manifest = Path.Combine(stateDir, "native-host.json");
        File.WriteAllText(manifest, JsonSerializer.Serialize(new
        {
            name = NativeHost.Name,
            description = "Lock In focus buddy",
            path = exePath,
            type = "stdio",
            allowed_origins = new[] { NativeHost.AllowedOrigin },
        }, new JsonSerializerOptions { WriteIndented = true }));
        foreach (var key in Keys)
        {
            using var k = Registry.CurrentUser.CreateSubKey(key);
            k.SetValue("", manifest);
        }

        var firefoxManifest = Path.Combine(stateDir, "native-host-firefox.json");
        File.WriteAllText(firefoxManifest, JsonSerializer.Serialize(new
        {
            name = NativeHost.Name,
            description = "Lock In focus buddy",
            path = exePath,
            type = "stdio",
            allowed_extensions = new[] { NativeHost.FirefoxId },
        }, new JsonSerializerOptions { WriteIndented = true }));
        using (var f = Registry.CurrentUser.CreateSubKey(FirefoxKey)) f.SetValue("", firefoxManifest);
        return manifest;
    }

    public static void Unregister()
    {
        foreach (var key in Keys.Append(FirefoxKey)) Registry.CurrentUser.DeleteSubKeyTree(key, throwOnMissingSubKey: false);
    }
}
