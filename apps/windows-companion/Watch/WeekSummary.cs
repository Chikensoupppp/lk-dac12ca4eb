using System.Text.Json;

namespace LockIn.Companion.Watch;

/// <summary>
/// The phone's week in one small record, shown as the "This week" row on the PC window. The phone
/// sends it when a session ends. Seconds of focus for Monday to Sunday, the weekly goal, the day
/// streak and today's total. Nothing else about the week leaves the phone.
/// </summary>
public sealed record WeekSummary(int[] DaySeconds, int GoalSeconds, int Streak, int TodaySeconds, int TodayIndex, int LastWeekSeconds = 0)
{
    public int TotalSeconds => DaySeconds.Sum();
}

public static class WeekStore
{
    private static readonly object Gate = new();
    private static string? file;
    private static WeekSummary? current;

    public static void Init(string? stateDir)
    {
        lock (Gate)
        {
            file = stateDir is null ? null : Path.Combine(stateDir, "week.json");
            current = null;
            try
            {
                if (file is not null && File.Exists(file))
                    current = Clean(JsonSerializer.Deserialize<WeekSummary>(File.ReadAllText(file)));
            }
            catch (Exception) { /* a bad file means no week row */ }
        }
    }

    public static WeekSummary? Current { get { lock (Gate) return current; } }

    /// When the phone last sent a week. The finish toast waits briefly for a fresh one.
    public static DateTimeOffset LastSet { get { lock (Gate) return lastSet; } }
    private static DateTimeOffset lastSet;

    /// <summary>Keeps only sane numbers. Returns false when the record is not usable.</summary>
    public static bool Set(WeekSummary? value)
    {
        var clean = Clean(value);
        if (clean is null) return false;
        lock (Gate)
        {
            current = clean;
            lastSet = DateTimeOffset.UtcNow;
            try { if (file is not null) File.WriteAllText(file, JsonSerializer.Serialize(clean)); }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
        }
        return true;
    }

    private static WeekSummary? Clean(WeekSummary? v)
    {
        if (v?.DaySeconds is not { Length: 7 }) return null;
        const int Day = 24 * 3600;
        return new WeekSummary(
            v.DaySeconds.Select(s => Math.Clamp(s, 0, Day)).ToArray(),
            Math.Clamp(v.GoalSeconds, 0, 7 * Day),
            Math.Clamp(v.Streak, 0, 3650),
            Math.Clamp(v.TodaySeconds, 0, Day),
            Math.Clamp(v.TodayIndex, 0, 6),
            Math.Clamp(v.LastWeekSeconds, 0, 7 * Day));
    }

    /// <summary>"4h 20m", "35m" or "0m".</summary>
    public static string Hours(int seconds)
    {
        var m = (seconds + 30) / 60;
        return m >= 60 ? (m % 60 == 0 ? $"{m / 60}h" : $"{m / 60}h {m % 60:00}m") : $"{m}m";
    }
}
