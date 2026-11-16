using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;
using QRCoder;

namespace LockIn.Companion.Watch;

/// <summary>
/// The PC app's one window: is it running, is a phone paired (with a QR code to pair right here),
/// what the current session is, and the browser link. Closing it keeps Nogbox running in the tray.
/// Same printed look as the phone: grey newsprint, riso blue, a sunflower edge on the main button.
/// </summary>
public sealed class HomeWindow : Form
{
    public static readonly Color Paper = Color.FromArgb(0xE7, 0xE8, 0xE3);
    public static readonly Color Card = Color.FromArgb(0xF3, 0xF4, 0xF0);
    public static readonly Color Ink = Color.FromArgb(0x1B, 0x1B, 0x1B);
    public static readonly Color Soft = Color.FromArgb(0x55, 0x58, 0x52);
    public static readonly Color Blue = Color.FromArgb(0x32, 0x55, 0xA4);
    public static readonly Color Sun = Color.FromArgb(0xFF, 0xB5, 0x11);

    private readonly Func<PairingOffer> openPairing;
    private readonly Func<IReadOnlyList<PairedDevice>> devices;
    private readonly Func<FocusSession> session;
    private readonly Func<string> connectBrowsers;
    private readonly string stateDir;
    private readonly Func<(bool Alive, bool Incognito)> browserStatus;
    private readonly CardPanel guide = new("SET UP  ·  2 STEPS");
    private readonly StepRow stepInstall = new(1, "Install Nogbox");
    private readonly StepRow stepPair = new(2, "Pair your phone");
    private readonly StepRow stepBrowser = new(3, "Connect your browser (optional)");
    private CardPanel? nowCard;
    private CardPanel? browserCard;
    private readonly LinkLabel skipBrowser = new() { Text = "Skip this step", AutoSize = true, LinkColor = Soft, ActiveLinkColor = Ink, Margin = new Padding(34, 0, 0, 4) };

    private readonly Label phoneLine = Line();
    private readonly PictureBox qr = new() { Size = new Size(220, 220), SizeMode = PictureBoxSizeMode.Zoom, Visible = false, Margin = new Padding(0, 10, 0, 4) };
    private readonly Label qrHint = Line(Soft, 10);
    private readonly PrimaryButton pairButton = new("Pair my phone");
    private readonly Label sessionTitle = new() { AutoSize = true, Font = new Font("Segoe UI", 16, FontStyle.Bold), ForeColor = Ink, Margin = new Padding(0, 2, 0, 0) };
    private readonly Label sessionLine = Line(Soft, 10);
    private readonly Label browserLine = Line(Soft, 10);
    private readonly NotifyIcon tray = new();
    private readonly System.Windows.Forms.Timer refresh = new() { Interval = 1000 };
    private DateTimeOffset? qrUntil;
    private bool quitting;
    private bool toldAboutTray;

    public HomeWindow(Func<PairingOffer> openPairing, Func<IReadOnlyList<PairedDevice>> devices,
        Func<FocusSession> session, Func<string> connectBrowsers, string stateDir,
        Func<(bool Alive, bool Incognito)>? browserStatus = null)
    {
        this.browserStatus = browserStatus ?? (() => (false, false));
        this.openPairing = openPairing;
        this.devices = devices;
        this.session = session;
        this.connectBrowsers = connectBrowsers;
        this.stateDir = stateDir;

        Text = "Nogbox";
        ClientSize = new Size(420, 820);
        MinimumSize = new Size(400, 520);
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Paper;
        ForeColor = Ink;
        Font = new Font("Segoe UI", 11);
        AutoScaleMode = AutoScaleMode.Dpi;
        var brain = LoadBrain();
        if (brain is not null) Icon = Icon.FromHandle(new Bitmap(brain, new Size(64, 64)).GetHicon());

        var page = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false,
            AutoScroll = true, Padding = new Padding(22, 18, 22, 18), BackColor = Paper
        };
        Controls.Add(page);

        // Header: the brain, the name, and one line that says it is working.
        var header = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Margin = new Padding(0, 0, 0, 14) };
        if (brain is not null)
            header.Controls.Add(new PictureBox { Image = brain, SizeMode = PictureBoxSizeMode.Zoom, Size = new Size(78, 64), Margin = new Padding(0, 0, 10, 0), AccessibleRole = AccessibleRole.Graphic, AccessibleName = "Nogbox brain" });
        var titles = new FlowLayoutPanel { AutoSize = true, FlowDirection = FlowDirection.TopDown, WrapContents = false, Margin = new Padding(0, 4, 0, 0) };
        titles.Controls.Add(new Label { Text = "Nogbox", AutoSize = true, Font = new Font("Segoe UI Black", 22), ForeColor = Ink, Margin = Padding.Empty });
        titles.Controls.Add(new Label { Text = "●  Running on this PC", AutoSize = true, Font = new Font("Segoe UI", 10, FontStyle.Bold), ForeColor = Color.FromArgb(0x2E, 0x7D, 0x4F), Margin = Padding.Empty });
        header.Controls.Add(titles);
        page.Controls.Add(header);

        // Setup guide: ticks itself off from the real state (paired phone, extension heartbeat).
        stepInstall.State = StepState.Done;
        guide.Body.Controls.Add(stepInstall);
        guide.Body.Controls.Add(stepPair);
        skipBrowser.LinkClicked += (_, _) =>
        {
            try { File.WriteAllText(Path.Combine(this.stateDir, "setup-browser-skipped"), ""); } catch (Exception) { }
            UpdateState();
        };
        guide.Visible = !File.Exists(Path.Combine(stateDir, "setup-done"));
        page.Controls.Add(guide);

        // Phone
        var phone = new CardPanel("PHONE");
        phone.Body.Controls.Add(phoneLine);
        phone.Body.Controls.Add(qr);
        phone.Body.Controls.Add(qrHint);
        pairButton.Click += (_, _) => ShowPairing();
        phone.Body.Controls.Add(pairButton);
        page.Controls.Add(phone);

        // Session
        var now = nowCard = new CardPanel("RIGHT NOW");
        now.Body.Controls.Add(sessionTitle);
        now.Body.Controls.Add(sessionLine);
        page.Controls.Add(now);

        // Browser
        var browser = browserCard = new CardPanel("BROWSERS");
        browserLine.Text = "Nogbox watches Chrome, Edge, Brave and Firefox by itself. Nothing to set up.";
        browser.Body.Controls.Add(browserLine);
        var connect = new SecondaryButton("Add Save for later (optional)");
        connect.Click += (_, _) =>
        {
            try
            {
                connectBrowsers();
                Installer.OpenExtensionHelp();
                browserLine.Text = "Folder copied. In Chrome, type chrome://extensions in the address bar. Turn on Developer mode, press Load unpacked, press Ctrl+V, press Select Folder.";
            }
            catch (Exception) { browserLine.Text = "Couldn't connect. Try again."; }
        };
        browser.Body.Controls.Add(connect);
        page.Controls.Add(browser);

        // Footer
        var footer = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Margin = new Padding(0, 6, 0, 0) };
        var later = new LinkLabel { Text = "Saved for later", AutoSize = true, LinkColor = Blue, ActiveLinkColor = Ink, Margin = new Padding(0, 12, 18, 0) };
        later.LinkClicked += (_, _) => new LaterWindow(new LaterStore(this.stateDir)).Show();
        var quit = new LinkLabel { Text = "Quit Nogbox", AutoSize = true, LinkColor = Soft, ActiveLinkColor = Ink, Margin = new Padding(0, 12, 0, 0) };
        quit.LinkClicked += (_, _) => Quit();
        footer.Controls.Add(later);
        footer.Controls.Add(quit);
        page.Controls.Add(footer);
        var startup = new CheckBox
        {
            Text = "Start Nogbox with Windows", AutoSize = true, ForeColor = Soft, Margin = new Padding(0, 14, 0, 0),
            Checked = Installer.StartsWithWindows()
        };
        startup.CheckedChanged += (_, _) => { try { Installer.SetStartWithWindows(startup.Checked); } catch (Exception) { } };
        page.Controls.Add(startup);

        page.ClientSizeChanged += (_, _) =>
        {
            var width = page.ClientSize.Width - page.Padding.Horizontal;
            foreach (var card in page.Controls.OfType<CardPanel>()) card.Width = width;
        };

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

    private static Bitmap? LoadBrain()
    {
        using var stream = typeof(HomeWindow).Assembly.GetManifestResourceStream("LockIn.Companion.Watch.Assets.BrainExact.png");
        if (stream is null) return null;
        using var image = Image.FromStream(stream);
        return new Bitmap(image);
    }

    private static Label Line(Color? color = null, float size = 11) => new()
    {
        AutoSize = true, MaximumSize = new Size(330, 0), ForeColor = color ?? Ink,
        Font = new Font("Segoe UI", size), Margin = new Padding(0, 2, 0, 6)
    };

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
            qr.Image = Image.FromStream(ms);
            qr.Visible = true;
            qrUntil = offer.ExpiresAt;
            pairButton.Text = "New code";
        }
        catch (Exception)
        {
            qrHint.Text = "Couldn't make a pairing code. Try again.";
        }
        UpdateState();
    }

    private void UpdateState()
    {
        var paired = devices();
        var now = DateTimeOffset.UtcNow;
        if (qrUntil is { } until && now < until)
        {
            var left = until - now;
            phoneLine.Text = "Point your iPhone Camera at this and tap the Nogbox banner.";
            qrHint.Text = $"Works for {(int)left.TotalMinutes}:{left.Seconds:00} and one phone.";
            qrHint.Visible = true;
        }
        else
        {
            if (qr.Visible) { qr.Visible = false; pairButton.Text = paired.Count == 0 ? "Pair my phone" : "Pair another phone"; }
            qrUntil = null;
            qrHint.Visible = false;
            phoneLine.Text = paired.Count == 0
                ? "No phone paired yet."
                : $"Paired with {paired[^1].Name}" + (paired.Count > 1 ? $" and {paired.Count - 1} more." : ".");
            if (paired.Count > 0 && pairButton.Text == "Pair my phone") pairButton.Text = "Pair another phone";
        }

        UpdateGuide(paired.Count > 0);

        var current = session();
        if (current.State == "active" && current.EndsAt is { } ends)
        {
            var left = ends - now;
            if (left < TimeSpan.Zero) left = TimeSpan.Zero;
            sessionTitle.Text = $"Focusing · {(int)left.TotalMinutes}:{left.Seconds:00} left";
            sessionLine.Text = "Distracting apps get a nudge from the buddy.";
        }
        else
        {
            sessionTitle.Text = "No session";
            sessionLine.Text = "Start one on your phone. This PC follows.";
        }
    }

    private void UpdateGuide(bool paired)
    {
        if (!guide.Visible) return;
        stepPair.State = paired ? StepState.Done : StepState.Now;
        stepPair.Detail = paired ? "" : "Press PAIR MY PHONE below. Point your iPhone Camera at the code. Tap the Nogbox banner.";
        guide.Heading = paired ? "ALL SET" : "SET UP  ·  2 STEPS";
        if (paired)
            try { File.WriteAllText(Path.Combine(stateDir, "setup-done"), ""); } catch (Exception) { }
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
        if (disposing) { refresh.Dispose(); tray.Dispose(); }
        base.Dispose(disposing);
    }

    /// <summary>A rounded card with a small spaced-out heading.</summary>
    private sealed class CardPanel : Panel
    {
        public FlowLayoutPanel Body { get; } = new()
        {
            AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, FlowDirection = FlowDirection.TopDown, WrapContents = false,
            Location = new Point(18, 40), BackColor = Color.Transparent
        };

        private readonly Label headingLabel;
        [System.ComponentModel.DesignerSerializationVisibility(System.ComponentModel.DesignerSerializationVisibility.Hidden)] public string Heading { get => headingLabel.Text; set => headingLabel.Text = value; }

        public CardPanel(string heading)
        {
            DoubleBuffered = true;
            BackColor = Paper;
            Width = 376;
            Margin = new Padding(0, 0, 0, 14);
            headingLabel = new Label { Text = heading, AutoSize = true, UseMnemonic = false, Location = new Point(18, 14), Font = new Font("Consolas", 9, FontStyle.Bold), ForeColor = Soft, BackColor = Card };
            Controls.Add(headingLabel);
            Controls.Add(Body);
            Body.SizeChanged += (_, _) => Height = Body.Bottom + 14;
            Body.BackColor = Card;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            using var path = Rounded(new Rectangle(0, 0, Width - 1, Height - 1), 16);
            using var fill = new SolidBrush(Card);
            e.Graphics.FillPath(fill, path);
        }
    }

    private enum StepState { Later, Now, Done, Skipped }

    /// <summary>One line of the setup guide: a numbered dot (blue now, green tick done) and what to do.</summary>
    private sealed class StepRow : Control
    {
        private static readonly Color Green = Color.FromArgb(0x2E, 0x7D, 0x4F);
        private readonly int number;
        private StepState state = StepState.Later;
        private string detail = "";
        private readonly Font titleFont = new("Segoe UI", 11, FontStyle.Bold);
        private readonly Font doneFont = new("Segoe UI", 11, FontStyle.Bold | FontStyle.Strikeout);
        private readonly Font detailFont = new("Segoe UI", 10);

        public StepRow(int number, string title)
        {
            this.number = number;
            Text = title;
            DoubleBuffered = true;
            BackColor = Card;
            Width = 330;
            Margin = new Padding(0, 2, 0, 6);
            AccessibleRole = AccessibleRole.StaticText;
            Relayout();
        }

        [System.ComponentModel.DesignerSerializationVisibility(System.ComponentModel.DesignerSerializationVisibility.Hidden)] public StepState State { get => state; set { if (state == value) return; state = value; Relayout(); } }
        [System.ComponentModel.DesignerSerializationVisibility(System.ComponentModel.DesignerSerializationVisibility.Hidden)] public string Detail { get => detail; set { if (detail == value) return; detail = value; Relayout(); } }

        private void Relayout()
        {
            var h = 30;
            if (detail.Length > 0)
                h += TextRenderer.MeasureText(detail, detailFont, new Size(Width - 40, 0), TextFormatFlags.WordBreak).Height + 4;
            Height = h;
            AccessibleName = $"Step {number}: {Text}. " + state switch
            {
                StepState.Done => "Done.",
                StepState.Now => "Do this now. " + detail,
                StepState.Skipped => "Skipped.",
                _ => "Later."
            };
            Invalidate();
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.Clear(Card);
            var dot = new Rectangle(1, 2, 24, 24);
            var fill = state switch { StepState.Done => Green, StepState.Now => Blue, _ => Card };
            using (var b = new SolidBrush(fill)) g.FillEllipse(b, dot);
            if (state is StepState.Later or StepState.Skipped)
                using (var pen = new Pen(Color.FromArgb(0xB4, 0xB7, 0xB0), 2)) g.DrawEllipse(pen, dot);
            var mark = state == StepState.Done ? "✓" : number.ToString();
            var markColor = state is StepState.Done or StepState.Now ? Color.White : Soft;
            TextRenderer.DrawText(g, mark, titleFont, dot, markColor, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
            var titleColor = state == StepState.Now ? Ink : Soft;
            TextRenderer.DrawText(g, Text, titleFont, new Rectangle(34, 2, Width - 34, 24),
                titleColor, TextFormatFlags.Left | TextFormatFlags.VerticalCenter);
            if (detail.Length > 0)
                TextRenderer.DrawText(g, detail, detailFont, new Rectangle(34, 30, Width - 40, Height - 30), Ink, TextFormatFlags.WordBreak);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) { titleFont.Dispose(); doneFont.Dispose(); detailFont.Dispose(); }
            base.Dispose(disposing);
        }
    }

    /// <summary>The main action: riso blue with a sunflower edge, like the phone's LOCK IN button.</summary>
    private sealed class PrimaryButton : Button
    {
        public PrimaryButton(string text)
        {
            Text = text;
            Size = new Size(220, 50);
            FlatStyle = FlatStyle.Flat;
            FlatAppearance.BorderSize = 0;
            FlatAppearance.MouseOverBackColor = Card;
            FlatAppearance.MouseDownBackColor = Card;
            BackColor = Card;
            Font = new Font("Segoe UI", 11, FontStyle.Bold);
            Cursor = Cursors.Hand;
            Margin = new Padding(0, 8, 0, 2);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.Clear(Card);
            using var shadow = Rounded(new Rectangle(4, 4, Width - 6, Height - 6), 14);
            using var face = Rounded(new Rectangle(0, 0, Width - 5, Height - 5), 14);
            using (var sun = new SolidBrush(Sun)) g.FillPath(sun, shadow);
            using (var blue = new SolidBrush(ClientRectangle.Contains(PointToClient(MousePosition)) ? Color.FromArgb(0x29, 0x47, 0x8C) : Blue)) g.FillPath(blue, face);
            TextRenderer.DrawText(g, Text.ToUpperInvariant(), Font, new Rectangle(0, 0, Width - 5, Height - 5), Color.White,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
        }

        protected override void OnMouseEnter(EventArgs e) { base.OnMouseEnter(e); Invalidate(); }
        protected override void OnMouseLeave(EventArgs e) { base.OnMouseLeave(e); Invalidate(); }
    }

    /// <summary>A quiet outlined button.</summary>
    private sealed class SecondaryButton : Button
    {
        public SecondaryButton(string text)
        {
            Text = text;
            AutoSize = true;
            MinimumSize = new Size(0, 44);
            Padding = new Padding(10, 0, 10, 0);
            FlatStyle = FlatStyle.Flat;
            FlatAppearance.BorderColor = Ink;
            FlatAppearance.BorderSize = 2;
            BackColor = Card;
            ForeColor = Ink;
            Font = new Font("Segoe UI", 10, FontStyle.Bold);
            Cursor = Cursors.Hand;
            Margin = new Padding(0, 6, 0, 2);
        }
    }

    private static GraphicsPath Rounded(Rectangle r, int radius)
    {
        var d = radius * 2;
        var path = new GraphicsPath();
        path.AddArc(r.X, r.Y, d, d, 180, 90);
        path.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        path.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        path.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        path.CloseFigure();
        return path;
    }

    /// <summary>Test helper: draws the window in three states (new, pairing, paired with a session) to PNGs.</summary>
    public static void DrawPreviews(string dir)
    {
        Directory.CreateDirectory(dir);
        var thread = new Thread(() =>
        {
            var start = DateTimeOffset.UtcNow;
            var offer = new PairingOffer(1, new[] { "192.168.1.20" }, 47822, new string('A', 64), "123456", start.AddMinutes(5));
            var phone = new PairedDevice("d1", "Brandon's iPhone", "x", start);
            void Draw(string name, IReadOnlyList<PairedDevice> paired, FocusSession now, bool pairing, (bool, bool) browser = default)
            {
                var state = Path.Combine(dir, name + "-state");
                if (Directory.Exists(state)) Directory.Delete(state, true);
                Directory.CreateDirectory(state);
                using var form = new HomeWindow(() => offer, () => paired, () => now, () => "", state, () => browser);
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
            Draw("home-browser", new[] { phone }, idle, false);
            Draw("home-incognito", new[] { phone }, idle, false, (true, false));
            Draw("home-session", new[] { phone }, new FocusSession("s", "active", 1500, start, start.AddMinutes(18).AddSeconds(42)), false, (true, true));
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
