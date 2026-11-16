namespace LockIn.Companion.Watch;

/// <summary>
/// What the accountability partner may see and do: the window title of what the user is on, and a
/// pause of that app or site for a few minutes. Always on; there is no switch, so the user cannot
/// turn it off. Private browser windows are still never shared (see CleanTitle).
/// </summary>
public static class PartnerShare
{
    public static bool On => true;

    public static void Init(string? stateDir) { }

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
