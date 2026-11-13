namespace LockIn.Companion.Watch;

/// <summary>
/// What the buddy says. It always sounds kind: no blame, no shouting, no guilt. When the user is
/// off task it names what they are on and says that thing can wait. Each line is a full, plain
/// sentence and fits on two lines of the buddy. The pull-back count picks a different line each time.
/// </summary>
public static class BuddyWords
{
    // Keys are lower case. Browser sites come from Distractions.NameOf; games and chat are process names.
    private static readonly string[] Chat = { "Chat can wait a little. Ready to go back?", "Your messages will be there later." };
    private static readonly string[] Game = { "Games can wait. Ready to go back?", "Your game will be there after your session." };

    private static readonly Dictionary<string, string[]> ByApp = new()
    {
        ["youtube"] = new[] { "Videos can wait. Ready to go back?", "That video will still be there later." },
        ["tiktok"] = new[] { "TikTok can wait. Ready to go back?", "Those clips will still be there later." },
        ["reddit"] = new[] { "Reddit can wait. Ready to go back?", "Those posts will still be there later." },
        ["instagram"] = new[] { "Instagram can wait. Ready to go back?", "Your feed will still be there later." },
        ["netflix"] = new[] { "Your show can wait. Ready to go back?", "Save that show for your break." },
        ["twitch"] = new[] { "The stream can wait. Ready to go back?", "You can watch after your session." },
        ["discord"] = Chat,
        ["telegram"] = Chat,
        ["whatsapp"] = Chat,
        ["steam"] = Game,
        ["steamwebhelper"] = Game,
        ["epicgameslauncher"] = Game,
        ["riotclientux"] = Game,
        ["leagueclient"] = Game,
    };

    private static readonly string[] Generic = { "Ready to go back?", "That can wait. Ready to go back?" };

    /// <summary>After several pull-backs: still gentle, and it says it is okay.</summary>
    private static readonly string[] Cry =
    {
        "It's okay. Try one small step.",
        "No stress. Take a breath, then go back.",
        "Tough day? You can still do this.",
    };

    /// <summary>The question when a distraction comes to the front. <paramref name="friendly"/> is "YouTube", "Discord", ...</summary>
    public static string Ask(string? friendly) => friendly is null ? "Is this for your work?" : $"Is {friendly} for your work?";

    /// <summary>What the buddy says after the user taps "It's for work".</summary>
    public static string Allowed(string? friendly) => $"Got it. I'll leave {friendly ?? "that"} alone.";

    /// <summary>The scrolling reminder. Gentle, and about the project, not about the site.</summary>
    private static readonly string[] Scrolling =
    {
        "You've been scrolling for a bit. Back to your project?",
        "That's a lot of scrolling. Ready to pick your work back up?",
        "Still scrolling? Your project is waiting for you.",
    };

    public static string ScrollReminder(int count) => Scrolling[Math.Max(count, 0) % Scrolling.Length];

    /// <summary>After "Back to work" on the reminder. <paramref name="moved"/>: the work window came to the front.</summary>
    public static string BackFromScrolling(bool moved) =>
        moved ? "Nice. Back to it!" : "Nice. Switch to your work when you're ready.";

    public const string NotNow = "Okay. I'll check in later.";

    /// <summary>The first hello on the PC, right after the phone pairs: the same coach as on the phone.</summary>
    public const string Paired = "We're a team now! Let's lock in.";

    /// <summary>A browser without the Lock In extension (or without it in private windows), before and after the grace time.</summary>
    public static string BrowserWarning(string browser, bool privateOff) => privateOff
        ? $"Let Lock In run in private windows in {browser} too."
        : $"Lock In isn't on in {browser}. Turn it on to keep using it.";

    public static string BrowserPaused(string browser, bool privateOff) => privateOff
        ? $"{browser} is paused until Lock In works in private windows."
        : $"{browser} is paused until Lock In is back on.";

    /// <summary>How the buddy moves while it says this line: a question tilts its head, a cheer hops.</summary>
    public static BuddyGesture GestureFor(BuddyMood mood, string text) => mood switch
    {
        BuddyMood.Fresh => BuddyGesture.Hop,
        BuddyMood.Sleepy => BuddyGesture.Nod,
        BuddyMood.Spiral => BuddyGesture.Dizzy,
        BuddyMood.Excited => BuddyGesture.Cheer,
        BuddyMood.Crying or BuddyMood.Rotten => BuddyGesture.Sob,
        _ => text.Contains('?') ? BuddyGesture.Tilt : BuddyGesture.Sway,
    };

    /// <param name="mood">The buddy's mood.</param>
    /// <param name="app">Name from <see cref="Distractions.NameOf"/> (a site, or a process name). May be null.</param>
    /// <param name="nudges">How many times the user was pulled back this session.</param>
    public static string For(BuddyMood mood, string? app, int nudges)
    {
        var turn = Math.Max(nudges - 1, 0); // the first pull-back gets the first line
        switch (mood)
        {
            case BuddyMood.Fresh: return "You're locked in. Nice start!";
            case BuddyMood.Sleepy: return "Nice work. Keep going!";
            case BuddyMood.Spiral: return "Almost there. You've got this!";
            case BuddyMood.Excited: return "Almost there. You've got this!";
            case BuddyMood.Curious: return Ask(app is null ? null : Distractions.FriendlyName(app));
            case BuddyMood.Crying: return Cry[turn % Cry.Length];
            default:
                var lines = app is not null && ByApp.TryGetValue(app.ToLowerInvariant(), out var found) ? found : Generic;
                return lines[turn % lines.Length];
        }
    }
}
