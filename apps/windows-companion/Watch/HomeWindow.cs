using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using QRCoder;

namespace LockIn.Companion.Watch;

/// <summary>
/// The PC app's one window. A calm card: the brain in a ring (the ring is the session's time left), one
/// line of state under it, a row for the paired iPhone and a footer (start with Windows, quit). Pairing shows the QR code in place of the brain. Closing it keeps Nogbox running in the tray.
/// Warm paper, ink navy ring, an amber edge on the one main button.
/// </summary>
public sealed class HomeWindow : Form
{
    private static readonly Color Paper = Color.FromArgb(0xF6, 0xF3, 0xEC);
    private static readonly Color FooterPaper = Color.FromArgb(0xF0, 0xEE, 0xE8);
    private static readonly Color Line = Color.FromArgb(0xE6, 0xE2, 0xD9);
    private static readonly Color Ink = Color.FromArgb(0x17, 0x15, 0x13);
    private static readonly Color Soft = Color.FromArgb(0x6F, 0x6A, 0x60);
    private static readonly Color Track = Color.FromArgb(0xE4, 0xDE, 0xD3);
    private static readonly Color Accent = Color.FromArgb(0xA9, 0x70, 0x29);
    private static readonly Color Navy = Color.FromArgb(0x22, 0x33, 0x5C);
    private static readonly Color NavyHover = Color.FromArgb(0x2C, 0x41, 0x73);
    private static readonly Color Amber = Color.FromArgb(0xE5, 0x9E, 0x37);
    private static readonly Color Green = Color.FromArgb(0x2F, 0xA3, 0x6B);
    private static readonly Color Off = Color.FromArgb(0xB9, 0xB6, 0xAE);
    private static readonly Color Caption = Color.FromArgb(0x23, 0x26, 0x2B);

    // Layout in 96-dpi units; scaled by Px() for drawing and placing.
    private const int W = 440, HeroH = 344, RowH = 66, FooterH = 62, Rows = 3;
    private const int RingX = 220, RingY = 148, RingR = 112, WeekOpenH = 232;

    /// <summary>The phone's week, once the phone has sent it. Adds a row above the footer.</summary>
    private WeekSummary? week;
    /// <summary>Whether the week row is folded open. Remembered between runs; shut at first.</summary>
    private bool weekOpen;
    /// <summary>Preview pictures set this to draw the row open or shut.</summary>
    internal static bool? PreviewWeekOpen;
    private readonly WeekTab weekTab = new();
    private int WeekRowH => weekOpen ? WeekOpenH : RowH;
    private int BodyH => HeroH + RowH * Rows + WeekRowH;
    private string WeekOpenFile => Path.Combine(stateDir, "week-open");

    /// <summary>Picks up a new week from the phone: grows the window and moves the footer controls.</summary>
    private void SyncWeek()
    {
        var latest = WeekStore.Current;
        var changed = (latest is null) != (week is null);
        week = latest;
        if (changed) LayoutWeek();
        Invalidate();
    }

    private void ToggleWeek()
    {
        weekOpen = !weekOpen;
        try
        {
            if (weekOpen) File.WriteAllText(WeekOpenFile, "1");
            else File.Delete(WeekOpenFile);
        }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
        LayoutWeek();
        Invalidate();
    }

    /// <summary>Sizes the window for the week row and puts the tab and the footer controls in place.</summary>
    private void LayoutWeek()
    {
        ClientSize = new Size(Px(W), Px(BodyH + FooterH));
        var footerTop = Px(BodyH);
        startup.Location = new Point(Px(26), footerTop + (Px(FooterH) - startup.Height) / 2);
        quit.Location = new Point(ClientSize.Width - Px(24) - quit.PreferredWidth, footerTop + (Px(FooterH) - quit.PreferredHeight) / 2);
        weekTab.Open = weekOpen;
        weekTab.Visible = true;
        weekTab.Size = new Size(Px(30), Px(30));
        weekTab.Location = new Point(ClientSize.Width - Px(24) - weekTab.Width, Px(HeroH + RowH * 3) + (Px(RowH) - weekTab.Height) / 2);
        weekTab.AccessibleName = weekOpen ? "Hide this week" : "Show this week";
        weekTab.Invalidate();
    }

    /// <summary>The round tab on the week row. Click, Enter or Space folds the chart open or shut.</summary>
    private sealed class WeekTab : Control
    {
        public bool Open;
        private bool hover;
        public event Action? Toggled;

        public WeekTab()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.Selectable, true);
            BackColor = Paper;
            Cursor = Cursors.Hand;
            TabStop = true;
            AccessibleRole = AccessibleRole.PushButton;
        }

        protected override void OnClick(EventArgs e) { base.OnClick(e); Toggled?.Invoke(); }
        protected override void OnKeyDown(KeyEventArgs e)
        {
            base.OnKeyDown(e);
            if (e.KeyCode is Keys.Enter or Keys.Space) { e.Handled = true; Toggled?.Invoke(); }
        }
        protected override void OnMouseEnter(EventArgs e) { base.OnMouseEnter(e); hover = true; Invalidate(); }
        protected override void OnMouseLeave(EventArgs e) { base.OnMouseLeave(e); hover = false; Invalidate(); }
        protected override void OnGotFocus(EventArgs e) { base.OnGotFocus(e); Invalidate(); }
        protected override void OnLostFocus(EventArgs e) { base.OnLostFocus(e); Invalidate(); }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            var r = new RectangleF(1, 1, Width - 3, Height - 3);
            using (var fill = new SolidBrush(hover ? Color.FromArgb(0xE9, 0xE3, 0xD7) : Color.FromArgb(0xEF, 0xEA, 0xE0)))
                g.FillEllipse(fill, r);
            using (var edge = new Pen(Focused ? Ink : Line, Focused ? 1.6f : 1f))
                g.DrawEllipse(edge, r);
            var cx = Width / 2f; var cy = Height / 2f; var s = Width * 0.16f;
            using var pen = new Pen(Ink, Math.Max(1.6f, Width / 18f)) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round };
            if (Open) g.DrawLines(pen, new[] { new PointF(cx - s, cy + s / 2), new PointF(cx, cy - s / 2), new PointF(cx + s, cy + s / 2) });
            else g.DrawLines(pen, new[] { new PointF(cx - s, cy - s / 2), new PointF(cx, cy + s / 2), new PointF(cx + s, cy - s / 2) });
        }
    }

    protected override void OnMouseClick(MouseEventArgs e)
    {
        base.OnMouseClick(e);
        // The whole week header folds the chart too, not only the small tab.
        if (e.Button == MouseButtons.Left
            && e.Y >= Px(HeroH + RowH * 3) && e.Y < Px(HeroH + RowH * 4))
            ToggleWeek();
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);
        Cursor = e.Y >= Px(HeroH + RowH * 3) && e.Y < Px(HeroH + RowH * 4) ? Cursors.Hand : Cursors.Default;
    }

    private readonly Func<PairingOffer> openPairing;

    /// <summary>
    /// A phone on the Wi-Fi asks to pair ("Find nearby PC"). Shows Allow / Don't allow, with the
    /// 4-digit code the phone shows too. Comes from a web request thread, so it hops to this window's.
    /// </summary>
    private void OnNearbyAsk(NearbyPairing.Ask ask)
    {
        if (IsDisposed || !IsHandleCreated) return;
        BeginInvoke(() =>
        {
            if (!Visible) ShowFromTray();
            Activate();
            var allow = new TaskDialogButton("Allow");
            var deny = new TaskDialogButton("Don't allow");
            var page = new TaskDialogPage
            {
                Caption = "SwipeLater",
                Heading = $"Connect {ask.Device}?",
                Text = $"Your phone shows the code {ask.Code}.\nAllow only if it matches.",
                Buttons = { allow, deny },
                DefaultButton = deny,
                AllowCancel = true,
            };
            var left = ask.Expires - DateTimeOffset.UtcNow;
            using var timeout = new System.Windows.Forms.Timer { Interval = (int)Math.Max(1000, left.TotalMilliseconds) };
            timeout.Tick += (_, _) => { timeout.Stop(); page.BoundDialog?.Close(); };
            timeout.Start();
            var answer = TaskDialog.ShowDialog(this, page);
            NearbyPairing.Answer(ask.Id, answer == allow, openPairing, DateTimeOffset.UtcNow);
        });
    }
    private readonly Func<IReadOnlyList<PairedDevice>> devices;
    private readonly Func<FocusSession> session;
    private readonly Func<string?> taskName;
    private readonly Func<bool> buddyOn;
    private readonly Action<bool> setBuddy;
    private readonly Action<string> removeDevice;
    private readonly Func<(bool Active, bool CanPause, DateTimeOffset? BreakEnds)> pauseState;
    private readonly Func<bool> pauseBuddy;
    private readonly QuietButton pauseButton = new("Pause 5 min");
    private readonly ContextMenuStrip phoneMenu = new() { ShowImageMargin = false };
    private string buddyStatus = "On";
    private readonly string stateDir;

    private readonly Bitmap? brain;
    private readonly PrimaryButton pairButton = new("Pair a phone");
    private readonly QuietButton rowButton = new("Pair another");
    private readonly Toggle startup = new();
    private readonly Toggle buddySwitch = new() { BackColor = Paper };
    private readonly LinkLabel quit = FooterLink("Quit");
    private readonly NotifyIcon tray = new();
    private readonly System.Windows.Forms.Timer refresh = new() { Interval = 1000 };
    private readonly float scale;

    private Image? qr;
    private DateTimeOffset? qrUntil;
    private int pairedWhenCodeMade;
    private bool quitting;
    private readonly Func<bool> lockedNow;
    private bool toldAboutTray;

    // What the window shows; set by UpdateState, drawn by OnPaint.
    private string title = "", subtitle = "";
    private bool bigTime;
    private bool onBreak;
    private double ring; // how much of the ring is navy, 0..1
    private string rowTitle = "iPhone", rowStatus = "Not paired";
    private bool rowOn;
    // "Looking for your phone": sonar rings grow out of the brain while no phone is paired.
    private bool searching;
    private readonly System.Windows.Forms.Timer sonar = new() { Interval = 33 };
    private readonly System.Diagnostics.Stopwatch sonarClock = System.Diagnostics.Stopwatch.StartNew();

    public HomeWindow(Func<PairingOffer> openPairing, Func<IReadOnlyList<PairedDevice>> devices,
        Func<FocusSession> session, string stateDir, Func<string?>? taskName = null,
        Func<bool>? buddyOn = null, Action<bool>? setBuddy = null, Action<string>? removeDevice = null,
        Func<(bool Active, bool CanPause, DateTimeOffset? BreakEnds)>? pauseState = null, Func<bool>? pauseBuddy = null,
        Func<bool>? lockedNow = null)
    {
        this.removeDevice = removeDevice ?? (_ => { });
        this.pauseState = pauseState ?? (() => (false, false, null));
        this.pauseBuddy = pauseBuddy ?? (() => false);
        this.lockedNow = lockedNow ?? (() => false);
        this.buddyOn = buddyOn ?? (() => true);
        this.setBuddy = setBuddy ?? (_ => { });
        this.openPairing = openPairing;
        this.devices = devices;
        this.session = session;
        this.taskName = taskName ?? (() => null);
        this.stateDir = stateDir;

        AutoScaleMode = AutoScaleMode.None;
        scale = DeviceDpi / 96f;
        Text = "SwipeLater";
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false;
        week = WeekStore.Current;
        weekOpen = PreviewWeekOpen ?? File.Exists(WeekOpenFile);
        ClientSize = new Size(Px(W), Px(BodyH + FooterH));
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Paper;
        ForeColor = Ink;
        Font = new Font("Segoe UI", 10.5f);
        DoubleBuffered = true;
        brain = LoadBrain();
        if (brain is not null) Icon = Icon.FromHandle(new Bitmap(brain, new Size(64, 64)).GetHicon());

        pairButton.Size = new Size(Px(156), Px(46));
        pairButton.Location = new Point((ClientSize.Width - pairButton.Width) / 2, Px(318));
        pairButton.Click += (_, _) => ShowPairing();
        Controls.Add(pairButton);

        rowButton.Font = new Font("Segoe UI Semibold", 10f);
        rowButton.Size = new Size(Px(118), Px(38));
        rowButton.Location = new Point(ClientSize.Width - rowButton.Width - Px(22), Px(HeroH) + (Px(RowH) - rowButton.Height) / 2);
        rowButton.Click += (_, _) =>
        {
            if (qrUntil is not null) { StopPairing(); return; }
            BuildPhoneMenu();
            phoneMenu.Show(rowButton, new Point(rowButton.Width - phoneMenu.Width, rowButton.Height + Px(4)));
        };
        phoneMenu.Renderer = new MenuLook();
        phoneMenu.Font = new Font("Segoe UI", 10.5f);
        Controls.Add(rowButton);

        buddySwitch.Size = new Size(Px(44), Px(24));
        buddySwitch.Location = new Point(ClientSize.Width - buddySwitch.Width - Px(26), Px(HeroH + RowH) + (Px(RowH) - buddySwitch.Height) / 2);
        buddySwitch.On = this.buddyOn();
        buddySwitch.AccessibleName = "Desk buddy";
        buddySwitch.Changed += on =>
        {
            Invalidate(new Rectangle(0, Px(HeroH + RowH), Px(300), Px(RowH)));
            _ = Task.Run(() => { try { this.setBuddy(on); } catch (Exception) { } });
        };
        Controls.Add(buddySwitch);

        pauseButton.Font = new Font("Segoe UI Semibold", 9.5f);
        pauseButton.Size = new Size(Px(104), Px(34));
        pauseButton.Location = new Point(buddySwitch.Left - pauseButton.Width - Px(14), Px(HeroH + RowH) + (Px(RowH) - pauseButton.Height) / 2);
        pauseButton.AccessibleDescription = "Rests the buddy for 5 minutes. Once per session.";
        pauseButton.Click += (_, _) => { if (this.pauseBuddy()) UpdateState(); };
        Controls.Add(pauseButton);

        var footerTop = Px(BodyH);
        startup.Size = new Size(Px(44), Px(24));
        startup.Location = new Point(Px(26), footerTop + (Px(FooterH) - startup.Height) / 2);
        startup.On = Installer.StartsWithWindows();
        startup.AccessibleName = "Start with Windows";
        startup.Changed += on => _ = Task.Run(() => { try { Installer.SetStartWithWindows(on); } catch (Exception) { } });
        Controls.Add(startup);

        quit.Location = new Point(ClientSize.Width - Px(24) - quit.PreferredWidth, footerTop + (Px(FooterH) - quit.PreferredHeight) / 2);
        quit.LinkClicked += (_, _) => Quit();
        Controls.Add(quit);

        weekTab.Toggled += ToggleWeek;
        NearbyPairing.Asked += OnNearbyAsk;
        Controls.Add(weekTab);
        LayoutWeek();

        // Tray: closing the window keeps Nogbox working.
        tray.Icon = Icon ?? SystemIcons.Application;
        tray.Text = "SwipeLater";
        tray.Visible = true;
        var menu = new ContextMenuStrip();
        menu.Items.Add("Open SwipeLater", null, (_, _) => ShowFromTray());
        menu.Items.Add("Quit", null, (_, _) => Quit());
        tray.ContextMenuStrip = menu;
        tray.DoubleClick += (_, _) => ShowFromTray();

        sonar.Tick += (_, _) => Invalidate(new Rectangle(0, 0, ClientSize.Width, Px(HeroH)));
        refresh.Tick += (_, _) => UpdateState();
        refresh.Start();
        UpdateState();
    }

    private int Px(int v) => (int)Math.Round(v * scale);
    private float Pf(float v) => v * scale;

    private static LinkLabel FooterLink(string text) => new()
    {
        Text = text, AutoSize = true, BackColor = FooterPaper, LinkColor = Ink, ActiveLinkColor = Navy, VisitedLinkColor = Ink,
        LinkBehavior = LinkBehavior.HoverUnderline, Font = new Font("Segoe UI Semibold", 10f)
    };

    private static Bitmap? LoadBrain()
    {
        using var stream = typeof(HomeWindow).Assembly.GetManifestResourceStream("LockIn.Companion.Watch.Assets.BrainExact.png");
        if (stream is null) return null;
        using var image = Image.FromStream(stream);
        return new Bitmap(image);
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        // Dark caption bar on Windows 11; older Windows ignores these and keeps its own.
        var dark = 1;
        _ = DwmSetWindowAttribute(Handle, 20, ref dark, sizeof(int));
        var caption = Caption.R | (Caption.G << 8) | (Caption.B << 16);
        _ = DwmSetWindowAttribute(Handle, 35, ref caption, sizeof(int));
        var text = 0xFFFFFF;
        _ = DwmSetWindowAttribute(Handle, 36, ref text, sizeof(int));
    }

    [DllImport("dwmapi.dll")] private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);

    private void ShowPairing()
    {
        try
        {
            var offer = openPairing();
            var payload = System.Text.Json.JsonSerializer.Serialize(offer, new System.Text.Json.JsonSerializerOptions(System.Text.Json.JsonSerializerDefaults.Web));
            using var generator = new QRCodeGenerator();
            using var data = generator.CreateQrCode("nogbox://pair?d=" + Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(payload)).TrimEnd('=').Replace('+', '-').Replace('/', '_'), QRCodeGenerator.ECCLevel.L);
            var png = new PngByteQRCode(data).GetGraphic(8);
            using var ms = new MemoryStream(png);
            qr?.Dispose();
            qr = Image.FromStream(ms);
            qrUntil = offer.ExpiresAt;
            pairedWhenCodeMade = devices().Count;
        }
        catch (Exception)
        {
            qrUntil = null;
        }
        UpdateState();
    }

    private void StopPairing()
    {
        qrUntil = null;
        UpdateState();
    }

    // Finish toast: remembers the running session, and when it runs out shows "Done. 25 minutes locked in."
    // It waits up to 15 s for the phone's fresh week so the second line is up to date. Early ends get none.
    private string? watchedId;
    private DateTimeOffset watchedEnds;
    private int watchedMinutes;
    private DateTimeOffset? toastDue;
    private int toastMinutes;
    private DateTimeOffset weekBefore;

    private void CheckFinished(FocusSession current, DateTimeOffset now)
    {
        if (current.State == "active" && current.EndsAt is { } ends && now < ends)
        {
            watchedId = current.Id;
            watchedEnds = ends;
            watchedMinutes = Math.Max(1, (int)Math.Round(current.DurationSeconds / 60.0));
        }
        else if (watchedId is not null)
        {
            if (now >= watchedEnds - TimeSpan.FromSeconds(15))
            {
                toastDue = now + TimeSpan.FromSeconds(15);
                toastMinutes = watchedMinutes;
                weekBefore = WeekStore.LastSet;
            }
            watchedId = null;
        }
        if (toastDue is { } due && (now >= due || WeekStore.LastSet > weekBefore))
        {
            toastDue = null;
            var w = WeekStore.Current;
            var line = w is null ? "Nice work." : $"Today {WeekStore.Hours(w.TodaySeconds)} · {WeekStore.Hours(w.TotalSeconds)} this week";
            tray.ShowBalloonTip(6000, toastMinutes == 1 ? "Done. 1 minute locked in." : $"Done. {toastMinutes} minutes locked in.", line, ToolTipIcon.None);
        }
    }

    private void UpdateState()
    {
        var paired = devices();
        var now = DateTimeOffset.UtcNow;
        var current = session();
        CheckFinished(current, now);
        bigTime = false;
        onBreak = false;

        // The code stays up until it runs out or a new phone shows up.
        if (qrUntil is not null && paired.Count > pairedWhenCodeMade) qrUntil = null;
        else if (qrUntil is { } until && now >= until) { ShowPairing(); return; }
        var pairing = qrUntil is not null;

        if (pairing)
        {
            var left = qrUntil!.Value - now;
            title = "Scan with your iPhone Camera";
            subtitle = $"Then tap the SwipeLater banner. New code in {(int)left.TotalMinutes}:{left.Seconds:00}.";
            ring = 0;
        }
        else if (paired.Count == 0)
        {
            title = "";
            subtitle = "Looking for your phone. Open SwipeLater on it.";
            ring = 0;
        }
        else if (current.State == "active" && pauseState().BreakEnds is { } breakEnds)
        {
            var left = breakEnds - now;
            if (left < TimeSpan.Zero) left = TimeSpan.Zero;
            onBreak = true;
            title = "On a break";
            subtitle = $"The buddy is resting. Back in {(int)left.TotalMinutes}:{left.Seconds:00}.";
            ring = Math.Clamp(left.TotalSeconds / HomeWindowBreakSeconds, 0, 1);
        }
        else if (current.State == "active" && current.EndsAt is { } ends)
        {
            var left = ends - now;
            if (left < TimeSpan.Zero) left = TimeSpan.Zero;
            var total = Math.Max(1, current.DurationSeconds);
            var startedAgo = current.StartedAt is { } s ? now - s : TimeSpan.MaxValue;
            if (startedAgo < TimeSpan.FromSeconds(4))
            {
                title = "Locked in";
                subtitle = $"{Math.Max(1, total / 60)} minutes.";
                ring = 1;
            }
            else
            {
                bigTime = true;
                title = $"{(int)left.TotalMinutes}:{left.Seconds:00}";
                var task = taskName();
                subtitle = string.IsNullOrWhiteSpace(task) ? "Focusing" : task.Trim();
                ring = Math.Clamp(left.TotalSeconds / total, 0, 1);
            }
        }
        else
        {
            title = "No session";
            subtitle = "Start one on your phone — this PC follows.";
            ring = 0;
        }

        searching = paired.Count == 0 && !pairing && SystemInformation.UIEffectsEnabled;
        if (searching != sonar.Enabled) sonar.Enabled = searching;
        pairButton.Visible = paired.Count == 0 && !pairing;
        rowOn = paired.Count > 0;
        rowTitle = paired.Count == 0 ? "iPhone" : paired[^1].Name + (paired.Count > 1 ? $" +{paired.Count - 1}" : "");
        rowStatus = pairing ? "Waiting for your phone" : paired.Count == 0 ? "Not paired" : "Paired";
        rowButton.Visible = paired.Count > 0 || pairing;
        rowButton.Text = pairing ? "Cancel" : "Manage";
        var pause = pauseState();
        pauseButton.Visible = pause.CanPause && buddySwitch.On && current.State == "active";
        buddyStatus = !buddySwitch.On ? "Off"
            : pause.BreakEnds is { } b ? $"Resting \u00b7 back in {(int)(b - now).TotalMinutes}:{(b - now).Seconds:00}"
            : pause.Active && !pause.CanPause ? "On \u00b7 break used" : "On";
        AccessibleDescription = $"{title}. {subtitle}. {rowTitle}: {rowStatus}.";
        SyncWeek();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        g.Clear(Paper);

        if (qrUntil is not null && qr is not null)
        {
            var size = Px(184);
            var box = new Rectangle((ClientSize.Width - size) / 2, Px(RingY) - size / 2, size, size);
            using (var card = Rounded(Rectangle.Inflate(box, Px(10), Px(10)), Px(16)))
            using (var white = new SolidBrush(Color.White))
            using (var edge = new Pen(Line, Pf(1.5f)))
            {
                g.FillPath(white, card);
                g.DrawPath(edge, card);
            }
            g.InterpolationMode = InterpolationMode.NearestNeighbor;
            g.PixelOffsetMode = PixelOffsetMode.Half;
            g.DrawImage(qr, box);
            g.PixelOffsetMode = PixelOffsetMode.Default;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        }
        else
        {
            var r = Pf(RingR);
            var c = new PointF(Pf(RingX), Pf(RingY));
            var rect = new RectangleF(c.X - r, c.Y - r, 2 * r, 2 * r);
            using (var track = new Pen(Track, Pf(5f)))
                g.DrawEllipse(track, rect);
            // Ticks inside the ring: 60 small, 12 long.
            using (var tick = new Pen(Color.FromArgb(0xB9, 0xB2, 0xA4), Pf(1.2f)))
            using (var tickBig = new Pen(Soft, Pf(1.6f)))
            {
                for (var i = 0; i < 60; i++)
                {
                    var a = i * Math.PI / 30;
                    var big = i % 5 == 0;
                    var r1 = r - Pf(big ? 18 : 13);
                    var r2 = r - Pf(8);
                    g.DrawLine(big ? tickBig : tick,
                        c.X + (float)Math.Sin(a) * r1, c.Y - (float)Math.Cos(a) * r1,
                        c.X + (float)Math.Sin(a) * r2, c.Y - (float)Math.Cos(a) * r2);
                }
            }
            if (searching)
            {
                // Three rings leave the brain one after another, slow at the end, fading as they grow.
                var t = (sonarClock.ElapsedMilliseconds + 3600 - 600) % 3600 / 3600.0;
                var r0 = r * 0.26f;
                var r1 = r - Pf(14);
                for (var k = 0; k < 3; k++)
                {
                    var q = (t + k / 3.0) % 1.0;
                    var grow = 1 - Math.Pow(1 - q, 2.2);
                    var rr = r0 + (r1 - r0) * (float)grow;
                    var alpha = (int)(235 * (1 - q) * Math.Min(1, q / 0.1));
                    if (alpha < 4) continue;
                    using var pulse = new Pen(Color.FromArgb(alpha, Amber), Pf(3.2f));
                    g.DrawEllipse(pulse, c.X - rr, c.Y - rr, 2 * rr, 2 * rr);
                }
            }
            if (ring > 0.001)
            {
                using var arc = new Pen(onBreak ? Amber : Accent, Pf(5.5f)) { StartCap = LineCap.Round, EndCap = LineCap.Round };
                if (ring >= 0.999) g.DrawEllipse(arc, rect);
                else g.DrawArc(arc, rect, -90, (float)(360 * ring));
            }
            // Hand-drawn tally ticks at the lower left of the ring.
            using (var tally = new Pen(Ink, Pf(2f)) { StartCap = LineCap.Round, EndCap = LineCap.Round })
            {
                var tx = c.X - r * 0.80f; var ty = c.Y + r * 0.66f;
                for (var i = 0; i < 3; i++)
                    g.DrawLine(tally, tx + i * Pf(6), ty + Pf(9), tx + i * Pf(6) + Pf(5), ty - Pf(1));
            }
            if (brain is not null)
            {
                var bw = Pf(92);
                var bh = bw * brain.Height / brain.Width;
                // While searching, the brain sways up and down, one smooth swing per ring. A ring leaves
                // (every 1200 ms) at the moment the brain comes back down to the middle (600 ms into each swing).
                var bob = searching ? (float)Math.Sin(sonarClock.ElapsedMilliseconds % 1200 / 1200.0 * 2 * Math.PI) * Pf(6) : 0f;
                g.DrawImage(brain, c.X - bw / 2, c.Y - bh / 2 - Pf(8) - bob, bw, bh);
            }
            using (var timeFont = bigTime ? new Font("Segoe UI Semibold", 26f) : new Font("Segoe UI Semibold", 15f))
            {
                var timeH = TextRenderer.MeasureText(g, title, timeFont, Size.Empty, TextFormatFlags.NoPadding).Height;
                TextRenderer.DrawText(g, title, timeFont, new Rectangle((int)(c.X - r * 0.8f), (int)(c.Y + Pf(34)), (int)(r * 1.6f), timeH), Ink,
                    TextFormatFlags.HorizontalCenter | TextFormatFlags.NoPadding);
            }
        }

        var top = Px(RingY + RingR + 18);
        using (var subFont = new Font("Segoe UI", 10.5f))
            TextRenderer.DrawText(g, subtitle, subFont, new Rectangle(Px(24), top, ClientSize.Width - Px(48), Px(40)), Soft,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.WordBreak | TextFormatFlags.NoPadding);

        // iPhone row
        var rowTop = Px(HeroH);
        using (var line = new Pen(Line, 1))
        {
            g.DrawLine(line, 0, rowTop, ClientSize.Width, rowTop);
            g.DrawLine(line, 0, rowTop + Px(RowH), ClientSize.Width, rowTop + Px(RowH));
            g.DrawLine(line, 0, rowTop + Px(RowH * 2), ClientSize.Width, rowTop + Px(RowH * 2));
        }
        var icon = new Rectangle(Px(28), rowTop + Px(RowH) / 2 - Px(11), Px(13), Px(22));
        using (var ip = new Pen(Ink, Pf(1.6f)))
        using (var phone = Rounded(icon, Px(3)))
        {
            g.DrawPath(ip, phone);
            g.DrawLine(ip, icon.X + icon.Width / 2f - Pf(2), icon.Bottom - Pf(4), icon.X + icon.Width / 2f + Pf(2), icon.Bottom - Pf(4));
        }
        using (var rowFont = new Font("Segoe UI", 11f))
        using (var statusFont = new Font("Segoe UI", 9.5f))
        {
            TextRenderer.DrawText(g, rowTitle, rowFont, new Point(Px(62), rowTop + Px(12)), Ink, TextFormatFlags.NoPadding);
            var dotY = rowTop + Px(44);
            using (var dot = new SolidBrush(rowOn ? Green : Off))
                g.FillEllipse(dot, Pf(63), dotY - Pf(3.5f), Pf(7), Pf(7));
            TextRenderer.DrawText(g, rowStatus, statusFont, new Rectangle(Px(76), dotY - Px(10), Px(220), Px(20)), Soft,
                TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
        }

        // Desk buddy row: the little brain, what it does, and the switch.
        var buddyTop = Px(HeroH + RowH);
        if (brain is not null)
        {
            var bw = Pf(34);
            var bh = bw * brain.Height / brain.Width;
            g.DrawImage(brain, Pf(18), buddyTop + Pf(RowH) / 2 - bh / 2, bw, bh);
        }
        using (var rowFont = new Font("Segoe UI", 11f))
        using (var statusFont = new Font("Segoe UI", 9.5f))
        {
            var on = buddySwitch.On;
            TextRenderer.DrawText(g, "Desk buddy", rowFont, new Point(Px(62), buddyTop + Px(12)), Ink, TextFormatFlags.NoPadding);
            var dotY = buddyTop + Px(44);
            using (var dot = new SolidBrush(on ? Green : Off))
                g.FillEllipse(dot, Pf(63), dotY - Pf(3.5f), Pf(7), Pf(7));
            TextRenderer.DrawText(g, buddyStatus, statusFont,
                new Rectangle(Px(76), dotY - Px(10), Px(280), Px(20)), Soft, TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
        }

        // Partner row: what the partner may see and do. Always on, no switch.
        var partnerTop = Px(HeroH + RowH * 2);
        using (var rowFont = new Font("Segoe UI", 11f))
        using (var statusFont = new Font("Segoe UI", 9.5f))
        using (var pen = new Pen(Ink, Pf(1.6f)))
        {
            // Two small people, drawn, so the row has a mark like the other two.
            var cy = partnerTop + Pf(RowH) / 2;
            g.DrawEllipse(pen, Pf(24), cy - Pf(9), Pf(9), Pf(9));
            g.DrawArc(pen, Pf(21), cy + Pf(1), Pf(15), Pf(14), 180, 180);
            g.DrawEllipse(pen, Pf(36), cy - Pf(7), Pf(7), Pf(7));
            g.DrawArc(pen, Pf(34), cy + Pf(2), Pf(11), Pf(11), 180, 180);
            TextRenderer.DrawText(g, "Your partner can see and pause", rowFont, new Point(Px(62), partnerTop + Px(12)), Ink, TextFormatFlags.NoPadding);
            var dotY = partnerTop + Px(44);
            using (var dot = new SolidBrush(Green))
                g.FillEllipse(dot, Pf(63), dotY - Pf(3.5f), Pf(7), Pf(7));
            TextRenderer.DrawText(g, "Window title only. Private windows stay hidden", statusFont,
                new Rectangle(Px(76), dotY - Px(10), Px(280), Px(20)), Soft, TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
        }

        // This week, sent by the phone. A header row that is always there, with a small round tab that
        // folds the chart open and shut. Shut: total, daily average and a tiny 7-bar sparkline. Open:
        // the total against the goal, then the full chart (plain bars, time above each, dashed average).
        // With no week from the phone yet, the row still shows, empty, and says so.
        var noData = week is null;
        var wk = week ?? new WeekSummary(new int[7], 0, 0, 0, ((int)DateTime.Now.DayOfWeek + 6) % 7);
        {
            var wTop = Px(HeroH + RowH * 3);
            using (var line = new Pen(Line, 1))
                g.DrawLine(line, 0, wTop, ClientSize.Width, wTop);
            using var rowFont = new Font("Segoe UI", 11f);
            using var smallFont = new Font("Segoe UI", 9.5f);
            using var totalFont = new Font("Segoe UI Semibold", 18f);
            using var valueFont = new Font("Segoe UI", 8.5f);
            var faint = Color.FromArgb(0xE4, 0xDE, 0xD3);
            var tan = Color.FromArgb(0xE6, 0xC4, 0x93);
            var right = ClientSize.Width - Px(24);
            var most = Math.Max(1, wk.DaySeconds.Max());
            var avg = wk.TotalSeconds / (wk.TodayIndex + 1);

            // Row mark: three small pills, like the chart.
            using (var markBrush = new SolidBrush(Ink))
            {
                var by = wTop + Pf(40);
                foreach (var (dx, h) in new[] { (0f, 8f), (6f, 15f), (12f, 11f) })
                    using (var p = Pill(Pf(23) + Pf(dx), by - Pf(h), Pf(3.5f), Pf(h)))
                        g.FillPath(markBrush, p);
            }
            TextRenderer.DrawText(g, "This week", rowFont, new Point(Px(62), wTop + Px(12)), Ink, TextFormatFlags.NoPadding);

            string sub;
            if (noData)
                sub = weekOpen ? "" : "No data yet";
            else if (!weekOpen)
                sub = $"{WeekStore.Hours(wk.TotalSeconds)} · daily avg {WeekStore.Hours(avg)}";
            else
            {
                // Like Screen Time: the daily average so far, against the one from last week.
                sub = $"Daily avg {WeekStore.Hours(avg)}";
                if (wk.LastWeekSeconds > 0)
                {
                    var lastAvg = wk.LastWeekSeconds / 7.0;
                    var pct = (int)Math.Round((avg - lastAvg) / lastAvg * 100);
                    sub += pct == 0 ? " · same as last week" : $" · {(pct > 0 ? "↑" : "↓")} {Math.Abs(pct)}% from last week";
                }
            }
            TextRenderer.DrawText(g, sub, smallFont, new Point(Px(62), wTop + Px(36)), Soft, TextFormatFlags.NoPadding);

            if (!weekOpen)
            {
                // Sparkline: seven tiny bars just left of the tab, today in deep amber.
                var sw = Pf(4); var sg = Pf(3); var sh = Pf(20);
                var sx = weekTab.Left - Pf(14) - 7 * sw - 6 * sg;
                var sb = wTop + Pf(RowH) / 2 + sh / 2;
                for (var i = 0; i < (noData ? 0 : 7); i++)
                {
                    var future = i > wk.TodayIndex;
                    var h = future || wk.DaySeconds[i] <= 0 ? Pf(2) : Math.Max(Pf(3), sh * (float)(wk.DaySeconds[i] / (double)most));
                    using var b = new SolidBrush(future ? faint : i == wk.TodayIndex ? Accent : tan);
                    using var p = TopRounded(sx + i * (sw + sg), sb - h, sw, h, Pf(2));
                    g.FillPath(b, p);
                }
            }
            else
            {
                // Total against the goal (nothing to show before the phone sends a week).
                if (!noData)
                {
                var y0 = wTop + Px(RowH) + Px(4);
                var total = WeekStore.Hours(wk.TotalSeconds);
                var tw = TextRenderer.MeasureText(g, total, totalFont, Size.Empty, TextFormatFlags.NoPadding).Width;
                TextRenderer.DrawText(g, total, totalFont, new Point(Px(62), y0), Ink, TextFormatFlags.NoPadding);
                if (wk.GoalSeconds > 0)
                {
                    TextRenderer.DrawText(g, $"of {WeekStore.Hours(wk.GoalSeconds)}", smallFont,
                        new Point(Px(62) + tw + Px(6), y0 + Px(11)), Soft, TextFormatFlags.NoPadding);
                    var barLen = Pf(120);
                    var bx = right - barLen;
                    var byy = y0 + Pf(18);
                    var done = (float)Math.Min(1, wk.TotalSeconds / (double)wk.GoalSeconds);
                    using (var trackB = new SolidBrush(faint))
                    using (var t = Pill(bx, byy, barLen, Pf(6)))
                        g.FillPath(trackB, t);
                    if (done > 0)
                        using (var fillB = new SolidBrush(Accent))
                        using (var f = Pill(bx, byy, Math.Max(Pf(6), barLen * done), Pf(6)))
                            g.FillPath(fillB, f);
                    var label = done >= 1 ? "Goal met" : $"{(int)(done * 100)}% of goal";
                    var lw = TextRenderer.MeasureText(g, label, valueFont, Size.Empty, TextFormatFlags.NoPadding).Width;
                    TextRenderer.DrawText(g, label, valueFont, new Point(right - lw, (int)byy - Px(17)), done >= 1 ? Accent : Soft, TextFormatFlags.NoPadding);
                }
                }

                // The chart.
                var left = Px(62);
                var colW = (right - left) / 7f;
                var barW = Pf(18);
                var maxH = Pf(56);
                var floor = wTop + Px(WeekOpenH) - Px(28);
                var letters = "MTWTFSS";
                using (var basePen = new Pen(faint, Pf(1f)))
                    g.DrawLine(basePen, left, floor, right, floor);
                if (noData)
                    TextRenderer.DrawText(g, "No data yet", smallFont,
                        new Rectangle(left, (int)floor - Px(60), right - left, Px(20)), Soft,
                        TextFormatFlags.HorizontalCenter | TextFormatFlags.NoPadding);
                if (avg > 0)
                {
                    var ay = floor - maxH * (float)(avg / (double)most);
                    using (var dash = new Pen(Soft, Pf(1.2f)) { DashPattern = new[] { 3f, 3f } })
                        g.DrawLine(dash, left, ay, right - Pf(22), ay);
                    using var avgFont = new Font("Segoe UI", 8f);
                    TextRenderer.DrawText(g, "avg", avgFont, new Point((int)(right - Pf(19)), (int)(ay - Pf(7))), Soft, TextFormatFlags.NoPadding);
                }
                for (var i = 0; i < 7; i++)
                {
                    var cx = left + colW * i + colW / 2;
                    var isToday = i == wk.TodayIndex;
                    var future = i > wk.TodayIndex;
                    if (!future && !noData)
                    {
                        var secs = wk.DaySeconds[i];
                        var h = secs <= 0 ? 0 : Math.Max(Pf(6), maxH * (float)(secs / (double)most));
                        if (h > 0)
                            using (var fill = new SolidBrush(isToday ? Accent : tan))
                            using (var shape = TopRounded(cx - barW / 2, floor - h, barW, h, Pf(5)))
                                g.FillPath(fill, shape);
                        // A paper patch behind the number, so the average line never runs through it.
                        var text = secs <= 0 ? "0" : WeekStore.Hours(secs);
                        var txw = TextRenderer.MeasureText(g, text, valueFont, Size.Empty, TextFormatFlags.NoPadding).Width + Px(4);
                        var tr = new Rectangle((int)(cx - txw / 2f), (int)(floor - h) - Px(17), txw, Px(14));
                        using (var patch = new SolidBrush(Paper))
                            g.FillRectangle(patch, tr);
                        TextRenderer.DrawText(g, text, valueFont, tr, isToday ? Accent : Soft,
                            TextFormatFlags.HorizontalCenter | TextFormatFlags.NoPadding);
                    }
                    using var dayFont = new Font("Segoe UI", 8.5f, isToday ? FontStyle.Bold : FontStyle.Regular);
                    TextRenderer.DrawText(g, letters[i].ToString(), dayFont,
                        new Rectangle((int)(cx - colW / 2), (int)floor + Px(6), (int)colW, Px(14)),
                        future ? Color.FromArgb(0xB9, 0xB2, 0xA4) : isToday ? Ink : Soft,
                        TextFormatFlags.HorizontalCenter | TextFormatFlags.NoPadding);
                }
            }
        }

        // Footer
        using (var foot = new SolidBrush(FooterPaper))
            g.FillRectangle(foot, 0, Px(BodyH) + 1, ClientSize.Width, Px(FooterH));
        using (var footFont = new Font("Segoe UI", 10.5f))
            TextRenderer.DrawText(g, "Start with Windows", footFont,
                new Rectangle(startup.Right + Px(10), startup.Top - Px(2), Px(200), startup.Height + Px(4)), Ink,
                TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
    }

    private const double HomeWindowBreakSeconds = 300;

    /// <summary>The iPhone row's menu: pair another phone, or unpair one (after a yes).</summary>
    private void BuildPhoneMenu()
    {
        phoneMenu.Items.Clear();
        phoneMenu.Items.Add("Pair another phone", null, (_, _) => ShowPairing());
        var paired = devices();
        if (paired.Count > 0) phoneMenu.Items.Add(new ToolStripSeparator());
        foreach (var device in paired)
        {
            var item = new ToolStripMenuItem($"Unpair {device.Name}") { ForeColor = Color.FromArgb(0xA8, 0x2A, 0x22) };
            item.Click += (_, _) =>
            {
                var sure = MessageBox.Show(this, $"Unpair {device.Name}? This PC stops following it. You can pair it again any time.",
                    "Unpair phone", MessageBoxButtons.OKCancel, MessageBoxIcon.None, MessageBoxDefaultButton.Button2);
                if (sure != DialogResult.OK) return;
                try { removeDevice(device.Id); } catch (Exception) { }
                UpdateState();
            };
            phoneMenu.Items.Add(item);
        }
    }

    /// <summary>Paper menu with a soft hover, to match the window.</summary>
    private sealed class MenuLook : ToolStripProfessionalRenderer
    {
        public MenuLook() : base(new Palette()) { RoundedEdges = true; }

        private sealed class Palette : ProfessionalColorTable
        {
            public override Color ToolStripDropDownBackground => Paper;
            public override Color MenuItemSelected => Color.FromArgb(0xEC, 0xEA, 0xE3);
            public override Color MenuItemSelectedGradientBegin => Color.FromArgb(0xEC, 0xEA, 0xE3);
            public override Color MenuItemSelectedGradientEnd => Color.FromArgb(0xEC, 0xEA, 0xE3);
            public override Color MenuItemBorder => Color.FromArgb(0xEC, 0xEA, 0xE3);
            public override Color MenuBorder => Line;
            public override Color SeparatorDark => Line;
            public override Color SeparatorLight => Paper;
            public override Color ImageMarginGradientBegin => Paper;
            public override Color ImageMarginGradientMiddle => Paper;
            public override Color ImageMarginGradientEnd => Paper;
        }
    }

    private void ShowFromTray()
    {
        Show();
        WindowState = FormWindowState.Normal;
        Activate();
    }

    private void Quit()
    {
        // In a Locked session there is no way out through Quit; Nogbox keeps watching until the timer ends.
        if (lockedNow())
        {
            tray.ShowBalloonTip(3000, "You are locked in", "SwipeLater stays on until the timer ends.", ToolTipIcon.None);
            return;
        }
        quitting = true;
        tray.Visible = false;
        Application.Exit();
        Environment.Exit(0);
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        if (!quitting && e.CloseReason == CloseReason.UserClosing)
        {
            e.Cancel = true;
            Hide();
            if (!toldAboutTray)
            {
                toldAboutTray = true;
                tray.ShowBalloonTip(3000, "SwipeLater is still on", "It keeps working in the tray. Right-click the icon to quit.", ToolTipIcon.None);
            }
            return;
        }
        base.OnFormClosing(e);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing) NearbyPairing.Asked -= OnNearbyAsk;
        if (disposing) { sonar.Dispose(); refresh.Dispose(); tray.Dispose(); qr?.Dispose(); brain?.Dispose(); phoneMenu.Dispose(); }
        base.Dispose(disposing);
    }

    /// <summary>A bar with round top corners and a flat bottom, so it stands on the baseline.</summary>
    private static GraphicsPath TopRounded(float x, float y, float w, float h, float r)
    {
        r = Math.Min(r, Math.Min(w / 2, h));
        var p = new GraphicsPath();
        p.AddArc(x, y, 2 * r, 2 * r, 180, 90);
        p.AddArc(x + w - 2 * r, y, 2 * r, 2 * r, 270, 90);
        p.AddLine(x + w, y + h, x, y + h);
        p.CloseFigure();
        return p;
    }

    /// <summary>A rectangle with fully round ends (a capsule), vertical or horizontal.</summary>
    private static GraphicsPath Pill(float x, float y, float w, float h)
    {
        var p = new GraphicsPath();
        var d = Math.Min(w, h);
        if (h >= w)
        {
            p.AddArc(x, y, d, d, 180, 180);
            p.AddArc(x, y + h - d, d, d, 0, 180);
        }
        else
        {
            p.AddArc(x, y, d, d, 90, 180);
            p.AddArc(x + w - d, y, d, d, 270, 180);
        }
        p.CloseFigure();
        return p;
    }

    private static GraphicsPath Rounded(Rectangle r, int radius)
    {
        var d = Math.Max(1, radius * 2);
        var path = new GraphicsPath();
        path.AddArc(r.X, r.Y, d, d, 180, 90);
        path.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        path.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        path.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        path.CloseFigure();
        return path;
    }

    /// <summary>The one main action: ink navy with an amber edge underneath.</summary>
    private sealed class PrimaryButton : Button
    {
        public PrimaryButton(string text)
        {
            Text = text;
            FlatStyle = FlatStyle.Flat;
            FlatAppearance.BorderSize = 0;
            BackColor = Paper;
            Font = new Font("Segoe UI Semibold", 11f);
            Cursor = Cursors.Hand;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.Clear(Paper);
            var radius = Height / 7;
            using (var edge = Rounded(new Rectangle(0, 4, Width - 1, Height - 5), radius))
            using (var amber = new SolidBrush(Amber))
                g.FillPath(amber, edge);
            var hover = ClientRectangle.Contains(PointToClient(MousePosition));
            using (var face = Rounded(new Rectangle(0, 0, Width - 1, Height - 5), radius))
            using (var navy = new SolidBrush(hover ? NavyHover : Navy))
                g.FillPath(navy, face);
            TextRenderer.DrawText(g, Text, Font, new Rectangle(0, 0, Width, Height - 5), Color.White,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
            if (Focused && ShowFocusCues)
                using (var pen = new Pen(Amber, 2) { DashStyle = DashStyle.Dot })
                    g.DrawRectangle(pen, 3, 3, Width - 7, Height - 11);
        }

        protected override void OnMouseEnter(EventArgs e) { base.OnMouseEnter(e); Invalidate(); }
        protected override void OnMouseLeave(EventArgs e) { base.OnMouseLeave(e); Invalidate(); }
    }

    /// <summary>A quiet rounded outline button for the iPhone row.</summary>
    private sealed class QuietButton : Button
    {
        public QuietButton(string text)
        {
            Text = text;
            FlatStyle = FlatStyle.Flat;
            FlatAppearance.BorderSize = 0;
            BackColor = Paper;
            Cursor = Cursors.Hand;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.Clear(Paper);
            var hover = ClientRectangle.Contains(PointToClient(MousePosition));
            using (var face = Rounded(new Rectangle(1, 1, Width - 3, Height - 3), 6))
            using (var fill = new SolidBrush(hover ? Color.FromArgb(0xEC, 0xEA, 0xE3) : Color.FromArgb(0xFB, 0xFA, 0xF7)))
            using (var edge = new Pen(Focused && ShowFocusCues ? Navy : Line, 1.5f))
            {
                g.FillPath(fill, face);
                g.DrawPath(edge, face);
            }
            TextRenderer.DrawText(g, Text, Font, ClientRectangle, Ink, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
        }

        protected override void OnMouseEnter(EventArgs e) { base.OnMouseEnter(e); Invalidate(); }
        protected override void OnMouseLeave(EventArgs e) { base.OnMouseLeave(e); Invalidate(); }
    }

    /// <summary>
    /// A pill switch, green when on. It flips on mouse down (no wait for the click, and fast taps never count
    /// as a double-click), then the knob slides over in about a tenth of a second.
    /// </summary>
    private sealed class Toggle : Control
    {
        private bool on;
        private float pos; // 0 = off, 1 = on; where the knob is drawn
        private readonly System.Windows.Forms.Timer slide = new() { Interval = 10 };
        private DateTime slideStart;
        private float slideFrom;
        public event Action<bool>? Changed;

        public Toggle()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.Selectable, true);
            SetStyle(ControlStyles.StandardDoubleClick, false);
            BackColor = FooterPaper;
            Cursor = Cursors.Hand;
            TabStop = true;
            AccessibleRole = AccessibleRole.CheckButton;
            slide.Tick += (_, _) =>
            {
                var t = (float)Math.Min(1, (DateTime.UtcNow - slideStart).TotalMilliseconds / 120);
                var eased = 1 - (1 - t) * (1 - t) * (1 - t);
                var target = on ? 1f : 0f;
                pos = slideFrom + (target - slideFrom) * eased;
                if (t >= 1) { pos = target; slide.Stop(); }
                Invalidate();
            };
        }

        /// <summary>Sets the state without animation or a Changed event (for loading the saved value).</summary>
        [System.ComponentModel.DesignerSerializationVisibility(System.ComponentModel.DesignerSerializationVisibility.Hidden)]
        public bool On
        {
            get => on;
            set { on = value; pos = on ? 1 : 0; slide.Stop(); AccessibleDescription = on ? "On" : "Off"; Invalidate(); }
        }

        private void Flip()
        {
            on = !on;
            AccessibleDescription = on ? "On" : "Off";
            if (SystemInformation.UIEffectsEnabled)
            {
                slideFrom = pos;
                slideStart = DateTime.UtcNow;
                slide.Start();
            }
            else pos = on ? 1 : 0;
            Invalidate();
            Changed?.Invoke(on);
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            base.OnMouseDown(e);
            if (e.Button != MouseButtons.Left) return;
            Focus();
            Flip();
        }

        protected override void OnKeyDown(KeyEventArgs e) { base.OnKeyDown(e); if (e.KeyCode is Keys.Space or Keys.Enter) Flip(); }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.Clear(BackColor);
            var fillColor = Color.FromArgb(
                (int)(Off.R + (Green.R - Off.R) * pos), (int)(Off.G + (Green.G - Off.G) * pos), (int)(Off.B + (Green.B - Off.B) * pos));
            using (var pill = Rounded(new Rectangle(0, 0, Width - 1, Height - 1), (Height - 1) / 2))
            using (var fill = new SolidBrush(fillColor))
                g.FillPath(fill, pill);
            var d = Height - 6;
            var x = 3 + (Width - d - 7) * pos;
            using (var knob = new SolidBrush(Color.White))
                g.FillEllipse(knob, x, 3, d, d);
            if (Focused && ShowFocusCues)
                using (var pen = new Pen(Navy, 1.5f))
                using (var ring = Rounded(new Rectangle(0, 0, Width - 1, Height - 1), (Height - 1) / 2))
                    g.DrawPath(pen, ring);
        }

        protected override void OnGotFocus(EventArgs e) { base.OnGotFocus(e); Invalidate(); }
        protected override void OnLostFocus(EventArgs e) { base.OnLostFocus(e); Invalidate(); }

        protected override void Dispose(bool disposing)
        {
            if (disposing) slide.Dispose();
            base.Dispose(disposing);
        }
    }

    /// <summary>Test helper: draws the window in each state to PNGs.</summary>
    public static void DrawPreviews(string dir)
    {
        Directory.CreateDirectory(dir);
        var thread = new Thread(() =>
        {
            var start = DateTimeOffset.UtcNow;
            var offer = new PairingOffer(1, new[] { "192.168.1.20" }, 47822, new string('A', 64), "123456", start.AddMinutes(5));
            var phone = new PairedDevice("d1", "iPhone", "x", start.AddDays(-1));
            void Draw(string name, IReadOnlyList<PairedDevice> paired, FocusSession now, bool pairing, string? task = null, bool buddy = true, (bool, bool, DateTimeOffset?) pause = default)
            {
                var state = Path.Combine(dir, name + "-state");
                Directory.CreateDirectory(state);
                using var form = new HomeWindow(() => offer, () => paired, () => now, state, () => task, () => buddy, null, null, () => pause);
                form.tray.Visible = false;
                form.ShowInTaskbar = false;
                form.StartPosition = FormStartPosition.Manual;
                form.Location = new Point(-4000, -4000);
                form.Show();
                if (pairing) form.ShowPairing();
                form.UpdateState();
                for (var i = 0; i < 5; i++) { Application.DoEvents(); Thread.Sleep(60); }
                using var bmp = new Bitmap(form.Width, form.Height);
                form.DrawToBitmap(bmp, new Rectangle(0, 0, form.Width, form.Height));
                bmp.Save(Path.Combine(dir, name + ".png"));
            }
            var idle = new FocusSession("none", "idle", 0, null, null);
            Draw("home-new", Array.Empty<PairedDevice>(), idle, false);
            Draw("home-pairing", Array.Empty<PairedDevice>(), idle, true);
            Draw("home-idle", new[] { phone }, idle, false);
            Draw("home-session", new[] { phone }, new FocusSession("s", "active", 2700, start.AddMinutes(-20), start.AddMinutes(24).AddSeconds(18)), false, "Studying · library desk");
            var running = new FocusSession("s", "active", 2700, start.AddMinutes(-20), start.AddMinutes(24).AddSeconds(18));
            Draw("home-canpause", new[] { phone }, running, false, "Studying", true, (true, true, null));
            Draw("home-break", new[] { phone }, running, false, "Studying", true, (true, false, start.AddMinutes(4).AddSeconds(12)));
            Draw("home-buddyoff", new[] { phone }, idle, false, null, false);
            Draw("home-locked", new[] { phone }, new FocusSession("s", "active", 2700, start, start.AddMinutes(45)), false);
            // Last: the week row, with sample numbers (Mon..Thu so far, Thursday is today).
            PreviewWeekOpen = true;
            Draw("home-week-empty-open", new[] { phone }, running, false, "Studying");
            WeekStore.Set(new WeekSummary(new[] { 3900, 5400, 6300, 2400, 0, 0, 0 }, 36000, 3, 2400, 3, 30000));
            PreviewWeekOpen = false;
            Draw("home-week-shut", new[] { phone }, running, false, "Studying · library desk");
            PreviewWeekOpen = true;
            Draw("home-week-open", new[] { phone }, running, false, "Studying · library desk");
            WeekStore.Set(new WeekSummary(new[] { 9000, 21600, 3600, 0, 14400, 0, 0 }, 72000, 0, 14400, 4));
            Draw("home-week-long", new[] { phone }, running, false, "Studying");
            PreviewWeekOpen = null;
        });
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
        thread.Join();
    }

    /// <summary>Runs the window on its own UI thread; the web server keeps the main thread.</summary>
    public static void Start(Func<HomeWindow> create, bool hidden)
    {
        var thread = new Thread(() =>
        {
            Application.EnableVisualStyles();
            var form = create();
            if (hidden) { _ = form.Handle; Application.Run(); }
            else Application.Run(form);
        })
        { IsBackground = true };
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
    }
}
