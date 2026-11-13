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

    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);
        Cursor = scene.HitTest(e.Location) == AskChoice.None ? Cursors.Default : Cursors.Hand;
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        base.OnMouseDown(e);
        if (e.Button != MouseButtons.Left) return;
        var choice = scene.HitTest(e.Location);
        if (choice != AskChoice.None) Chosen?.Invoke(choice);
    }

    public BuddyWindow()
    {
        FormBorderStyle = FormBorderStyle.None;
        TopMost = true;
        ShowInTaskbar = false;
        StartPosition = FormStartPosition.Manual;
        Size = new Size(BuddyScene.Width, BuddyScene.Height);
        Location = new Point(
            Screen.PrimaryScreen!.WorkingArea.Right - Width - 12,
            Screen.PrimaryScreen.WorkingArea.Bottom - Height - 12);
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
    public void SetMood(BuddyMood next, bool show, string? words = null, bool ask = false, bool scrolling = false)
    {
        if (IsDisposed) return;
        if (InvokeRequired)
        {
            BeginInvoke(() => Apply(next, show, words, ask, scrolling));
            return;
        }
        Apply(next, show, words, ask, scrolling);
    }

    private void Apply(BuddyMood next, bool show, string? words, bool ask, bool scrolling)
    {
        if (!show)
        {
            frame.Stop();
            Visible = false;
            scene.Reset();
            return;
        }
        // Same mood and same words: the scene keeps going, so the bubble does not restart every 2 seconds.
        scene.Set(next, words ?? BuddyWords.For(next, null, 0), Now, ask, scrolling);
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
