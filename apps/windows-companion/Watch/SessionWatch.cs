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
    private bool hooked;

    private string? sessionId;
    private bool buddy;
    private string? task;
    private DateTimeOffset startedAt;
    private TimeSpan length;
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

    // A short line that overrides the clock mood for a few seconds ("Got it. I'll leave YouTube alone.").
    private string? sayText;
    private BuddyMood sayMood;
    private DateTimeOffset sayUntil;

    public SessionWatch(TimeProvider clock, AllowStore allowStore)
    {
        this.clock = clock;
        this.allowStore = allowStore;
        timer = new System.Threading.Timer(_ => Tick(), null, Timeout.Infinite, Timeout.Infinite);
    }

    /// <summary>
    /// Called when a session starts (or is mirrored from the phone). <paramref name="allow"/> are
    /// apps the phone already knows are fine for this session; the PC adds what this task remembered.
    /// </summary>
    public void Begin(string id, bool showBuddy, DateTimeOffset started, int durationSeconds,
        string? taskName = null, IEnumerable<string>? allow = null)
    {
        lock (gate)
        {
            if (sessionId == id) return;
            sessionId = id;
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
        }
        if (showBuddy && !hooked)
        {
            BuddyWindow.Instance.Chosen += OnChosen;
            hooked = true;
        }
        timer.Change(TimeSpan.Zero, Interval);
        BuddyWindow.Instance.SetMood(MoodFor(0, false, 0), showBuddy);
    }

    public void End(string? id)
    {
        lock (gate)
        {
            if (id is not null && sessionId != id) return;
            sessionId = null;
            asking = askName = declined = sayText = null;
        }
        timer.Change(Timeout.Infinite, Timeout.Infinite);
        BuddyWindow.Instance.SetMood(BuddyMood.Fresh, false);
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

    private void Tick()
    {
        string? id;
        bool showBuddy;
        DateTimeOffset started;
        TimeSpan total;
        lock (gate)
        {
            if (sessionId is null) return;
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
        bool ask = false;
        lock (gate)
        {
            if (sessionId != id) return;
            app = Distractions.NameOf(front);
            var off = isDistraction && key is not null && !allowed.Contains(key);

            if (!showBuddy)
            {
                // Phone-only mode: report, never touch a window.
                onTask = !off;
                if (off && !wasOff) nudges++;
                wasOff = off;
                return;
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
            else
            {
                mood = MoodFor(fraction, stayedHidden, nudges);
                words = BuddyWords.For(mood, app, nudges);
            }
        }

        // Minimize the distraction. Never close it: unsaved work must survive.
        if (minimize != IntPtr.Zero) ShowWindow(minimize, SwMinimize);
        BuddyWindow.Instance.SetMood(mood, true, words, ask);
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

    public void Dispose() => timer.Dispose();
}
