using System.Drawing;
using System.Text;
using LockIn.Companion.Watch;

internal static class LaterChecks
{
    public static void Run(Action<bool, string> check)
    {
        var now = DateTimeOffset.UtcNow;
        var dir = Path.Combine(Path.GetTempPath(), "lockin-later-checks-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(dir);
        try
        {
            var store = new LaterStore(dir);
            const string url = "https://www.youtube.com/watch?v=synthetic-test";
            check(store.Save(url, now), "Later saves an explicitly chosen link");
            check(new LaterStore(dir).Read().Single().Url == url, "Later survives restart");
            check(!Encoding.UTF8.GetString(File.ReadAllBytes(Path.Combine(dir, "later.dat"))).Contains("youtube"), "Later links are encrypted at rest");
            check(store.Save(url, now.AddMinutes(1)) && store.Read().Count == 1, "Later deduplicates links");
            foreach (var bad in new[] { "file:///C:/test", "javascript:alert(1)", "http://reddit.com/", "https://reddit.com.evil.test/", "https://user:pass@youtube.com/", "https://youtube.com:444/", "https://example.test/", new string('x', 2049) })
                check(!store.Save(bad, now), "Later rejects unsafe or unsupported URL");
            check(store.Remove(url) && store.Read().Count == 0, "Later removes a link");
            File.WriteAllText(Path.Combine(dir, "later.dat"), "damaged synthetic file");
            check(store.Read().Count == 0, "Later tolerates corrupt storage");
            check(!store.Save(url, now) && !store.Remove(url)
                && File.ReadAllText(Path.Combine(dir, "later.dat")) == "damaged synthetic file", "Later preserves an unreadable original instead of overwriting it");
            File.Delete(Path.Combine(dir, "later.dat"));
            Parallel.For(0, 20, i => new LaterStore(dir).Save("https://www.youtube.com/watch?v=synthetic-" + i, now));
            check(store.Read().Count == 20, "Independent Later store instances do not lose concurrent saves");
            foreach (var item in store.Read()) store.Remove(item.Url);

            var capture = new LaterCapture();
            var front = new FrontWindow.Snapshot(new IntPtr(123), 123, "chrome", "Synthetic video - YouTube");
            check(capture.Poll("chrome", now) is null, "No click means no URL request");
            check(capture.Request("session-a", front, now), "Buddy click requests the foreground page");
            var token = capture.Poll("chrome", now)!;
            check(capture.Poll("firefox", now) is null, "Another browser cannot claim the request");
            check(capture.Complete("chrome", token, url, "session-b", front, now) is null, "A late response cannot cross sessions");
            check(capture.Complete("chrome", token, url, "session-a", front with { Handle = new IntPtr(456) }, now) is null, "Switching browser windows cancels capture");
            check(capture.Complete("chrome", token, "https://www.reddit.com/r/test/", "session-a", front, now) is null, "A response from another site is refused");
            check(capture.Complete("chrome", token, url, "session-a", front, now) == url, "The matching requested page is accepted");
            check(capture.Complete("chrome", token, url, "session-a", front, now) is null, "URL request is single-use");
            capture.Request("session-a", front, now);
            check(capture.Poll("chrome", now.AddSeconds(6)) is null, "URL request expires after five seconds");
            capture.Clear();
            check(capture.Poll("chrome", now) is null, "Session end clears the pending request");
            check(LaterMessage.Parse("{\"v\":1,\"kind\":\"later-poll\"}") is not null, "URL-free poll is parsed");
            check(LaterMessage.Parse("{\"v\":1,\"kind\":\"later-save\",\"request\":\"bad\",\"url\":\"https://youtube.com/\"}") is null, "Unbound URL response is rejected");

            using var bitmap = new Bitmap(BuddyScene.Width, BuddyScene.Height);
            using var graphics = Graphics.FromImage(bitmap);
            var scene = new BuddyScene();
            scene.Set(BuddyMood.Curious, "Is YouTube for your work?", 0, ask: true, saveLater: true);
            scene.Render(graphics, 2);
            if (Environment.GetEnvironmentVariable("LOCKIN_CHECK_SHOTS_DIR") is { } shots)
            {
                Directory.CreateDirectory(shots);
                bitmap.Save(Path.Combine(shots, "buddy-save-later.png"));
                store.Save(url, now);
                using var window = new LaterWindow(store);
                window.StartPosition = System.Windows.Forms.FormStartPosition.Manual;
                window.Location = new Point(-10000, -10000);
                window.ShowInTaskbar = false;
                window.Show();
                System.Windows.Forms.Application.DoEvents();
                using var screen = new Bitmap(window.Width, window.Height);
                window.DrawToBitmap(screen, new Rectangle(Point.Empty, window.Size));
                screen.Save(Path.Combine(shots, "later-list.png"));
            }
            var found = Enumerable.Range(0, bitmap.Height).Any(y => Enumerable.Range(0, bitmap.Width).Any(x => scene.HitTest(new Point(x, y)) == AskChoice.SaveLater));
            check(found, "Save for Later button is rendered and clickable");
            scene.Set(BuddyMood.Fresh, "Saved", 3);
            check(!Enumerable.Range(0, bitmap.Height).Any(y => Enumerable.Range(0, bitmap.Width).Any(x => scene.HitTest(new Point(x, y)) == AskChoice.SaveLater)), "Save button hit target clears with the question");

            using var pipeServer = new GuardianPipe(_ => { }, _ => { }, (browser, message) => browser == "chrome" && message.Kind == "later-poll" ? token : null);
            using var pipe = new System.IO.Pipes.NamedPipeClientStream(".", GuardianPipe.Name, System.IO.Pipes.PipeDirection.InOut, System.IO.Pipes.PipeOptions.CurrentUserOnly | System.IO.Pipes.PipeOptions.Asynchronous);
            pipe.Connect(2000);
            var poll = Encoding.UTF8.GetBytes("{\"v\":1,\"kind\":\"later-poll\",\"browser\":\"chrome\"}\n");
            pipe.Write(poll);
            pipe.Flush();
            using var reader = new StreamReader(pipe);
            using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(3));
            var response = reader.ReadLineAsync(timeout.Token).AsTask().GetAwaiter().GetResult();
            check(response?.Contains(token) == true, "Real private pipe round-trips the save request token");
        }
        finally { Directory.Delete(dir, recursive: true); }
    }
}
