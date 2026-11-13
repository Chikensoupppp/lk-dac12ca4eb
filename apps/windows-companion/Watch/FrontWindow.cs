using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

namespace LockIn.Companion.Watch;

/// <summary>
/// Reads the window the user is looking at. Only reads names; never reads what is on screen.
/// </summary>
public static class FrontWindow
{
    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

    public sealed record Snapshot(IntPtr Handle, int ProcessId, string Process, string Title);

    public static Snapshot? Current()
    {
        var handle = GetForegroundWindow();
        if (handle == IntPtr.Zero) return null;
        GetWindowThreadProcessId(handle, out var pid);
        var sb = new StringBuilder(256);
        GetWindowText(handle, sb, sb.Capacity);
        string process;
        try { process = Process.GetProcessById((int)pid).ProcessName; }
        catch (Exception) { process = ""; }
        return new Snapshot(handle, (int)pid, process, sb.ToString());
    }
}
