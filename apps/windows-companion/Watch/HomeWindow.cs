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
    private static readonly Color Paper = Color.FromArgb(0xF7, 0xF6, 0xF2);
    private static readonly Color FooterPaper = Color.FromArgb(0xF0, 0xEE, 0xE8);
    private static readonly Color Line = Color.FromArgb(0xE6, 0xE2, 0xD9);
    private static readonly Color Ink = Color.FromArgb(0x1C, 0x1C, 0x1E);
    private static readonly Color Soft = Color.FromArgb(0x66, 0x65, 0x61);
    private static readonly Color Track = Color.FromArgb(0xDE, 0xD6, 0xC7);
    private static readonly Color Navy = Color.FromArgb(0x22, 0x33, 0x5C);
    private static readonly Color NavyHover = Color.FromArgb(0x2C, 0x41, 0x73);
    private static readonly Color Amber = Color.FromArgb(0xE5, 0x9E, 0x37);
    private static readonly Color Green = Color.FromArgb(0x2F, 0xA3, 0x6B);
    private static readonly Color Off = Color.FromArgb(0xB9, 0xB6, 0xAE);
    private static readonly Color Caption = Color.FromArgb(0x23, 0x26, 0x2B);

    // Layout in 96-dpi units; scaled by Px() for drawing and placing.
    private const int W = 440, HeroH = 392, RowH = 66, FooterH = 62, Rows = 2;
    private const int RingX = 220, RingY = 132, RingR = 84;

    private readonly Func<PairingOffer> openPairing;
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
    private bool toldAboutTray;

    // What the window shows; set by UpdateState, drawn by OnPaint.
    private string title = "", subtitle = "";
    private bool bigTime;
    private bool onBreak;
    private double ring; // how much of the ring is navy, 0..1
    private string rowTitle = "iPhone", rowStatus = "Not paired";
    private bool rowOn;

    public HomeWindow(Func<PairingOffer> openPairing, Func<IReadOnlyList<PairedDevice>> devices,
        Func<FocusSession> session, string stateDir, Func<string?>? taskName = null,
        Func<bool>? buddyOn = null, Action<bool>? setBuddy = null, Action<string>? removeDevice = null,
        Func<(bool Active, bool CanPause, DateTimeOffset? BreakEnds)>? pauseState = null, Func<bool>? pauseBuddy = null)
    {
        this.removeDevice = removeDevice ?? (_ => { });
        this.pauseState = pauseState ?? (() => (false, false, null));
        this.pauseBuddy = pauseBuddy ?? (() => false);
        this.buddyOn = buddyOn ?? (() => true);
        this.setBuddy = setBuddy ?? (_ => { });
        this.openPairing = openPairing;
        this.devices = devices;
        this.session = session;
        this.taskName = taskName ?? (() => null);
        this.stateDir = stateDir;

        AutoScaleMode = AutoScaleMode.None;
        scale = DeviceDpi / 96f;
        Text = "Nogbox";
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false;
        ClientSize = new Size(Px(W), Px(HeroH + RowH * Rows + FooterH));
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

        var footerTop = Px(HeroH + RowH * Rows);
        startup.Size = new Size(Px(44), Px(24));
        startup.Location = new Point(Px(26), footerTop + (Px(FooterH) - startup.Height) / 2);
        startup.On = Installer.StartsWithWindows();
        startup.AccessibleName = "Start with Windows";
        startup.Changed += on => _ = Task.Run(() => { try { Installer.SetStartWithWindows(on); } catch (Exception) { } });
        Controls.Add(startup);

        quit.Location = new Point(ClientSize.Width - Px(24) - quit.PreferredWidth, footerTop + (Px(FooterH) - quit.PreferredHeight) / 2);
        quit.LinkClicked += (_, _) => Quit();
        Controls.Add(quit);

        // Tray: closing the window keeps Nogbox working.
        tray.Icon = Icon ?? SystemIcons.Application;
        tray.Text = "Nogbox";
        tray.Visible = true;
        var menu = new ContextMenuStrip();
        menu.Items.Add("Open Nogbox", null, (_, _) => ShowFromTray());
        menu.Items.Add("Quit", null, (_, _) => Quit());
        tray.ContextMenuStrip = menu;
        tray.DoubleClick += (_, _) => ShowFromTray();

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

    private void UpdateState()
    {
        var paired = devices();
        var now = DateTimeOffset.UtcNow;
        var current = session();
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
            subtitle = $"Then tap the Nogbox banner. New code in {(int)left.TotalMinutes}:{left.Seconds:00}.";
            ring = 0;
        }
        else if (paired.Count == 0)
        {
            title = "No phone yet";
            subtitle = "Pair your phone to start sessions from it.";
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
        Invalidate(new Rectangle(0, 0, ClientSize.Width, Px(HeroH + RowH * Rows)));
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
            using (var track = new Pen(Track, Pf(3.5f)))
                g.DrawEllipse(track, rect);
            if (ring > 0.001)
            {
                using var arc = new Pen(onBreak ? Amber : Navy, Pf(4.5f)) { StartCap = LineCap.Round, EndCap = LineCap.Round };
                if (ring >= 0.999) g.DrawEllipse(arc, rect);
                else g.DrawArc(arc, rect, -90, (float)(360 * ring));
            }
            if (brain is not null)
            {
                var bw = Pf(122);
                var bh = bw * brain.Height / brain.Width;
                g.DrawImage(brain, c.X - bw / 2, c.Y - bh / 2, bw, bh);
            }
        }

        var top = Px(RingY + RingR + 24);
        using (var titleFont = bigTime ? new Font("Segoe UI Semibold", 27f) : new Font("Segoe UI Semibold", 17f))
        using (var subFont = new Font("Segoe UI", 10.5f))
        {
            var titleH = TextRenderer.MeasureText(g, title, titleFont, Size.Empty, TextFormatFlags.NoPadding).Height;
            TextRenderer.DrawText(g, title, titleFont, new Rectangle(0, top, ClientSize.Width, titleH), Ink,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.NoPadding);
            TextRenderer.DrawText(g, subtitle, subFont, new Rectangle(Px(24), top + titleH + Px(bigTime ? 2 : 6), ClientSize.Width - Px(48), Px(40)), Soft,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.WordBreak | TextFormatFlags.NoPadding);
        }

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

        // Footer
        using (var foot = new SolidBrush(FooterPaper))
            g.FillRectangle(foot, 0, Px(HeroH + RowH * Rows) + 1, ClientSize.Width, Px(FooterH));
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
                tray.ShowBalloonTip(3000, "Nogbox is still on", "It keeps working in the tray. Right-click the icon to quit.", ToolTipIcon.None);
            }
            return;
        }
        base.OnFormClosing(e);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing) { refresh.Dispose(); tray.Dispose(); qr?.Dispose(); brain?.Dispose(); phoneMenu.Dispose(); }
        base.Dispose(disposing);
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
