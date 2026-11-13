using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;

namespace LockIn.Companion.Watch;

/// <summary>What the user tapped on the buddy's question.</summary>
public enum AskChoice { None, ForWork, BackToWork }

/// <summary>How the buddy moves while it talks. Each line of speech picks one (see <see cref="BuddyWords.GestureFor"/>).</summary>
public enum BuddyGesture
{
    Hop,   // a cheer: hops, with a burst of stars
    Nod,   // "nice work": nods, with a check badge
    Dizzy, // "almost there": wobbles, eyes spin, stars orbit
    Tilt,  // a question: tilts its head, with a "?" badge
    Sway,  // "it can wait": sways slowly, hearts float up
    Sob,   // crying: shakes, tears keep falling
    Cheer, // "almost there": one happy jump and a wiggle, thumbs-up badge, sparkles all around
}

/// <summary>
/// One buddy, drawn for any moment in time: the brain with its pose, little extras around it, and a
/// speech bubble that pops in, types the words out while the mouth moves, waits, then fades away.
/// The window and the test pictures both draw through this class, so what the pictures show is
/// what the window shows. No window code in here.
/// </summary>
public sealed class BuddyScene
{
    public const int Width = 240, Height = 256;
    private const int BrainTop = 92;          // the brain's area starts here; the bubble sits above it
    private const double TypeStart = 0.25;    // seconds after the bubble pops in
    private const double CharsPerSecond = 34;
    private const double HoldSeconds = 6.0;   // how long the finished bubble stays
    private const double FadeSeconds = 0.45;
    private const double MoodBlendSeconds = 1.8; // colors and face drift from one mood to the next

    private static readonly Color Cream = Color.FromArgb(0xF7, 0xF3, 0xE8);
    private static readonly Color Ink = Color.FromArgb(0x40, 0x16, 0x2A);
    private static readonly Color Sun = Color.FromArgb(0xFF, 0xB5, 0x11);
    private static readonly Color Gold = Color.FromArgb(0xFF, 0xC4, 0x40);
    private static readonly Color Heart = Color.FromArgb(0xFF, 0x60, 0x82);
    private static readonly Font BubbleFont = new("Segoe UI", 10f, FontStyle.Bold);
    private static readonly Font BadgeFont = new("Segoe UI", 13f, FontStyle.Bold);
    private static readonly Font ButtonFont = new("Segoe UI", 8.5f, FontStyle.Bold);
    private static readonly StringFormat Typographic = StringFormat.GenericTypographic;

    /// <summary>How long the buddy waits for an answer before it counts as "no" (the watcher uses the same number).</summary>
    public const double AskSeconds = 12;

    private BuddyMood mood = BuddyMood.Fresh;
    private BuddyMood fromMood = BuddyMood.Fresh;
    private string text = "";
    private BuddyGesture gesture = BuddyGesture.Hop;
    private double speechStart = double.NegativeInfinity;
    private double moodStart = double.NegativeInfinity;
    private List<string>? lines;
    private bool asking;
    private double askStart;
    private RectangleF yesRect = RectangleF.Empty, noRect = RectangleF.Empty; // the two buttons, in window pixels

    /// <summary>
    /// Call whenever the mood or the words may have changed. Same mood and words: nothing restarts.
    /// <paramref name="ask"/> true shows the two buttons ("It's for work" / "Back to work") and a countdown.
    /// </summary>
    public void Set(BuddyMood nextMood, string nextText, double now, bool ask = false)
    {
        if (ask && !asking) askStart = now;
        if (!ask)
        {
            yesRect = noRect = RectangleF.Empty;
        }
        var askChanged = ask != asking;
        asking = ask;
        if (nextMood == mood && nextText == text && !askChanged && !double.IsNegativeInfinity(speechStart)) return;
        if (double.IsNegativeInfinity(moodStart))
        {
            fromMood = nextMood;
            moodStart = now;
        }
        else if (nextMood != mood)
        {
            // Blend from whatever the buddy mostly looks like right now.
            fromMood = MoodBlend(now) < 0.5f ? fromMood : mood;
            moodStart = now;
        }
        mood = nextMood;
        text = nextText;
        gesture = BuddyWords.GestureFor(nextMood, nextText);
        speechStart = now;
        lines = null;
    }

    /// <summary>Forget everything, so the next session starts with a fresh greeting.</summary>
    public void Reset()
    {
        mood = BuddyMood.Fresh;
        fromMood = BuddyMood.Fresh;
        text = "";
        asking = false;
        yesRect = noRect = RectangleF.Empty;
        speechStart = double.NegativeInfinity;
        moodStart = double.NegativeInfinity;
        lines = null;
    }

    /// <summary>True while something is moving fast (a fresh line of speech); the window then draws more often.</summary>
    public bool Busy(double now) => asking || now - speechStart < TypeStart + text.Length / CharsPerSecond + HoldSeconds + 1;

    /// <summary>Which button, if any, is at this point of the window.</summary>
    public AskChoice HitTest(Point p) =>
        yesRect.Contains(p) ? AskChoice.ForWork : noRect.Contains(p) ? AskChoice.BackToWork : AskChoice.None;

    /// <summary>0 at a mood change, easing to 1 when the new look is complete.</summary>
    private float MoodBlend(double now)
    {
        var t = Math.Clamp((now - moodStart) / MoodBlendSeconds, 0, 1);
        return (float)(t * t * (3 - 2 * t));
    }

    public void Render(Graphics g, double now)
    {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = TextRenderingHint.AntiAlias; // ClearType leaves color fringes on a see-through picture

        var tt = now - speechStart;
        var typedChars = Math.Clamp((tt - TypeStart) * CharsPerSecond, 0, text.Length);
        var typing = tt >= TypeStart && typedChars < text.Length;
        var pose = PoseFor(now, tt, now - moodStart, typing);

        var area = new RectangleF(0, BrainTop, Width, Height - BrainTop);
        BrainArt.Draw(g, StageOf(mood), area, pose);
        DrawExtras(g, area, pose, tt, now);
        DrawBubble(g, tt, (int)typedChars, now);
    }

    // ---- motion --------------------------------------------------------------------------

    /// <summary>The app's brain stage for a mood. Excited uses the fresh brain (with star eyes).</summary>
    private static int StageOf(BuddyMood m) => m is BuddyMood.Excited or BuddyMood.Curious ? 0 : (int)m;

    private BrainPose PoseFor(double now, double tt, double tm, bool typing)
    {
        var p = BrainPose.Rest;
        p.Time = (float)now;
        p.FromStage = StageOf(fromMood);
        p.Blend = MoodBlend(now);
        p.FromStarEyes = fromMood == BuddyMood.Excited;
        p.StarEyes = mood == BuddyMood.Excited;

        // Always: breathing, and a blink every few seconds.
        var breath = Math.Sin(now * 2 * Math.PI * 0.45);
        p.Sy = 1 + 0.012f * (float)breath;
        p.Sx = 1 - 0.008f * (float)breath;
        var blinkAt = now % 3.6;
        if (blinkAt < 0.14) p.Blink = (float)Math.Sin(Math.PI * blinkAt / 0.14);

        // Full strength while it speaks, then it calms to a quarter and keeps idling.
        var e = tt < 0 ? 0.0 : Math.Clamp(1.2 - (tt - 3.5) / 1.5, 0.25, 1.0);
        var ef = (float)e;

        switch (gesture)
        {
            case BuddyGesture.Hop:
            {
                // Two hops when it says hello, then it stays still. It does not keep bouncing.
                const double rate = 1.7, hops = 2;
                if (tt >= 0 && tt < hops / rate)
                {
                    var air = Math.Sin(Math.PI * ((tt * rate) % 1));
                    p.Dy = -16 * (float)air;
                    p.Sy += 0.05f * (float)air - 0.08f * (float)Math.Pow(1 - air, 8);
                    p.Sx = 1 / (float)Math.Sqrt(Math.Max(p.Sy, 0.5));
                }
                break;
            }
            case BuddyGesture.Nod:
            {
                // A few nods while it talks, getting smaller, then still.
                if (tt >= 0 && tt < 2.5)
                {
                    var n = Math.Sin(2 * Math.PI * 1.2 * tt) * (1 - tt / 2.5);
                    p.Dy = 6 * (float)n;
                    p.Tilt = 1.5f * (float)n;
                }
                break;
            }
            case BuddyGesture.Cheer:
            {
                // One big happy jump, then a little side-to-side wiggle while it talks, then still.
                const double jump = 0.6;
                if (tt >= 0 && tt < jump)
                {
                    var air = Math.Sin(Math.PI * tt / jump);
                    p.Dy = -22 * (float)air;
                    p.Sy += 0.07f * (float)air - 0.09f * (float)Math.Pow(1 - air, 8);
                    p.Sx = 1 / (float)Math.Sqrt(Math.Max(p.Sy, 0.5));
                }
                else if (tt >= jump && tt < 3.0)
                {
                    var fadeW = 1 - (tt - jump) / (3.0 - jump);
                    p.Tilt = 5 * (float)(Math.Sin(2 * Math.PI * 2.0 * (tt - jump)) * fadeW);
                }
                break;
            }
            case BuddyGesture.Dizzy:
                p.Tilt = 7 * ef * (float)Math.Sin(2 * Math.PI * 0.9 * now);
                p.Dx = 7 * ef * (float)Math.Sin(2 * Math.PI * 0.9 * now + Math.PI / 2);
                p.SpiralTurn = (float)(now * 5);
                break;
            case BuddyGesture.Tilt:
            {
                var ease = (float)(1 - Math.Exp(-Math.Max(tt, 0) * 6));
                p.Tilt = (9 * (0.4f + 0.6f * ef) + 2.5f * (float)Math.Sin(2 * Math.PI * 0.6 * now)) * ease;
                p.Dx = 4 * ease;
                break;
            }
            case BuddyGesture.Sway:
                p.Tilt = 5 * ef * (float)Math.Sin(2 * Math.PI * 0.5 * now);
                p.Dx = 6 * ef * (float)Math.Sin(2 * Math.PI * 0.5 * now + 0.6);
                break;
            case BuddyGesture.Sob:
            {
                var heave = Math.Pow(Math.Max(0, Math.Sin(2 * Math.PI * 0.9 * now)), 3);
                p.Dy = ef * (float)(2.2 * Math.Sin(2 * Math.PI * 6 * now) + 4 * heave);
                p.Sy -= 0.05f * ef * (float)heave;
                p.Tilt = 1.8f * (float)Math.Sin(2 * Math.PI * 2.5 * now);
                p.TearPhase = (float)((now * 0.9) % 1);
                break;
            }
        }

        // The mouth moves while the words come out.
        if (typing) p.MouthOpen = (float)Math.Clamp(Math.Abs(Math.Sin(tt * 19)) * (0.55 + 0.45 * Math.Sin(tt * 7.3)), 0, 1);
        return p;
    }

    // ---- extras around the head ----------------------------------------------------------

    private void DrawExtras(Graphics g, RectangleF area, BrainPose pose, double tt, double now)
    {
        if (tt < 0) return;
        var s = Math.Min(area.Width / 364f, area.Height / 300f);
        var ox = area.Left + (area.Width - 364 * s) / 2;
        var oy = area.Top + (area.Height - 300 * s) / 2;
        PointF At(float x, float y) => new(ox + x * s + pose.Dx * s, oy + y * s + pose.Dy * s);

        if (gesture == BuddyGesture.Cheer)
        {
            // Sparkles all around that twinkle in and out, white and gold, the whole time it is excited.
            var spots = new (float X, float Y, float R, bool White)[]
            {
                (30, 70, 11, false), (334, 54, 10, false), (16, 190, 8, true), (350, 176, 12, false),
                (70, 266, 7, true), (300, 270, 9, false), (182, -6, 8, true), (110, 10, 6, false), (262, 6, 7, true),
            };
            for (var i = 0; i < spots.Length; i++)
            {
                var twinkle = (float)Math.Pow(Math.Max(0, Math.Sin(now * 2.6 + i * 1.7)), 1.3);
                if (twinkle < 0.03f) continue;
                var c = At(spots[i].X, spots[i].Y);
                using var star = Star(c.X, c.Y, spots[i].R * s * 2.1f * (0.5f + 0.5f * twinkle));
                using var brush = new SolidBrush(Color.FromArgb((int)(255 * twinkle), spots[i].White ? Color.White : Gold));
                g.FillPath(brush, star);
                if (spots[i].White)
                {
                    using var edge = new Pen(Color.FromArgb((int)(200 * twinkle), Gold), 1.2f);
                    g.DrawPath(edge, star);
                }
            }
            if (tt < 1.3) Burst(g, At, tt);
            if (tt > 0.35 && tt < 7.5)
            {
                var u = (float)Math.Clamp((tt - 0.35) / 0.3, 0, 1);
                var alpha = tt > 6.9 ? (float)(1 - (tt - 6.9) / 0.6) : 1f;
                var c = At(306, 46);
                c.Y += 2.5f * (float)Math.Sin(now * 3);
                Badge(g, c, (0.3f + 0.7f * EaseOutBack(u)) * 1.4f, alpha, BadgeKind.ThumbsUp);
            }
            return;
        }

        switch (gesture)
        {
            case BuddyGesture.Hop when tt < 1.3:
                Burst(g, At, tt);
                break;
            case BuddyGesture.Nod when tt > 0.3 && tt < 5.5:
            {
                var u = (float)Math.Clamp((tt - 0.3) / 0.3, 0, 1);
                var alpha = tt > 4.9 ? (float)(1 - (tt - 4.9) / 0.6) : 1f;
                Badge(g, At(300, 40), 0.3f + 0.7f * EaseOutBack(u), alpha, BadgeKind.Check);
                break;
            }
            case BuddyGesture.Dizzy:
                for (var i = 0; i < 3; i++)
                {
                    var a = now * 3.2 + i * 2 * Math.PI / 3;
                    var c = At(182 + (float)Math.Cos(a) * 90, 22 + (float)Math.Sin(a) * 14);
                    using var star = Star(c.X, c.Y, 6.5f);
                    using var brush = new SolidBrush(Gold);
                    g.FillPath(brush, star);
                }
                break;
            case BuddyGesture.Tilt when tt > 0.15 && tt < 6.5:
            {
                var u = (float)Math.Clamp((tt - 0.15) / 0.3, 0, 1);
                var alpha = tt > 6.0 ? (float)(1 - (tt - 6.0) / 0.5) : 1f;
                var c = At(300, 38);
                c.Y += 3 * (float)Math.Sin(now * 4);
                Badge(g, c, 0.3f + 0.7f * EaseOutBack(u), alpha, BadgeKind.Question);
                break;
            }
            case BuddyGesture.Sway:
                for (var i = 0; i < 3; i++)
                {
                    var phase = (now * 0.45 + i / 3.0) % 1;
                    var c = At(182 + (i - 1) * 62 + 10 * (float)Math.Sin(phase * 6 + i), 20 - (float)phase * 90);
                    var alpha = (int)(255 * Math.Sin(Math.PI * phase));
                    using var path = HeartPath(c.X, c.Y, 5.5f);
                    using var brush = new SolidBrush(Color.FromArgb(alpha, Heart));
                    g.FillPath(brush, path);
                }
                break;
        }
    }

    /// <summary>A ring of gold stars flying out from the head, once.</summary>
    private static void Burst(Graphics g, Func<float, float, PointF> at, double tt)
    {
        var u = (float)Math.Clamp((tt - 0.05) / 1.1, 0, 1);
        var fade = 1 - u;
        for (var i = 0; i < 6; i++)
        {
            var a = Math.PI / 180 * (i * 60 + 15);
            var r = 100 + 75 * (1 - (1 - u) * (1 - u));
            var c = at(182 + (float)Math.Cos(a) * r, 150 + (float)Math.Sin(a) * r * 0.8f);
            using var star = Star(c.X, c.Y, 6.5f * (1 - 0.5f * u));
            using var brush = new SolidBrush(Color.FromArgb((int)(255 * fade), Gold));
            g.FillPath(brush, star);
        }
    }

    private enum BadgeKind { Check, Question, ThumbsUp }

    private static void Badge(Graphics g, PointF center, float scale, float alpha, BadgeKind kind)
    {
        var saved = g.Save();
        g.TranslateTransform(center.X, center.Y);
        g.ScaleTransform(scale, scale);
        var a = (int)(255 * Math.Clamp(alpha, 0, 1));
        using var fill = new SolidBrush(Color.FromArgb(a, Sun));
        using var outline = new Pen(Color.FromArgb(a, Ink), 2.2f);
        g.FillEllipse(fill, -13, -13, 26, 26);
        g.DrawEllipse(outline, -13, -13, 26, 26);
        if (kind == BadgeKind.Check)
        {
            using var tick = new Pen(Color.FromArgb(a, Ink), 3f) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round };
            g.DrawLines(tick, new[] { new PointF(-5.5f, 0.5f), new PointF(-1.5f, 4.5f), new PointF(6, -4.5f) });
        }
        else if (kind == BadgeKind.ThumbsUp)
        {
            // A drawn thumbs-up (a fist with the thumb up, and a cuff), in the buddy's ink.
            using var ink = new SolidBrush(Color.FromArgb(a, Ink));
            using var fist = RoundRect(-4.5f, -1.5f, 11, 10, 3);
            using var thumb = RoundRect(-3.5f, -10.5f, 4.6f, 11, 2.3f);
            g.FillPath(ink, fist);
            g.FillPath(ink, thumb);
            g.FillRectangle(ink, -9f, -0.5f, 3.4f, 9);
            using var fingers = new Pen(Color.FromArgb(a, Sun), 1.1f) { StartCap = LineCap.Round, EndCap = LineCap.Round };
            g.DrawLine(fingers, 1.5f, 1.5f, 5.5f, 1.5f);
            g.DrawLine(fingers, 1.5f, 4.3f, 5.5f, 4.3f);
        }
        else
        {
            using var ink = new SolidBrush(Color.FromArgb(a, Ink));
            using var centered = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
            g.DrawString("?", BadgeFont, ink, new RectangleF(-13, -14, 26, 26), centered);
        }
        g.Restore(saved);
    }

    // ---- speech bubble -------------------------------------------------------------------

    private void DrawBubble(Graphics g, double tt, int shownChars, double now)
    {
        if (tt < 0 || text.Length == 0) return;
        var endTyping = TypeStart + text.Length / CharsPerSecond;
        // A question stays until it is answered; other lines fade away after a few seconds.
        var fade = !asking && tt > endTyping + HoldSeconds ? 1 - (tt - endTyping - HoldSeconds) / FadeSeconds : 1;
        var alpha = Math.Min(1, tt / 0.12) * fade;
        if (alpha <= 0.01) return;

        // Wrap once, using the whole sentence, so the bubble keeps its size while the words type in.
        lines ??= Wrap(g, text, Width - 12 - 26);
        var lineHeight = BubbleFont.GetHeight(g);
        var widest = lines.Max(l => g.MeasureString(l, BubbleFont, int.MaxValue, Typographic).Width);
        const float buttonRoom = 46; // buttons row plus the countdown line
        var w = Math.Max(widest + 26, asking ? 212 : 0);
        var h = lines.Count * lineHeight + 18 + (asking ? buttonRoom : 0);
        var tailX = Width / 2f + 14;
        var x = Math.Clamp(tailX - w * 0.6f, 6, Width - 6 - w);
        var bottom = BrainTop - 16f;
        var y = Math.Max(2, bottom - h);
        var tip = new PointF(tailX, bottom + 13);

        var pop = (float)Math.Clamp(tt / 0.25, 0, 1);
        var scale = 0.4f + 0.6f * EaseOutBack(pop);
        var saved = g.Save();
        g.TranslateTransform(tip.X, tip.Y);
        g.ScaleTransform(scale, scale);
        g.TranslateTransform(-tip.X, -tip.Y);

        var a = (int)(255 * alpha);
        using var path = BubblePath(x, y, w, h, tailX, bottom + 13);
        using var fill = new SolidBrush(Color.FromArgb(a, Cream));
        using var outline = new Pen(Color.FromArgb(a, Ink), 2.4f) { LineJoin = LineJoin.Round };
        g.FillPath(fill, path);
        g.DrawPath(outline, path);

        using var ink = new SolidBrush(Color.FromArgb(a, Ink));
        var left = shownChars;
        for (var i = 0; i < lines.Count && left > 0; i++)
        {
            var take = Math.Min(lines[i].Length, left);
            g.DrawString(lines[i][..take], BubbleFont, ink, x + 13, y + 9 + i * lineHeight, Typographic);
            left -= lines[i].Length + 1;
        }

        if (asking && tt >= endTyping)
        {
            // Two big buttons and a countdown line that shrinks. Doing nothing counts as "back to work".
            var rowY = y + 9 + lines.Count * lineHeight + 8;
            var buttonWidth = (w - 26 - 8) / 2;
            yesRect = new RectangleF(x + 13, rowY, buttonWidth, 24);
            noRect = new RectangleF(x + 13 + buttonWidth + 8, rowY, buttonWidth, 24);
            Button(g, yesRect, "It's for work", filled: true, a);
            Button(g, noRect, "Back to work", filled: false, a);

            var left01 = (float)Math.Clamp(1 - (now - askStart) / AskSeconds, 0, 1);
            var barY = rowY + 24 + 9;
            using var barBack = new Pen(Color.FromArgb((int)(60 * alpha), Ink), 3f) { StartCap = LineCap.Round, EndCap = LineCap.Round };
            using var bar = new Pen(Color.FromArgb(a, Sun), 3f) { StartCap = LineCap.Round, EndCap = LineCap.Round };
            g.DrawLine(barBack, x + 15, barY, x + w - 15, barY);
            if (left01 > 0.02f) g.DrawLine(bar, x + 15, barY, x + 15 + (w - 30) * left01, barY);
        }
        else if (!asking)
        {
            yesRect = noRect = RectangleF.Empty;
        }
        g.Restore(saved);
    }

    private static void Button(Graphics g, RectangleF r, string label, bool filled, int alpha)
    {
        using var path = RoundRect(r.X, r.Y, r.Width, r.Height, 7);
        using var fill = new SolidBrush(Color.FromArgb(alpha, filled ? Sun : Cream));
        using var edge = new Pen(Color.FromArgb(alpha, Ink), 2f) { LineJoin = LineJoin.Round };
        g.FillPath(fill, path);
        g.DrawPath(edge, path);
        using var ink = new SolidBrush(Color.FromArgb(alpha, Ink));
        using var centered = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
        g.DrawString(label, ButtonFont, ink, r, centered);
    }

    private static List<string> Wrap(Graphics g, string sentence, float maxWidth)
    {
        var result = new List<string>();
        var line = "";
        foreach (var word in sentence.Split(' '))
        {
            var trial = line.Length == 0 ? word : line + " " + word;
            if (line.Length > 0 && g.MeasureString(trial, BubbleFont, int.MaxValue, Typographic).Width > maxWidth)
            {
                result.Add(line);
                line = word;
            }
            else line = trial;
        }
        if (line.Length > 0) result.Add(line);
        return result;
    }

    /// <summary>A rounded box with a little tail pointing down at the brain.</summary>
    private static GraphicsPath BubblePath(float x, float y, float w, float h, float tailX, float tipY)
    {
        const float r = 12;
        var p = new GraphicsPath();
        p.AddArc(x, y, r * 2, r * 2, 180, 90);
        p.AddArc(x + w - r * 2, y, r * 2, r * 2, 270, 90);
        p.AddArc(x + w - r * 2, y + h - r * 2, r * 2, r * 2, 0, 90);
        p.AddLine(tailX + 9, y + h, tailX + 1, tipY);
        p.AddLine(tailX + 1, tipY, tailX - 9, y + h);
        p.AddArc(x, y + h - r * 2, r * 2, r * 2, 90, 90);
        p.CloseFigure();
        return p;
    }

    // ---- small shapes and easing ---------------------------------------------------------

    private static float EaseOutBack(float t)
    {
        const float c1 = 1.70158f, c3 = c1 + 1;
        var u = t - 1;
        return 1 + c3 * u * u * u + c1 * u * u;
    }

    private static GraphicsPath Star(float x, float y, float r)
    {
        var pts = new PointF[8];
        for (var i = 0; i < 8; i++)
        {
            var a = Math.PI / 4 * i - Math.PI / 2;
            var rr = i % 2 == 0 ? r : r * 0.28;
            pts[i] = new PointF(x + (float)(rr * Math.Cos(a)), y + (float)(rr * Math.Sin(a)));
        }
        var path = new GraphicsPath();
        path.AddPolygon(pts);
        return path;
    }

    private static GraphicsPath RoundRect(float x, float y, float w, float h, float r)
    {
        var p = new GraphicsPath();
        p.AddArc(x, y, r * 2, r * 2, 180, 90);
        p.AddArc(x + w - r * 2, y, r * 2, r * 2, 270, 90);
        p.AddArc(x + w - r * 2, y + h - r * 2, r * 2, r * 2, 0, 90);
        p.AddArc(x, y + h - r * 2, r * 2, r * 2, 90, 90);
        p.CloseFigure();
        return p;
    }

    private static GraphicsPath HeartPath(float cx, float cy, float size)
    {
        var p = new GraphicsPath();
        p.AddBezier(cx, cy + size, cx - size * 1.3f, cy + size * 0.1f, cx - size * 0.7f, cy - size * 0.9f, cx, cy - size * 0.35f);
        p.AddBezier(cx, cy - size * 0.35f, cx + size * 0.7f, cy - size * 0.9f, cx + size * 1.3f, cy + size * 0.1f, cx, cy + size);
        p.CloseFigure();
        return p;
    }
}

/// <summary>Writes pictures and frame sequences of the buddy to disk, to check the look without waiting for a real session.</summary>
public static class BuddyPictures
{
    private static readonly (string Name, BuddyMood Mood, string? App, int Nudges)[] Cases =
    {
        ("fresh", BuddyMood.Fresh, null, 1),
        ("sleepy", BuddyMood.Sleepy, null, 1),
        ("excited", BuddyMood.Excited, null, 1),
        ("question", BuddyMood.Droopy, "YouTube", 1),
        ("reassure", BuddyMood.Droopy, "YouTube", 2),
        ("cry", BuddyMood.Crying, "YouTube", 3),
    };

    public const int FramesPerSecond = 20;
    public const double Seconds = 5;

    public static void Write(string dir)
    {
        Directory.CreateDirectory(dir);
        foreach (var (name, mood, app, nudges) in Cases)
        {
            var scene = new BuddyScene();
            scene.Set(mood, BuddyWords.For(mood, app, nudges), 0);
            Save(scene, Path.Combine(dir, $"buddy-{name}.png"), 2.2);

            var frames = Path.Combine(dir, "frames", name);
            Directory.CreateDirectory(frames);
            for (var f = 0; f < FramesPerSecond * Seconds; f++)
                Save(scene, Path.Combine(frames, $"f{f:D4}.png"), f / (double)FramesPerSecond, quiet: true);
            Console.WriteLine(frames);
        }

        // One buddy through a whole session, to check that each mood blends into the next.
        var steps = new (double At, BuddyMood Mood, string? App, int Nudges)[]
        {
            (0, BuddyMood.Fresh, null, 0), (4, BuddyMood.Sleepy, null, 0), (8, BuddyMood.Excited, null, 0),
            (12, BuddyMood.Droopy, "YouTube", 1), (16, BuddyMood.Excited, null, 1), (19, BuddyMood.Crying, "YouTube", 3),
            (23, BuddyMood.Excited, null, 3),
        };
        var journey = new BuddyScene();
        var journeyDir = Path.Combine(dir, "frames", "journey");
        Directory.CreateDirectory(journeyDir);
        var next = 0;
        for (var f = 0; f < FramesPerSecond * 27; f++)
        {
            var now = f / (double)FramesPerSecond;
            while (next < steps.Length && steps[next].At <= now)
            {
                var (_, mood, app, nudges) = steps[next++];
                journey.Set(mood, BuddyWords.For(mood, app, nudges), now);
            }
            Save(journey, Path.Combine(journeyDir, $"f{f:D4}.png"), now, quiet: true);
        }
        Console.WriteLine(journeyDir);
    }

    private static void Save(BuddyScene scene, string path, double now, bool quiet = false)
    {
        using var bitmap = new Bitmap(BuddyScene.Width, BuddyScene.Height, PixelFormat.Format32bppPArgb);
        using (var g = Graphics.FromImage(bitmap))
        {
            g.Clear(Color.Transparent);
            scene.Render(g, now);
        }
        bitmap.Save(path, ImageFormat.Png);
        if (!quiet) Console.WriteLine(path);
    }
}
