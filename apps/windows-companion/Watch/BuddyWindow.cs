using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace LockIn.Companion.Watch;

/// <summary>
/// The brain moods. Fresh to Rotten are the app's stages 0 to 5. Excited is the PC buddy's own:
/// the fresh brain with star eyes, for the end of a session that went well. Curious is also its own:
/// the fresh brain tilting its head, when it asks whether a window is for work.
/// </summary>
public enum BuddyMood { Fresh, Sleepy, Spiral, Droopy, Crying, Rotten, Excited, Curious }

/// <summary>
/// The desk buddy: the app's brain in the bottom-right corner of the screen, with a speech bubble.
/// It stays on top, has no border and no box behind it (only the brain and its bubble show), is not
/// in the taskbar, and never takes the keyboard focus. It runs on its own UI thread and draws about
/// 30 times a second while it talks, and slower while it only breathes. The drawing itself is in
/// <see cref="BuddyScene"/>.
/// </summary>
public sealed class BuddyWindow : Form
{
    private static readonly Lazy<BuddyWindow> lazy = new(Start);
    public static BuddyWindow Instance => lazy.Value;

    private static readonly Stopwatch Clock = Stopwatch.StartNew();
    private static double Now => Clock.Elapsed.TotalSeconds;

    private const int WsExLayered = 0x80000, WsExToolWindow = 0x80, WsExNoActivate = 0x08000000;
    private const int UlwAlpha = 2;
    private const int FastMs = 33, SlowMs = 90;

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    private struct Blend { public byte Op, Flags, Alpha, Format; }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UpdateLayeredWindow(IntPtr hwnd, IntPtr hdcDst, ref Point dst, ref Size size,
        IntPtr hdcSrc, ref Point src, int key, ref Blend blend, int flags);
    [DllImport("user32.dll")] private static extern IntPtr GetDC(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern int ReleaseDC(IntPtr hwnd, IntPtr dc);
    [DllImport("gdi32.dll")] private static extern IntPtr CreateCompatibleDC(IntPtr dc);
    [DllImport("gdi32.dll")] private static extern IntPtr SelectObject(IntPtr dc, IntPtr obj);
    [DllImport("gdi32.dll")] private static extern bool DeleteObject(IntPtr obj);
    [DllImport("gdi32.dll")] private static extern bool DeleteDC(IntPtr dc);

    private readonly BuddyScene scene = new();
    private readonly System.Windows.Forms.Timer frame = new() { Interval = FastMs };

    protected override CreateParams CreateParams
    {
        get
        {
            var cp = base.CreateParams;
            cp.ExStyle |= WsExLayered | WsExToolWindow | WsExNoActivate;
            return cp;
        }
    }

    protected override bool ShowWithoutActivation => true;

    /// <summary>Raised on the buddy's thread when the user taps a button on its question.</summary>
    public event Action<AskChoice>? Chosen;

    // Dragging: press on the brain (not on a button) and move. The spot is saved and used next time.
    // Clicks on see-through pixels already fall through to the window behind, so only the drawn
    // brain and bubble can be grabbed.
    private Point? dragFrom;
    private Point dragStart;
    private bool dragged;

    // The scene is drawn at 100% (240 x 288) and enlarged by the screen's scale (150% = 1.5), so the window,
    // the picture and the buttons all grow together. Mouse positions are shrunk back before the scene is asked.
    private float DpiScale => Math.Max(1f, DeviceDpi / 96f);
    private Point InScene(Point p) => new((int)(p.X / DpiScale), (int)(p.Y / DpiScale));

    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);
        if (dragFrom is { } from && (e.Button & MouseButtons.Left) != 0)
        {
            var dx = Cursor.Position.X - from.X;
            var dy = Cursor.Position.Y - from.Y;
            if (dragged || Math.Abs(dx) + Math.Abs(dy) > 4)
            {
                dragged = true;
                Location = Clamp(new Point(dragStart.X + dx, dragStart.Y + dy));
                Render();
            }
            return;
        }
        Cursor = scene.HitTest(InScene(e.Location)) == AskChoice.None ? Cursors.SizeAll : Cursors.Hand;
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        base.OnMouseDown(e);
        if (e.Button != MouseButtons.Left) return;
        var choice = scene.HitTest(InScene(e.Location));
        if (choice != AskChoice.None) { Chosen?.Invoke(choice); return; }
        dragFrom = Cursor.Position;
        dragStart = Location;
        dragged = false;
        Capture = true;
    }

    protected override void OnMouseUp(MouseEventArgs e)
    {
        base.OnMouseUp(e);
        if (dragFrom is not null && dragged) SavePosition(Location);
        dragFrom = null;
        dragged = false;
        Capture = false;
    }

    /// <summary>Keeps the whole buddy inside the work area of the screen it is on.</summary>
    private Point Clamp(Point p)
    {
        var area = Screen.FromPoint(new Point(p.X + Width / 2, p.Y + Height / 2)).WorkingArea;
        return new Point(Math.Clamp(p.X, area.Left, area.Right - Width), Math.Clamp(p.Y, area.Top, area.Bottom - Height));
    }

    private static string PositionFile => Path.Combine(
        Environment.GetEnvironmentVariable("LOCKIN_STATE_DIR")
            ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "LockIn"),
        "buddy-position.txt");

    private static void SavePosition(Point p)
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(PositionFile)!);
            File.WriteAllText(PositionFile, $"{p.X},{p.Y}");
        }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
    }

    /// <summary>The saved spot, if it is still on a screen (a monitor may have been unplugged).</summary>
    private static Point? LoadPosition(Size size)
    {
        try
        {
            if (!File.Exists(PositionFile)) return null;
            var parts = File.ReadAllText(PositionFile).Split(',');
            if (parts.Length != 2 || !int.TryParse(parts[0], out var x) || !int.TryParse(parts[1], out var y)) return null;
            var rect = new Rectangle(x, y, size.Width, size.Height);
            return Screen.AllScreens.Any(s => s.WorkingArea.IntersectsWith(rect)) ? new Point(x, y) : null;
        }
        catch (IOException) { return null; }
        catch (UnauthorizedAccessException) { return null; }
    }

    public BuddyWindow()
    {
        FormBorderStyle = FormBorderStyle.None;
        TopMost = true;
        ShowInTaskbar = false;
        StartPosition = FormStartPosition.Manual;
        Size = new Size((int)Math.Round(BuddyScene.Width * DpiScale), (int)Math.Round(BuddyScene.Height * DpiScale));
        Location = HomeSpot(Size);
        Visible = false;
        frame.Tick += (_, _) => Render();
    }

    private static BuddyWindow Start()
    {
        BuddyWindow? form = null;
        var ready = new ManualResetEventSlim();
        var thread = new Thread(() =>
        {
            form = new BuddyWindow();
            _ = form.Handle; // create the window handle now, on this thread
            ready.Set();
            Application.Run(form);
        })
        { IsBackground = true };
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
        ready.Wait();
        return form!;
    }

    /// <summary>Show or hide the buddy, and set its mood and words. Safe to call from any thread.</summary>
    /// <param name="near">The window the question is about. While asking, the buddy moves to that window's screen.</param>
    public void SetMood(BuddyMood next, bool show, string? words = null, bool ask = false, bool scrolling = false, bool canSave = false, IntPtr near = default)
    {
        if (IsDisposed) return;
        if (InvokeRequired)
        {
            BeginInvoke(() => Apply(next, show, words, ask, scrolling, canSave, near));
            return;
        }
        Apply(next, show, words, ask, scrolling, canSave, near);
    }

    // With several monitors the question must appear where the distraction is, or it is asked on a screen nobody
    // is looking at. The saved (dragged) spot stays the home position and the buddy goes back to it afterwards.
    private bool movedForQuestion;

    private static Point DefaultSpot(Screen screen, Size size) =>
        new(screen.WorkingArea.Right - size.Width - 12, screen.WorkingArea.Bottom - size.Height - 12);

    private static Point HomeSpot(Size size) => LoadPosition(size) ?? DefaultSpot(Screen.PrimaryScreen!, size);

    private void FollowQuestion(bool ask, IntPtr near)
    {
        if (dragFrom is not null) return; // never move it out from under the user's hand
        if (ask && near != IntPtr.Zero)
        {
            var target = Screen.FromHandle(near);
            var here = Screen.FromPoint(new Point(Left + Width / 2, Top + Height / 2));
            if (target.DeviceName == here.DeviceName) return;
            var home = HomeSpot(Size);
            var homeOnTarget = Screen.FromPoint(new Point(home.X + Width / 2, home.Y + Height / 2)).DeviceName == target.DeviceName;
            Location = Clamp(homeOnTarget ? home : DefaultSpot(target, Size));
            movedForQuestion = true;
        }
        else if (!ask && movedForQuestion)
        {
            Location = Clamp(HomeSpot(Size));
            movedForQuestion = false;
        }
    }

    public void ShowLater(LaterStore store)
    {
        if (IsDisposed) return;
        if (InvokeRequired) { BeginInvoke(() => ShowLater(store)); return; }
        new LaterWindow(store).Show();
    }

    private void Apply(BuddyMood next, bool show, string? words, bool ask, bool scrolling, bool canSave, IntPtr near)
    {
        if (!show)
        {
            frame.Stop();
            Visible = false;
            scene.Reset();
            return;
        }
        FollowQuestion(ask, near);
        // Same mood and same words: the scene keeps going, so the bubble does not restart every 2 seconds.
        scene.Set(next, words ?? BuddyWords.For(next, null, 0), Now, ask, scrolling, canSave);
        Visible = true;
        frame.Start();
        Render();
    }

    /// <summary>
    /// Draws the scene on a see-through picture and hands it to Windows. Per-pixel alpha keeps the
    /// edges smooth, with no box or fringe around the brain.
    /// </summary>
    private void Render()
    {
        var now = Now;
        frame.Interval = scene.Busy(now) ? FastMs : SlowMs;

        using var bitmap = new Bitmap(Width, Height, PixelFormat.Format32bppPArgb);
        using (var g = Graphics.FromImage(bitmap))
        {
            g.Clear(Color.Transparent);
            g.ScaleTransform(DpiScale, DpiScale);
            scene.Render(g, now);
        }

        var screenDc = GetDC(IntPtr.Zero);
        var memDc = CreateCompatibleDC(screenDc);
        var hBitmap = bitmap.GetHbitmap(Color.FromArgb(0));
        var old = SelectObject(memDc, hBitmap);
        try
        {
            var dst = new Point(Left, Top);
            var size = new Size(Width, Height);
            var src = new Point(0, 0);
            var blend = new Blend { Op = 0, Flags = 0, Alpha = 255, Format = 1 }; // AC_SRC_OVER, AC_SRC_ALPHA
            UpdateLayeredWindow(Handle, screenDc, ref dst, ref size, memDc, ref src, 0, ref blend, UlwAlpha);
        }
        finally
        {
            SelectObject(memDc, old);
            DeleteObject(hBitmap);
            DeleteDC(memDc);
            ReleaseDC(IntPtr.Zero, screenDc);
        }
    }
}
