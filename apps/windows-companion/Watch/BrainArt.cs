using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

namespace LockIn.Companion.Watch;

/// <summary>
/// How the brain is moved and posed for one animation frame. Offsets are in drawing units
/// (364 by 300). The pivot for squash and tilt is the bottom of the brain, so a hop looks like a hop.
/// </summary>
public struct BrainPose
{
    public float Dx, Dy, Tilt, Sx, Sy;
    /// <summary>0 to 1 = mouth open while talking. Below 0 = not talking (the stage's own mouth).</summary>
    public float MouthOpen;
    public float SpiralTurn, TearPhase, Blink, Time;
    /// <summary>
    /// Mood change in progress: the stage it comes from, and how far it is (0 = all old, 1 = all new).
    /// Colors and droop blend; marks and faces fade across. No snap from one look to the next.
    /// </summary>
    public int FromStage;
    public float Blend;
    /// <summary>Star eyes (the excited buddy) on the old face and on the new face. Only stage 0 has them.</summary>
    public bool FromStarEyes, StarEyes;
    /// <summary>Where the pupils look, in drawing units (about -12 to 12). 0,0 = at you.</summary>
    public float LookX, LookY;
    /// <summary>0 to 1: determined eyebrows ("let's go"), only on the fresh face.</summary>
    public float Brows;
    /// <summary>0 to 1: a big open smile, only on the fresh face (cheering).</summary>
    public float Grin;

    public static BrainPose Rest => new() { Sx = 1, Sy = 1, MouthOpen = -1, FromStage = -1, Blend = 1 };
}

/// <summary>
/// The app's brain (apps/ios/BrainArt/BrainDrawing.swift), drawn with the same shapes, colors
/// and faces. Still picture only (time 0): no wobble, no animation. Drawing space is 364 by 300,
/// fitted into the area it is given. Keep this in step with the Swift file.
/// </summary>
public static class BrainArt
{
    private static Color Hex(uint v) => Color.FromArgb((int)(0xFF000000u | v));

    private static readonly Color Cream = Hex(0xF2ECE1);
    private static readonly Color Ink = Hex(0x40162A);
    /// <summary>The body outline: a softer plum than the eyes (the 2026-11-13 plush look).</summary>
    private static readonly Color Edge = Hex(0x6B4561);
    private static readonly Color Gold = Hex(0xFFC440);
    private static readonly Color Blush = Hex(0xF08DB0);
    private static readonly Color Tongue = Hex(0xFF6E8C);
    private static readonly Color Tear = Hex(0x7FD8FF);
    private static readonly Color Stink = Hex(0x8C9670);

    /// <summary>Body, bottom shade and fold color for each stage, 0 fresh to 5 rotten.</summary>
    private static readonly (uint Body, uint Shade, uint Fold)[] Palette =
    {
        (0xF9BAD2, 0xF1A2C1, 0xE597B8), (0xF7B4C8, 0xEC9DB6, 0xDF8FAA), (0xF0A0AA, 0xDA7888, 0xCE6C7C),
        (0xD6A696, 0xBC8476, 0xB2786C), (0xBAAA82, 0xA08E68, 0x968260), (0x989E76, 0x7E845E, 0x747A58),
    };

    public static void Draw(Graphics g, int stage, RectangleF area, BrainPose pose = default)
    {
        var p = pose.Sx == 0 ? BrainPose.Rest : pose;
        stage = Math.Clamp(stage, 0, 5);
        var from = p.FromStage < 0 ? stage : Math.Clamp(p.FromStage, 0, 5);
        var w = from == stage ? 1f : Math.Clamp(p.Blend, 0f, 1f);
        var bodyColor = Mix(Hex(Palette[from].Body), Hex(Palette[stage].Body), w);
        var shadeColor = Mix(Hex(Palette[from].Shade), Hex(Palette[stage].Shade), w);
        var foldColor = Mix(Hex(Palette[from].Fold), Hex(Palette[stage].Fold), w);
        // How much of a mark to show: 1 if both moods have it, 0 if neither, in between while it fades.
        float Has(Func<int, bool> test) => Lerp(test(from) ? 1 : 0, test(stage) ? 1 : 0, w);

        g.SmoothingMode = SmoothingMode.AntiAlias;
        var s = Math.Min(area.Width / 364f, area.Height / 300f);
        var ox = area.Left + (area.Width - 364 * s) / 2;
        var oy = area.Top + (area.Height - 300 * s) / 2;
        using var outer = new Matrix(s, 0, 0, s, ox, oy);

        // Sparkles while it is still doing well (they twinkle; at time 0 they sit at these sizes).
        var sparkle = Has(st => st <= 1);
        if (sparkle > 0)
        {
            var sparkles = new[] { (X: 56f, Y: 50f, R: 16f), (X: 320f, Y: 66f, R: 11f), (X: 322f, Y: 236f, R: 9f) };
            using var gold = new SolidBrush(Fade(Gold, sparkle));
            for (var i = 0; i < sparkles.Length; i++)
            {
                var k = 1 + 0.25 * Math.Sin(2.0 * i + p.Time * 3.5);
                using var star = Star(sparkles[i].X, sparkles[i].Y, (float)(sparkles[i].R * k));
                star.Transform(outer);
                g.FillPath(gold, star);
            }
        }

        // Droop and tilt for the worse stages. The brain is also drawn 1.08 larger.
        static float DroopOf(int st) => st switch { 3 => 6f, 4 => 10f, 5 => 18f, _ => 0f };
        var droop = Lerp(DroopOf(from), DroopOf(stage), w);
        using var brain = BrainMatrix(s, ox, oy, droop, droop * 0.4, p);
        var k2 = s * 1.08f; // width of every line, in canvas pixels

        using var outlinePath = Outline();
        outlinePath.Transform(brain);
        using var foldsPath = Folds();
        foldsPath.Transform(brain);

        // Body: cream sticker border, bottom shade, pink body lifted up-left so the shade shows,
        // a shine while it is fresh, folds, then the dark outline.
        using var creamPen = new Pen(Cream, 18 * k2) { LineJoin = LineJoin.Round };
        using var shadeBrush = new SolidBrush(shadeColor);
        using var bodyBrush = new SolidBrush(bodyColor);
        g.DrawPath(creamPen, outlinePath);
        g.FillPath(shadeBrush, outlinePath);

        var saved = g.Save();
        g.SetClip(outlinePath, CombineMode.Replace);
        using (var shifted = Outline())
        {
            shifted.Transform(new Matrix(1, 0, 0, 1, -3, -40));
            shifted.Transform(brain);
            g.FillPath(bodyBrush, shifted);
        }
        static float ShineOf(int st) => st <= 2 ? (200 - st * 50) / 255f : 0f;
        var alpha = Lerp(ShineOf(from), ShineOf(stage), w);
        if (alpha > 0)
        {
            // Short glossy marks on the top bumps, like a soft plush toy catching the light.
            using var shinePath = new GraphicsPath();
            AddQuad(shinePath, new PointF(86, 120), new PointF(88, 104), new PointF(100, 94));
            shinePath.StartFigure();
            AddQuad(shinePath, new PointF(134, 76), new PointF(144, 70), new PointF(156, 70));
            shinePath.StartFigure();
            AddQuad(shinePath, new PointF(208, 70), new PointF(220, 70), new PointF(230, 76));
            shinePath.StartFigure();
            AddQuad(shinePath, new PointF(266, 94), new PointF(278, 102), new PointF(280, 118));
            shinePath.Transform(brain);
            using var shinePen = new Pen(Color.FromArgb((int)(alpha * 255), 255, 255, 255), 9 * k2)
            { StartCap = LineCap.Round, EndCap = LineCap.Round };
            g.DrawPath(shinePen, shinePath);
        }
        g.Restore(saved);

        using var foldPen = new Pen(foldColor, 4.5f * k2) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round };
        var foldClip = g.Save();
        g.SetClip(outlinePath, CombineMode.Replace);
        g.DrawPath(foldPen, foldsPath);
        g.Restore(foldClip);

        // Damage that stays. Between two moods each mark fades in or out.
        var bandage = Has(st => st >= 2);
        if (bandage > 0) DrawBandage(g, brain, k2, bandage);
        var crackA = Has(st => st >= 3);
        if (crackA > 0)
        {
            using var crack = new GraphicsPath();
            crack.AddLines(new[] { new PointF(236, 60), new PointF(226, 80), new PointF(240, 88), new PointF(230, 110) });
            crack.Transform(brain);
            using var crackPen = new Pen(Fade(Ink, crackA), 5 * k2) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round };
            g.DrawPath(crackPen, crack);
        }

        var crackB = Has(st => st >= 4);
        if (crackB > 0)
        {
            using var crack2 = new GraphicsPath();
            crack2.AddLines(new[] { new PointF(84, 128), new PointF(100, 136), new PointF(92, 150), new PointF(108, 158) });
            crack2.Transform(brain);
            using var crack2Pen = new Pen(Fade(Ink, crackB), 5 * k2) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round };
            g.DrawPath(crack2Pen, crack2);
        }
        var rot = Has(st => st == 5);
        if (rot > 0)
        {
            // Stink wisps rising, and two flies circling (frozen at time 0).

            using var stinkPen = new Pen(Fade(Stink, rot), 4 * k2) { StartCap = LineCap.Round, EndCap = LineCap.Round };
            for (var i = 0; i < 3; i++)
            {
                var x = 130f + i * 50;
                var y0 = 34f - (i * 10f) % 30;
                using var wisp = new GraphicsPath();
                AddQuad(wisp, new PointF(x, y0), new PointF(x - 8, y0 - 10), new PointF(x, y0 - 20));
                AddQuad(wisp, new PointF(x, y0 - 20), new PointF(x + 8, y0 - 30), new PointF(x, y0 - 40));
                wisp.Transform(brain);
                g.DrawPath(stinkPen, wisp);
            }
            using var creamBrush = new SolidBrush(Fade(Cream, rot));
            using var faintCream = new SolidBrush(Fade(Color.FromArgb(128, Cream), rot));
            for (var i = 0; i < 2; i++)
            {
                var a = i * 3.0;
                var fx = (float)(182 + Math.Cos(a) * 140);
                var fy = (float)(120 + Math.Sin(a * 1.3) * 60);
                using var fly = Ellipse(fx, fy, 4, 4);
                fly.Transform(brain);
                g.FillPath(creamBrush, fly);
                using var wing = new GraphicsPath();
                wing.AddEllipse(fx - 9, fy - 8, 10, 6);
                wing.Transform(brain);
                g.FillPath(faintCream, wing);
            }
        }

        using (var inkPen = new Pen(Edge, 6 * k2) { LineJoin = LineJoin.Round })
            g.DrawPath(inkPen, outlinePath);

        // The face. Between two moods both faces are drawn: the old one fades out as the new one fades in.
        if (w >= 0.999f) DrawFace(g, stage, brain, k2, bodyColor, p, p.StarEyes);
        else
        {
            FadedLayer(g, 1 - w, lg => DrawFace(lg, from, brain, k2, bodyColor, p, p.FromStarEyes));
            FadedLayer(g, w, lg => DrawFace(lg, stage, brain, k2, bodyColor, p, p.StarEyes));
        }
    }

    private static float Lerp(float a, float b, float t) => a + (b - a) * t;

    private static Color Mix(Color a, Color b, float t) => Color.FromArgb(
        (int)Math.Round(Lerp(a.A, b.A, t)), (int)Math.Round(Lerp(a.R, b.R, t)),
        (int)Math.Round(Lerp(a.G, b.G, t)), (int)Math.Round(Lerp(a.B, b.B, t)));

    private static Color Fade(Color c, float amount) => Color.FromArgb((int)(c.A * Math.Clamp(amount, 0f, 1f)), c);

    /// <summary>Draws into a see-through layer, then lays it on the picture at the given strength.</summary>
    private static void FadedLayer(Graphics g, float alpha, Action<Graphics> draw)
    {
        if (alpha <= 0.01f) return;
        var bounds = g.VisibleClipBounds;
        var width = (int)Math.Ceiling(bounds.Right);
        var height = (int)Math.Ceiling(bounds.Bottom);
        using var layer = new Bitmap(width, height, PixelFormat.Format32bppPArgb);
        using (var lg = Graphics.FromImage(layer))
        {
            lg.SmoothingMode = SmoothingMode.AntiAlias;
            draw(lg);
        }
        using var attrs = new ImageAttributes();
        attrs.SetColorMatrix(new ColorMatrix { Matrix33 = alpha });
        g.DrawImage(layer, new Rectangle(0, 0, width, height), 0, 0, width, height, GraphicsUnit.Pixel, attrs);
    }

    private static void DrawFace(Graphics g, int stage, Matrix brain, float k2, Color bodyColor, BrainPose p, bool starEyes)
    {
        // Eyes: big and set low, like a baby face.
        const float ey = 168;
        using var inkBrush = new SolidBrush(Ink);
        using var whiteBrush = new SolidBrush(Color.White);
        using var roundPen = new Pen(Ink, 4.5f * k2) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round };
        foreach (var (x, i) in new[] { (140f, 0), (224f, 1) })
        {
            switch (stage)
            {
                case 0:
                {
                    if (starEyes)
                    {
                        // Excited: gold star eyes with a dark edge and a tiny shine. Blinks squash them too.
                        using var starEye = FivePointStar(x, ey, 19, 1 - 0.9f * p.Blink);
                        starEye.Transform(brain);
                        using var goldEye = new SolidBrush(Gold);
                        g.FillPath(goldEye, starEye);
                        using var starEdge = new Pen(Ink, 3.5f * k2) { LineJoin = LineJoin.Round };
                        g.DrawPath(starEdge, starEye);
                        if (p.Blink < 0.5f)
                        {
                            using var shine = Ellipse(x - 4, ey - 5, 3.5f, 3.5f);
                            shine.Transform(brain);
                            g.FillPath(whiteBrush, shine);
                        }
                        break;
                    }
                    // A blink squashes the eye flat and hides the sparkle in it. LookX/LookY turn the gaze.
                    var px = x + p.LookX;
                    var py = ey + p.LookY;
                    using var pupil = Ellipse(px, py, 13, 15 * (1 - 0.9f * p.Blink));
                    pupil.Transform(brain);
                    g.FillPath(inkBrush, pupil);
                    if (p.Blink < 0.5f)
                    {
                        using var hi1 = Ellipse(px - 4, py - 6, 5.5f, 5.5f);
                        hi1.Transform(brain);
                        g.FillPath(whiteBrush, hi1);
                        using var hi2 = Ellipse(px + 5, py + 7, 2.6f, 2.6f);
                        hi2.Transform(brain);
                        g.FillPath(whiteBrush, hi2);
                    }
                    if (p.Brows > 0.01f)
                    {
                        // Short brows tilted toward the middle: keen, not angry.
                        var lift = 30 - 4 * p.Brows;
                        using var brow = new GraphicsPath();
                        if (i == 0) brow.AddLine(x - 15, ey - lift - 6 * p.Brows, x + 12, ey - lift + 2);
                        else brow.AddLine(x - 12, ey - lift + 2, x + 15, ey - lift - 6 * p.Brows);
                        brow.Transform(brain);
                        using var browPen = new Pen(Color.FromArgb((int)(255 * Math.Clamp(p.Brows, 0, 1)), Ink), 5.5f * k2)
                            { StartCap = LineCap.Round, EndCap = LineCap.Round };
                        g.DrawPath(browPen, brow);
                    }
                    break;
                }
                case 1:
                {
                    // Sleepy: the lid covers the top half.
                    using var pupil = Ellipse(x, ey + 3, 14, 14);
                    pupil.Transform(brain);
                    g.FillPath(inkBrush, pupil);
                    using var hi = Ellipse(x - 4, ey + 2, 4, 4);
                    hi.Transform(brain);
                    g.FillPath(whiteBrush, hi);
                    using var lid = new GraphicsPath();
                    lid.AddRectangle(new RectangleF(x - 17, ey - 16, 34, 15));
                    lid.Transform(brain);
                    using var bodyLid = new SolidBrush(bodyColor);
                    g.FillPath(bodyLid, lid);
                    using var lidLine = new GraphicsPath();
                    lidLine.AddLine(x - 15, ey - 1, x + 15, ey - 1);
                    lidLine.Transform(brain);
                    g.DrawPath(roundPen, lidLine);
                    break;
                }
                case 2:
                {
                    // A spiral, the eyes going round.
                    using var spiral = new GraphicsPath();
                    var pts = new PointF[61];
                    for (var kk = 0; kk <= 60; kk++)
                    {
                        var f = kk / 60.0;
                        var ang = f * 5 * Math.PI + i + p.SpiralTurn;
                        var rr = 1 + f * 12;
                        pts[kk] = new PointF((float)(x + Math.Cos(ang) * rr), (float)(ey + Math.Sin(ang) * rr));
                    }
                    spiral.AddLines(pts);
                    spiral.Transform(brain);
                    using var spiralPen = new Pen(Ink, 4 * k2) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round };
                    g.DrawPath(spiralPen, spiral);
                    break;
                }
                case 4:
                {
                    // Shut and crying: a shut arc, and a tear.
                    using var shut = new GraphicsPath();
                    AddQuad(shut, new PointF(x - 13, ey + 4), new PointF(x, ey - 10), new PointF(x + 13, ey + 4));
                    shut.Transform(brain);
                    using var shutPen = new Pen(Ink, 5 * k2) { StartCap = LineCap.Round, EndCap = LineCap.Round };
                    g.DrawPath(shutPen, shut);
                    var side = i == 1 ? 1f : -1f;
                    using var tear = new GraphicsPath();
                    AddQuad(tear, new PointF(x + 8 * side, ey + 10), new PointF(x + 12 * side, ey + 26), new PointF(x + 8 * side, ey + 40));
                    tear.Transform(brain);
                    using var tearPen = new Pen(Color.FromArgb(230, Tear), 7 * k2) { StartCap = LineCap.Round, EndCap = LineCap.Round };
                    g.DrawPath(tearPen, tear);
                    // A drop that keeps falling from each eye.
                    var phase = (p.TearPhase + i * 0.5f) % 1f;
                    using var fall = Ellipse(x + (8 + 4 * phase) * side, ey + 18 + 52 * phase, 4.5f * (1 - 0.4f * phase), 6.5f * (1 - 0.4f * phase));
                    fall.Transform(brain);
                    using var fallBrush = new SolidBrush(Color.FromArgb((int)(220 * (1 - phase)), Tear));
                    g.FillPath(fallBrush, fall);
                    break;
                }
                case 5:
                {
                    // Dead eyes: an X each.
                    using var xs = new GraphicsPath();
                    xs.AddLine(x - 11, ey - 11, x + 11, ey + 11);
                    xs.AddLine(x + 11, ey - 11, x - 11, ey + 11);
                    xs.Transform(brain);
                    using var xPen = new Pen(Ink, 6 * k2) { StartCap = LineCap.Round, EndCap = LineCap.Round };
                    g.DrawPath(xPen, xs);
                    break;
                }
                case 3:
                {
                    // Drooping, half shut, a little uneven.
                    using var pupil = Ellipse(x, ey + 5, 13, 12 * (1 - 0.9f * p.Blink));
                    pupil.Transform(brain);
                    g.FillPath(inkBrush, pupil);
                    using var lid = new GraphicsPath();
                    lid.AddRectangle(new RectangleF(x - 16, ey - 12, 32, 16));
                    lid.Transform(brain);
                    using var bodyLid = new SolidBrush(bodyColor);
                    g.FillPath(bodyLid, lid);
                    var lidY1 = ey + 3 + (i == 1 ? 0 : 3);
                    var lidY2 = ey + 3 + (i == 1 ? 3 : 0);
                    using var lidLine = new GraphicsPath();
                    lidLine.AddLine(x - 14, lidY1, x + 14, lidY2);
                    lidLine.Transform(brain);
                    g.DrawPath(roundPen, lidLine);
                    break;
                }
            }
        }

        if (stage <= 2)
        {
            using var blush = new SolidBrush(Blush);
            foreach (var bx in new[] { 110f, 254f })
            {
                using var cheek = Ellipse(bx, 196, 16, 8.5f);
                cheek.Transform(brain);
                g.FillPath(blush, cheek);
            }
        }

        if (stage == 1)
        {
            // A tear drop on the brow.
            using var drop = new GraphicsPath();
            AddQuad(drop, new PointF(266, 74), new PointF(276, 94), new PointF(266, 98));
            AddQuad(drop, new PointF(266, 98), new PointF(256, 94), new PointF(266, 74));
            drop.Transform(brain);
            using var dropBrush = new SolidBrush(Tear);
            g.FillPath(dropBrush, drop);
            using var dropPen = new Pen(Ink, 3 * k2) { LineJoin = LineJoin.Round };
            g.DrawPath(dropPen, drop);
        }

        // Mouth. While the buddy speaks it opens and closes (not when crying or rotten: their mouths are the point).
        const float mx = 182, my = 196;
        if (p.Grin > 0.01f && stage == 0)
        {
            // A big open "D" smile with a tongue: the coach cheering.
            var grin = Math.Clamp(p.Grin, 0f, 1f);
            var w = 15 + 11 * grin;
            var depth = 10 + 20 * grin;
            using var smile = new GraphicsPath();
            smile.AddLine(mx - w, my + 1, mx + w, my + 1);
            smile.AddBezier(mx + w, my + 1, mx + w * 0.9f, my + 1 + depth * 1.3f, mx - w * 0.9f, my + 1 + depth * 1.3f, mx - w, my + 1);
            smile.CloseFigure();
            smile.Transform(brain);
            g.FillPath(inkBrush, smile);
            using var tongue = Ellipse(mx + 2, my + 1 + depth * 0.78f, w * 0.52f, depth * 0.24f);
            tongue.Transform(brain);
            using var tongueBrush = new SolidBrush(Tongue);
            g.FillPath(tongueBrush, tongue);
        }
        else if (p.MouthOpen >= 0 && stage < 4)
        {
            var open = Math.Clamp(p.MouthOpen, 0f, 1f);
            using var talk = Ellipse(mx, my + 6, 9 + 2 * open, 2.5f + 10 * open);
            talk.Transform(brain);
            g.FillPath(inkBrush, talk);
            if (stage == 0 && open > 0.45f)
            {
                using var tongueTalk = Ellipse(mx, my + 6 + 5 * open, 6, 3.5f * open);
                tongueTalk.Transform(brain);
                using var tongueTalkBrush = new SolidBrush(Tongue);
                g.FillPath(tongueTalkBrush, tongueTalk);
            }
        }
        else switch (stage)
        {
            case 0:
            {
                using var mouth = new GraphicsPath();
                AddQuad(mouth, new PointF(mx - 11, my), new PointF(mx, my + 20), new PointF(mx + 11, my));
                mouth.CloseFigure();
                mouth.Transform(brain);
                g.FillPath(inkBrush, mouth);
                using var mouthPen = new Pen(Ink, 4 * k2) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round };
                g.DrawPath(mouthPen, mouth);
                using var tongue = Ellipse(mx, my + 8, 5.5f, 3.5f);
                tongue.Transform(brain);
                using var tongueBrush = new SolidBrush(Tongue);
                g.FillPath(tongueBrush, tongue);
                break;
            }
            case 1:
            {
                using var m = new GraphicsPath();
                AddQuad(m, new PointF(mx - 14, my + 4), new PointF(mx - 7, my - 2), new PointF(mx, my + 4));
                AddQuad(m, new PointF(mx, my + 4), new PointF(mx + 7, my + 10), new PointF(mx + 14, my + 4));
                m.Transform(brain);
                g.DrawPath(roundPen, m);
                break;
            }
            case 2:
            {
                using var o = Ellipse(mx, my + 6, 9, 12);
                o.Transform(brain);
                g.FillPath(inkBrush, o);
                break;
            }
            case 3:
            {
                using var line = new GraphicsPath();
                line.AddLine(mx - 16, my + 6, mx + 16, my + 6);
                line.Transform(brain);
                g.DrawPath(roundPen, line);
                break;
            }
            case 4:
            {
                using var m = new GraphicsPath();
                AddQuad(m, new PointF(mx - 18, my + 16), new PointF(mx, my - 8), new PointF(mx + 18, my + 16));
                m.CloseFigure();
                m.Transform(brain);
                g.FillPath(inkBrush, m);
                break;
            }
            case 5:
            {
                using var line = new GraphicsPath();
                line.AddLine(mx - 18, my + 4, mx + 18, my + 4);
                line.Transform(brain);
                g.DrawPath(roundPen, line);
                using var tongueOut = new GraphicsPath();
                tongueOut.AddLine(mx + 2, my + 4, mx + 2, my + 18);
                AddQuad(tongueOut, new PointF(mx + 2, my + 18), new PointF(mx + 11, my + 32), new PointF(mx + 20, my + 18));
                tongueOut.AddLine(mx + 20, my + 18, mx + 20, my + 4);
                tongueOut.CloseFigure();
                tongueOut.Transform(brain);
                using var tongueBrush = new SolidBrush(Tongue);
                g.FillPath(tongueBrush, tongueOut);
                using var tonguePen = new Pen(Ink, 3 * k2) { LineJoin = LineJoin.Round };
                g.DrawPath(tonguePen, tongueOut);
                break;
            }
        }
    }

    /// <summary>The brain's droop and tilt, plus the 1.08 scale, folded into one matrix.</summary>
    private static Matrix BrainMatrix(float s, float ox, float oy, float droop, double degrees, BrainPose pose)
    {
        var r = degrees * Math.PI / 180;
        var cos = Math.Cos(r);
        var sin = Math.Sin(r);
        PointF Map(double x, double y)
        {
            x = (x - 182) * 1.08;
            y = (y - 150) * 1.08 + 2;
            var rx = x * cos - y * sin;
            var ry = x * sin + y * cos;
            return new PointF((float)(ox + s * (rx + 182)), (float)(oy + s * (ry + 150 + droop)));
        }
        var p0 = Map(0, 0);
        var px = Map(1, 0);
        var py = Map(0, 1);
        var m = new Matrix(px.X - p0.X, px.Y - p0.Y, py.X - p0.X, py.Y - p0.Y, p0.X, p0.Y);

        // The pose: squash and tilt about the bottom of the brain, then move.
        var pivotX = ox + s * 182;
        var pivotY = oy + s * (270 + droop);
        m.Translate(-pivotX, -pivotY, MatrixOrder.Append);
        m.Scale(pose.Sx, pose.Sy, MatrixOrder.Append);
        m.Rotate(pose.Tilt, MatrixOrder.Append);
        m.Translate(pivotX + pose.Dx * s, pivotY + pose.Dy * s, MatrixOrder.Append);
        return m;
    }

    /// <summary>Quadratic curve from a to b with control c, as the cubic GDI+ draws.</summary>
    private static void AddQuad(GraphicsPath p, PointF a, PointF c, PointF b)
    {
        var c1 = new PointF(a.X + 2f / 3 * (c.X - a.X), a.Y + 2f / 3 * (c.Y - a.Y));
        var c2 = new PointF(b.X + 2f / 3 * (c.X - b.X), b.Y + 2f / 3 * (c.Y - b.Y));
        p.AddBezier(a, c1, c2, b);
    }

    /// <summary>16 even points on a squashed circle; each stretch between two bulges outward.</summary>
    private static GraphicsPath Outline()
    {
        // Wider than tall, a smooth round dome on top and puffy bumps around the sides and bottom:
        // a squishy plush brain.
        const int n = 15;
        var pts = new PointF[n];
        var bumps = new float[n];
        for (var i = 0; i < n; i++)
        {
            var a = 2 * Math.PI * i / n - Math.PI / 2;
            var up = Math.Sin(a) < 0;
            pts[i] = new PointF(
                (float)Math.Round(182 + 120 * Math.Cos(a), MidpointRounding.AwayFromZero),
                (float)Math.Round(160 + (up ? 112 : 94) * Math.Sin(a), MidpointRounding.AwayFromZero));
            // How far the stretch from this point to the next bulges: low over the dome, full lower down.
            var mid = a + Math.PI / n;
            var top = Math.Max(0, -Math.Sin(mid));
            bumps[i] = (float)(20 - 13 * top * top);
        }
        var p = new GraphicsPath();
        for (var i = 0; i < n; i++)
        {
            var a = pts[i];
            var b = pts[(i + 1) % n];
            var dx = b.X - a.X;
            var dy = b.Y - a.Y;
            var len = Math.Max((float)Math.Sqrt(dx * dx + dy * dy), 1);
            var ctrl = new PointF((a.X + b.X) / 2 + dy / len * bumps[i], (a.Y + b.Y) / 2 - dx / len * bumps[i]);
            AddQuad(p, a, ctrl, b);
        }
        p.CloseFigure();
        return p;
    }

    private static GraphicsPath Folds()
    {
        // Soft curls (like a "6" lying down) on each side, mirrored, and a split down the top middle.
        var p = new GraphicsPath();
        void Curl(float cx, float cy, float r, bool right, float start)
        {
            // A three-quarter loop with a tail running off it.
            p.StartFigure();
            var sweep = right ? -270f : 270f;
            p.AddArc(cx - r, cy - r, r * 2, r * 2, start, sweep);
            var end = (start + sweep) * Math.PI / 180;
            var ex = cx + r * (float)Math.Cos(end);
            var ey = cy + r * (float)Math.Sin(end);
            var tail = right ? -1f : 1f;
            AddQuad(p, new PointF(ex, ey), new PointF(ex + tail * r * 0.2f, ey + r * 0.9f), new PointF(ex - tail * r * 0.5f, ey + r * 1.5f));
        }
        void Pair(float x, float y, float r, float start)
        {
            Curl(x, y, r, false, start);
            Curl(364 - x, y, r, true, 180 - start);
        }
        Pair(142, 78, 19, 180);   // top
        Pair(92, 112, 15, 200);   // upper sides
        Pair(140, 136, 13, 190);  // inner
        Pair(80, 168, 14, 210);   // lower sides
        Pair(96, 222, 13, 230);   // bottom sides
        p.StartFigure();
        p.AddBezier(182, 52, 176, 78, 188, 100, 182, 124);
        p.AddBezier(182, 124, 178, 136, 184, 146, 182, 152);
        p.StartFigure();
        p.AddLine(182, 244, 182, 262);
        return p;
    }

    private static GraphicsPath Ellipse(float x, float y, float rx, float ry)
    {
        var p = new GraphicsPath();
        p.AddEllipse(x - rx, y - ry, rx * 2, ry * 2);
        return p;
    }

    /// <summary>A plump five-point star, squashed up and down by <paramref name="squashY"/> (for blinks).</summary>
    private static GraphicsPath FivePointStar(float x, float y, float r, float squashY)
    {
        var pts = new PointF[10];
        for (var i = 0; i < 10; i++)
        {
            var a = Math.PI / 5 * i - Math.PI / 2;
            var rr = i % 2 == 0 ? r : r * 0.52;
            pts[i] = new PointF(x + (float)(rr * Math.Cos(a)), y + (float)(rr * Math.Sin(a) * squashY) + 1);
        }
        var p = new GraphicsPath();
        p.AddPolygon(pts);
        return p;
    }

    /// <summary>A four-point twinkle star.</summary>
    private static GraphicsPath Star(float x, float y, float r)
    {
        var pts = new PointF[8];
        for (var i = 0; i < 8; i++)
        {
            var a = Math.PI / 4 * i - Math.PI / 2;
            var rr = i % 2 == 0 ? r : r * 0.28;
            pts[i] = new PointF(x + (float)(rr * Math.Cos(a)), y + (float)(rr * Math.Sin(a)));
        }
        var p = new GraphicsPath();
        p.AddPolygon(pts);
        return p;
    }

    private static void DrawBandage(Graphics g, Matrix brain, float k, float amount = 1)
    {
        const float x = 98, y = 92, w = 58, h = 20, rad = 6;
        var tilt = new Matrix();
        tilt.RotateAt(-24, new PointF(x + w / 2, y + h / 2));

        using var rect = new GraphicsPath();
        rect.AddArc(x, y, rad * 2, rad * 2, 180, 90);
        rect.AddArc(x + w - rad * 2, y, rad * 2, rad * 2, 270, 90);
        rect.AddArc(x + w - rad * 2, y + h - rad * 2, rad * 2, rad * 2, 0, 90);
        rect.AddArc(x, y + h - rad * 2, rad * 2, rad * 2, 90, 90);
        rect.CloseFigure();
        rect.Transform(tilt);
        rect.Transform(brain);
        using (var cream = new SolidBrush(Fade(Cream, amount)))
            g.FillPath(cream, rect);
        using (var edge = new Pen(Fade(Ink, amount), 4 * k) { LineJoin = LineJoin.Round })
            g.DrawPath(edge, rect);

        using var stripes = new GraphicsPath();
        foreach (var sx in new[] { x + 22, x + 29, x + 36 })
            stripes.AddLine(sx, y + 5, sx, y + 15);
        stripes.Transform(tilt);
        stripes.Transform(brain);
        using var stripePen = new Pen(Fade(Ink, amount), 2.5f * k) { StartCap = LineCap.Round, EndCap = LineCap.Round };
        g.DrawPath(stripePen, stripes);
    }
}
