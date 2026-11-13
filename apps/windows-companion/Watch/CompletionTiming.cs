namespace LockIn.Companion.Watch;

/// <summary>Decides when a naturally finished session starts and ends its short celebration.</summary>
public static class CompletionTiming
{
    public static readonly TimeSpan CheerDuration = TimeSpan.FromSeconds(6);

    public enum Phase { Running, StartCheer, Cheering, Hide }

    public static Phase Evaluate(DateTimeOffset now, DateTimeOffset endsAt, DateTimeOffset? cheerUntil)
    {
        if (cheerUntil is { } until) return now < until ? Phase.Cheering : Phase.Hide;
        return now < endsAt ? Phase.Running : Phase.StartCheer;
    }
}
