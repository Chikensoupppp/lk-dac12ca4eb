using System.Text.Json;

namespace LockIn.Companion.Watch;

/// <summary>
/// The user's consent for their accountability partner: one switch on the PC window. When it is on,
/// the partner can see the window title of what the user is on and can pause that app or site for a
/// few minutes. Off by default. Nothing is shared while it is off.
/// </summary>
public static class PartnerShare
{
    private static readonly object Gate = new();
    private static string? file;
    private static bool on;

    public static void Init(string? stateDir)
    {
        lock (Gate)
        {
            file = stateDir is null ? null : Path.Combine(stateDir, "partner-share.json");
            on = false;
            try
            {
                if (file is not null && File.Exists(file))
                    on = JsonSerializer.Deserialize<Saved>(File.ReadAllText(file))?.On ?? false;
            }
            catch (Exception) { /* a bad file means off */ }
        }
    }

    public static bool On
    {
        get { lock (Gate) return on; }
        set
        {
            lock (Gate)
            {
                on = value;
                try { if (file is not null) File.WriteAllText(file, JsonSerializer.Serialize(new Saved(value))); }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
            }
        }
    }

    private sealed record Saved(bool On);

    private static readonly string[] PrivateMarks = { "inprivate", "incognito", "private browsing", "private window" };
    private static readonly string[] BrowserTails =
    {
        " - Google Chrome", " - Microsoft Edge", " - Mozilla Firefox", " - Brave", " - Opera", " - Vivaldi",
        " — Mozilla Firefox", " - Personal - Microsoft Edge", " - Work - Microsoft Edge",
    };

    /// <summary>
    /// The window title the partner may see: the page or document name, trimmed. Private browser
    /// windows are never shared. Returns null when there is nothing fit to share.
    /// </summary>
    public static string? CleanTitle(string? title)
    {
        if (string.IsNullOrWhiteSpace(title)) return null;
        var t = title.Trim();
        foreach (var mark in PrivateMarks)
            if (t.Contains(mark, StringComparison.OrdinalIgnoreCase)) return null;
        foreach (var tail in BrowserTails)
            if (t.EndsWith(tail, StringComparison.OrdinalIgnoreCase)) { t = t[..^tail.Length]; break; }
        t = t.Trim();
        if (t.Length == 0) return null;
        return t.Length > 90 ? t[..89] + "…" : t;
    }
}
