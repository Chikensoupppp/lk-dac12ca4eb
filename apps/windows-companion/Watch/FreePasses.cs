namespace LockIn.Companion.Watch;

/// <summary>
/// The free session's way past the buddy's "Is it for work?" question. A few passes, not a blanket yes:
/// each one opens that site for a short while and then it is asked about again, a pass cannot be taken the
/// instant the question shows, and the passes do not come back during the session. A Locked session (Plus)
/// has no passes at all. It slows a person down; it does not stop them, and ending the session is always allowed.
/// </summary>
public sealed class FreePasses
{
    public const int PerSession = 2;

    /// <summary>How long one pass keeps its site open.</summary>
    public static readonly TimeSpan Lasts = TimeSpan.FromMinutes(15);

    // How long the question must have been up before a "yes" counts: the first pass, then the second.
    // Short on purpose: the question itself times out after 12 seconds.
    private static readonly TimeSpan[] Waits = { TimeSpan.FromSeconds(3), TimeSpan.FromSeconds(6) };

    private readonly Dictionary<string, DateTimeOffset> until = new(StringComparer.OrdinalIgnoreCase);
    private int used;

    public int Left => PerSession - used;

    /// <summary>False once both passes are used: the buddy stops asking and just minimizes.</summary>
    public bool CanAsk => used < PerSession;

    public void Reset()
    {
        used = 0;
        until.Clear();
    }

    /// <summary>True while a pass keeps this site open.</summary>
    public bool IsOpen(string key, DateTimeOffset now) => until.TryGetValue(key, out var end) && now < end;

    /// <summary>
    /// Tries to spend a pass on <paramref name="key"/>. False when none is left, or when the question has not
    /// been up long enough yet (<paramref name="stillToWait"/> says how much longer).
    /// </summary>
    public bool TryUse(string key, DateTimeOffset now, DateTimeOffset askedAt, out TimeSpan stillToWait)
    {
        stillToWait = TimeSpan.Zero;
        if (!CanAsk) return false;
        var wait = Waits[Math.Min(used, Waits.Length - 1)] - (now - askedAt);
        if (wait > TimeSpan.Zero)
        {
            stillToWait = wait;
            return false;
        }
        used++;
        until[key] = now + Lasts;
        return true;
    }
}
