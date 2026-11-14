using System.Runtime.InteropServices;

namespace LockIn.Companion.Watch;

/// <summary>
/// While a session runs, looks at the front window every second. Only apps on the distraction list
/// can ever be touched; everything else (Word, Excel, a code editor, a school site) is left alone.
/// When a listed one comes to the front, the buddy ASKS first: "Is YouTube for your work?" with two
/// buttons. "It's for work" allows it for the rest of the session and remembers it for this task.
/// "Back to work", or no answer within 12 seconds, minimizes it (never closes it, so nothing the user
/// typed is lost). The buddy's brain changes with the time left and how often the user was pulled back.
/// The phone reads the state through /session/status.
///
/// Focus Guardian sits on top of that: on sites that are NOT blocked (allowed for this task, say YouTube
/// for lectures), the browser extension reports scrolling counts and <see cref="ScrollGuard"/> decides
/// when steady feed scrolling has lasted long enough for a gentle reminder with "Back to work" (brings
/// the last work window forward) and "Not now". It never minimizes or closes anything.
/// </summary>
public sealed class SessionWatch : IDisposable
{
    [DllImport("user32.dll")] private static extern bool ShowWindow(IntPtr hWnd, int cmd);
    private const int SwMinimize = 6;

    public static readonly TimeSpan Interval = TimeSpan.FromSeconds(1);
    private static readonly TimeSpan AskTime = TimeSpan.FromSeconds(BuddyScene.AskSeconds);
    private static readonly TimeSpan SayTime = TimeSpan.FromSeconds(4);

    /// <summary>After this many pull-backs the brain cries instead of just drooping.</summary>
    public const int CryAfterNudges = 3;

    private readonly object gate = new();
    private readonly System.Threading.Timer timer;
    private readonly TimeProvider clock;
    private readonly AllowStore allowStore;
    private readonly ScrollGuard guard;
    private readonly BrowserGuard browsers;
    private readonly LaterStore later;
    private readonly LaterCapture capture = new();
    private bool savedThisSession;
    private readonly WorkWindowMemory work = new();
    private readonly int ownProcessId = Environment.ProcessId;
    private bool hooked;

    private string? sessionId;
    private bool buddy;
    private string? task;
    private DateTimeOffset startedAt;
    private TimeSpan length;
    private DateTimeOffset? cheerUntil;
    private HashSet<string> allowed = new(StringComparer.OrdinalIgnoreCase);
    private int nudges;
    private string? app;
    private bool onTask = true;
    private bool wasOff;

    // The open question, if any.
    private string? asking;       // key of the app being asked about ("youtube")
    private string? askName;      // how the buddy says it ("YouTube")
    private DateTimeOffset askStarted;
    private IntPtr askHandle;
    private string? declined;     // an app the user already answered "no" for; left alone until they leave it

    // The scrolling reminder, if one is showing.
    private bool reminding;
    private DateTimeOffset remindStarted;
    private int reminders;

    // A short line that overrides the clock mood for a few seconds ("Got it. I'll leave YouTube alone.").
    private string? sayText;
    private BuddyMood sayMood;
    private DateTimeOffset sayUntil;

    public SessionWatch(TimeProvider clock, AllowStore allowStore, GuardianOptions? guardianOptions = null,
        string? stateDir = null)
    {
        this.clock = clock;
        this.allowStore = allowStore;
        guard = new ScrollGuard(guardianOptions);
        browsers = new BrowserGuard(TimeSpan.FromSeconds(guard.Options.BrowserGraceSeconds), stateDir);
        later = new LaterStore(stateDir ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "LockIn"));
        timer = new System.Threading.Timer(_ => Tick(), null, Timeout.Infinite, Timeout.Infinite);
    }

    /// <summary>
    /// Called when a session starts (or is mirrored from the phone). <paramref name="allow"/> are
    /// apps the phone already knows are fine for this session; the PC adds what this task remembered.
    /// </summary>
    public void Begin(string id, bool showBuddy, DateTimeOffset started, int durationSeconds,
        string? taskName = null, IEnumerable<string>? allow = null, int? remindAfterSeconds = null)
    {
        lock (gate)
        {
            if (sessionId == id) return;
            sessionId = id;
            capture.Clear();
            savedThisSession = false;
            cheerUntil = null;
            buddy = showBuddy;
            task = taskName;
            startedAt = started;
            length = TimeSpan.FromSeconds(durationSeconds);
            allowed = allowStore.For(taskName);
            foreach (var item in allow ?? Array.Empty<string>())
                if (!string.IsNullOrWhiteSpace(item)) allowed.Add(item.Trim().ToLowerInvariant());
            nudges = 0;
            wasOff = false;
            onTask = true;
            app = null;
            asking = askName = declined = sayText = null;
            guard.Reset(clock.GetUtcNow(), remindAfterSeconds);
            browsers.ResetWarnings();
            work.Clear();
            reminding = false;
            reminders = 0;
            if (showBuddy && !hooked)
            {
                BuddyWindow.Instance.Chosen += OnChosen;
                hooked = true;
            }
            BuddyWindow.Instance.SetMood(MoodFor(0, false, 0), showBuddy);
            timer.Change(TimeSpan.Zero, Interval);
        }
    }

    public void End(string? id)
    {
        lock (gate)
        {
            if (id is not null && sessionId != id) return;
            if (sessionId is null) return;
            var natural = clock.GetUtcNow() >= startedAt + length;
            ShowLaterLocked();
            sessionId = null;
            asking = askName = declined = sayText = null;
            guard.Reset(clock.GetUtcNow());
            work.Clear();
            reminding = false;
            if (natural && buddy)
            {
                cheerUntil = clock.GetUtcNow() + CompletionTiming.CheerDuration;
                BuddyWindow.Instance.SetMood(BuddyMood.Excited, true, "You did it! Great job.");
                return;
            }
            cheerUntil = null;
            timer.Change(Timeout.Infinite, Timeout.Infinite);
            BuddyWindow.Instance.SetMood(BuddyMood.Fresh, false);
        }
    }

    /// <summary>Status for the phone. Null when the id is not the running session.</summary>
    public (string? App, bool OnTask, int Nudges, string? Asking)? StatusFor(string id)
    {
        lock (gate)
        {
            if (sessionId != id) return null;
            return (app, onTask, nudges, askName);
        }
    }

    /// <summary>
    /// The brain's mood. Off task wins: droopy, or crying after several pull-backs. On task it
    /// drifts with the session: fresh at the start, sleepy in the middle, excited near the end
    /// (the finish is good news, so no dizzy face). These cut-offs are a first guess; tune them with Brandon.
    /// </summary>
    public static BuddyMood MoodFor(double fractionDone, bool off, int nudgeCount)
    {
        if (off) return nudgeCount >= CryAfterNudges ? BuddyMood.Crying : BuddyMood.Droopy;
        if (fractionDone < 0.4) return BuddyMood.Fresh;
        if (fractionDone < 0.75) return BuddyMood.Sleepy;
        return BuddyMood.Excited;
    }

    /// <summary>
    /// A report from the browser extension. Ignored outside a session and in phone-only mode
    /// (no buddy on screen, so nobody to remind).
    /// </summary>
    public void Report(GuardianSignal signal)
    {
        lock (gate)
        {
            if (sessionId is null || !buddy) return;
            guard.Report(clock.GetUtcNow(), signal);
        }
    }

    /// <summary>
    /// A short cheer from the buddy outside a session (after pairing). It shows for a few seconds and
    /// hides again, unless a session started meanwhile; then the session owns the buddy.
    /// </summary>
    public void Greet(string words)
    {
        lock (gate) { if (sessionId is not null) return; }
        BuddyWindow.Instance.SetMood(BuddyMood.Excited, true, words);
        _ = Task.Delay(TimeSpan.FromSeconds(8)).ContinueWith(_ =>
        {
            lock (gate) { if (sessionId is not null) return; }
            BuddyWindow.Instance.SetMood(BuddyMood.Fresh, false);
        });
    }

    /// <summary>A browser says its Lock In extension is running. Kept between sessions too.</summary>
    public void Heartbeat(BrowserHeartbeat beat)
    {
        lock (gate) browsers.Heartbeat(clock.GetUtcNow(), beat);
    }

    /// <summary>Request/response stays on the same user's native pipe; only a click can save a URL.</summary>
    public string? HandleLater(string browser, LaterMessage message)
    {
        lock (gate)
        {
            var now = clock.GetUtcNow();
            if (sessionId is null || !buddy || now >= startedAt + length) return null;
            if (message.Kind == "later-poll") return capture.Poll(browser, now);
            var front = FrontWindow.Current();
            var url = capture.Complete(browser, message.Request!, message.Url!, sessionId, front, now);
            if (url is null) return null;
            var saved = later.Save(url, now);
            sayText = saved ? "Saved for later. Back to it!" : "Couldn't save. Try again.";
            sayMood = BuddyMood.Fresh;
            sayUntil = now + SayTime;
            if (saved)
            {
                savedThisSession = true;
                if (asking is not null) ShowWindow(DeclineLocked(), SwMinimize);
                else if (reminding)
                {
                    reminding = false;
                    guard.Answered(now, true);
                    if (front is not null) ShowWindow(front.Handle, SwMinimize);
                }
            }
            BuddyWindow.Instance.SetMood(BuddyMood.Fresh, true, sayText);
            return null;
        }
    }

    private void ShowLaterLocked()
    {
        capture.Clear();
        if (!savedThisSession) return;
        savedThisSession = false;
        BuddyWindow.Instance.ShowLater(later);
    }

    private void Tick()
    {
        string? id;
        bool showBuddy;
        DateTimeOffset started;
        TimeSpan total;
        lock (gate)
        {
            var observedAt = clock.GetUtcNow();
            if (sessionId is null)
            {
                if (cheerUntil is { } until && observedAt >= until)
                {
                    cheerUntil = null;
                    timer.Change(Timeout.Infinite, Timeout.Infinite);
                    BuddyWindow.Instance.SetMood(BuddyMood.Fresh, false);
                }
                return;
            }
            if (CompletionTiming.Evaluate(observedAt, startedAt + length, null) == CompletionTiming.Phase.StartCheer)
            {
                ShowLaterLocked();
                sessionId = null;
                asking = askName = declined = sayText = null;
                guard.Reset(observedAt);
                work.Clear();
                reminding = false;
                if (buddy)
                {
                    cheerUntil = observedAt + CompletionTiming.CheerDuration;
                    BuddyWindow.Instance.SetMood(BuddyMood.Excited, true, "You did it! Great job.");
                }
                else
                {
                    timer.Change(Timeout.Infinite, Timeout.Infinite);
                    BuddyWindow.Instance.SetMood(BuddyMood.Fresh, false);
                }
                return;
            }
            id = sessionId;
            showBuddy = buddy;
            started = startedAt;
            total = length;
        }

        var front = FrontWindow.Current();
        var key = Distractions.KeyOf(front);
        var isDistraction = Distractions.IsDistraction(front);
        var now = clock.GetUtcNow();
        var fraction = total.TotalSeconds > 0 ? Math.Clamp((now - started).TotalSeconds / total.TotalSeconds, 0, 1) : 0;

        IntPtr minimize = IntPtr.Zero;
        BuddyMood mood;
        string words;
        bool ask = false, scrolling = false;
        lock (gate)
        {
            if (sessionId != id) return;
            if (capture.Expired(now))
            {
                capture.Clear();
                sayText = "Couldn't save. Check the extension.";
                sayMood = BuddyMood.Fresh;
                sayUntil = now + SayTime;
            }
            app = Distractions.NameOf(front);
            var off = isDistraction && key is not null && !allowed.Contains(key);
            work.Seen(front, ownProcessId);

            if (!showBuddy)
            {
                // Phone-only mode: report, never touch a window.
                onTask = !off;
                if (off && !wasOff) nudges++;
                wasOff = off;
                return;
            }

            // A browser the buddy cannot see into (extension off, or off in private windows): warn, then
            // keep it minimized while it is in front. Checked first: everything below relies on the extension.
            var check = Distractions.IsBrowser(front) ? browsers.Check(now, front!.Process.ToLowerInvariant()) : default;
            if (check.Problem != BrowserGuard.Problem.None)
            {
                var name = Distractions.FriendlyName(front!.Process);
                var privateOff = check.Problem == BrowserGuard.Problem.PrivateOff;
                onTask = false;
                if (check.Paused)
                {
                    minimize = front.Handle;
                    mood = BuddyMood.Droopy;
                    words = BuddyWords.BrowserPaused(name, privateOff);
                }
                else
                {
                    mood = BuddyMood.Curious;
                    words = BuddyWords.BrowserWarning(name, privateOff);
                }
                if (now < sayUntil && sayText is not null) { mood = sayMood; words = sayText; }
                goto show;
            }

            var stayedHidden = false;
            if (!off)
            {
                asking = askName = declined = null;
                onTask = true;
                wasOff = false;
            }
            else if (declined == key)
            {
                // Already answered "no": keep it minimized until the user leaves it.
                onTask = false;
                minimize = front!.Handle;
                stayedHidden = true;
            }
            else if (asking == key)
            {
                askHandle = front!.Handle;
                onTask = false;
                if (now - askStarted >= AskTime)
                {
                    minimize = DeclineLocked();
                    stayedHidden = true;
                }
            }
            else
            {
                asking = key;
                askName = Distractions.FriendlyName(Distractions.NameOf(front));
                askStarted = now;
                askHandle = front!.Handle;
                onTask = false;
            }

            // Guardian: only on pages the blocking left open, only while a browser is in front,
            // and never on top of the "Is it for work?" question.
            if (reminding && (off || asking is not null || now - remindStarted >= AskTime))
                reminding = false; // no answer counts as "not now"; the cooldown started when it was shown
            if (!reminding && !off && asking is null && Distractions.IsBrowser(front) && guard.ShouldRemind(now))
            {
                reminding = true;
                remindStarted = now;
                guard.Reminded(now);
                reminders++;
            }

            if (now < sayUntil && sayText is not null)
            {
                mood = sayMood;
                words = sayText;
            }
            else if (asking is not null)
            {
                mood = BuddyMood.Curious;
                words = BuddyWords.Ask(askName);
                ask = true;
            }
            else if (reminding)
            {
                mood = BuddyMood.Curious;
                words = BuddyWords.ScrollReminder(reminders - 1);
                ask = scrolling = true;
            }
            else
            {
                mood = MoodFor(fraction, stayedHidden, nudges);
                words = BuddyWords.For(mood, app, nudges);
            }
        }

        show:
        lock (gate)
        {
            // A tick may have read the foreground window while the session ended.
            if (sessionId != id) return;
            // Minimize the distraction. Never close it: unsaved work must survive.
            if (minimize != IntPtr.Zero) ShowWindow(minimize, SwMinimize);
            var canSave = ask && Distractions.IsBrowser(front) && key is "youtube" or "reddit";
            BuddyWindow.Instance.SetMood(mood, true, words, ask, scrolling, canSave);
        }
    }

    /// <summary>The user said "no" (or did not answer in time). Call with the lock held.</summary>
    private IntPtr DeclineLocked()
    {
        var handle = askHandle;
        nudges++;
        declined = asking;
        wasOff = true;
        asking = askName = null;
        return handle;
    }

    /// <summary>The user tapped a button on the buddy's question.</summary>
    private void OnChosen(AskChoice choice)
    {
        if (choice == AskChoice.SaveLater)
        {
            lock (gate)
            {
                if (sessionId is null || (!reminding && asking is null)) return;
                if (capture.Request(sessionId, FrontWindow.Current(), clock.GetUtcNow()))
                {
                    sayText = "Saving this page...";
                    sayMood = BuddyMood.Fresh;
                    sayUntil = clock.GetUtcNow() + TimeSpan.FromSeconds(5);
                    BuddyWindow.Instance.SetMood(BuddyMood.Fresh, true, sayText);
                }
            }
            return;
        }
        if (TryAnswerReminder(choice)) return;
        IntPtr minimize = IntPtr.Zero;
        string? say = null;
        lock (gate)
        {
            if (sessionId is null || asking is null) return;
            if (choice == AskChoice.ForWork)
            {
                allowed.Add(asking);
                allowStore.Add(task, asking);
                say = BuddyWords.Allowed(askName);
                sayText = say;
                sayMood = BuddyMood.Fresh;
                sayUntil = clock.GetUtcNow() + SayTime;
                asking = askName = declined = null;
                onTask = true;
                wasOff = false;
            }
            else
            {
                minimize = DeclineLocked();
            }
        }
        if (minimize != IntPtr.Zero) ShowWindow(minimize, SwMinimize);
        if (say is not null) BuddyWindow.Instance.SetMood(BuddyMood.Fresh, true, say);
    }

    /// <summary>
    /// The answer to the scrolling reminder. Runs on the buddy's thread right after the click, which is
    /// when Windows lets this program bring another window to the front.
    /// </summary>
    private bool TryAnswerReminder(AskChoice choice)
    {
        IntPtr? target;
        lock (gate)
        {
            if (sessionId is null || !reminding || choice is not (AskChoice.BackToWork or AskChoice.NotNow)) return false;
            reminding = false;
            var now = clock.GetUtcNow();
            guard.Answered(now, choice == AskChoice.BackToWork);
            target = choice == AskChoice.BackToWork ? work.TargetFor(FrontWindow.Current()) : null;
        }
        var say = choice == AskChoice.NotNow
            ? BuddyWords.NotNow
            : BuddyWords.BackFromScrolling(target is { } handle && FrontWindow.BringToFront(handle));
        lock (gate)
        {
            sayText = say;
            sayMood = BuddyMood.Fresh;
            sayUntil = clock.GetUtcNow() + SayTime;
        }
        BuddyWindow.Instance.SetMood(BuddyMood.Fresh, true, say);
        return true;
    }

    public void Dispose() => timer.Dispose();
}
