using System.Diagnostics;
using System.Drawing;
using System.Windows.Forms;

namespace LockIn.Companion.Watch;

public sealed class LaterWindow : Form
{
    private readonly LaterStore store;
    private readonly FlowLayoutPanel list = new() { Dock = DockStyle.Fill, AutoScroll = true, FlowDirection = FlowDirection.TopDown, WrapContents = false, Padding = new Padding(16) };

    public LaterWindow(LaterStore store)
    {
        this.store = store;
        Text = "Saved for later";
        Size = new Size(540, 430);
        MinimumSize = new Size(400, 280);
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Color.FromArgb(247, 243, 232);
        ForeColor = Color.FromArgb(27, 27, 27);
        Font = new Font("Segoe UI", 11);
        Controls.Add(list);
        list.ClientSizeChanged += (_, _) => SizeRows();
        RefreshItems();
    }

    private void RefreshItems()
    {
        foreach (Control control in list.Controls.Cast<Control>().ToArray()) control.Dispose();
        var items = store.Read();
        list.Controls.Add(new Label { Text = "Saved for later", Font = new Font("Segoe UI", 20, FontStyle.Bold), AutoSize = true, Margin = new Padding(0, 0, 0, 6) });
        list.Controls.Add(new Label { Text = items.Count == 0 ? "Nothing saved yet." : "Ready when you are.", AutoSize = true, ForeColor = Color.FromArgb(87, 90, 85), Margin = new Padding(0, 0, 0, 24) });
        foreach (var item in items)
        {
            var row = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Margin = new Padding(0, 0, 0, 12) };
            var uri = new Uri(item.Url);
            var link = new LinkLabel { Text = uri.Host + uri.PathAndQuery, Width = 290, Height = 48, AutoEllipsis = true, LinkColor = Color.FromArgb(50, 85, 164), ActiveLinkColor = Color.FromArgb(27, 27, 27), VisitedLinkColor = Color.FromArgb(50, 85, 164), AccessibleName = "Open " + item.Url };
            link.LinkClicked += (_, _) =>
            {
                try { if (LaterStore.CleanUrl(item.Url) is { } url) Process.Start(new ProcessStartInfo(url) { UseShellExecute = true }); }
                catch (Exception e) when (e is System.ComponentModel.Win32Exception or InvalidOperationException) { link.Text = "Couldn't open. Try again."; }
            };
            var remove = new Button { Text = "Remove", Width = 90, Height = 40, FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(50, 85, 164), ForeColor = Color.White };
            remove.FlatAppearance.BorderSize = 0;
            remove.Click += (_, _) => { if (store.Remove(item.Url)) RefreshItems(); else remove.Text = "Try again"; };
            row.Controls.Add(link);
            row.Controls.Add(remove);
            list.Controls.Add(row);
        }
        SizeRows();
    }

    private void SizeRows()
    {
        foreach (var row in list.Controls.OfType<FlowLayoutPanel>())
            row.Controls[0].Width = Math.Max(140, list.ClientSize.Width - 150);
    }
}
