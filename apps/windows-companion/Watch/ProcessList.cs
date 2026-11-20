using System.Runtime.InteropServices;

namespace LockIn.Companion.Watch;

/// <summary>
/// One snapshot of the running programs: process id to its parent and exe name. It comes from the Windows
/// process list, so no handle is opened on any program (safe next to games with anti-cheat).
/// </summary>
public static class ProcessList
{
    /// <param name="Parent">The id of the program that started it (may be gone).</param>
    /// <param name="Name">The exe name without ".exe", as Windows spells it.</param>
    public readonly record struct Entry(uint Parent, string Name);

    public static Dictionary<uint, Entry> Snapshot()
    {
        var all = new Dictionary<uint, Entry>();
        var snapshot = CreateToolhelp32Snapshot(SnapshotProcesses, 0);
        if (snapshot == IntPtr.Zero || snapshot == new IntPtr(-1)) return all;
        try
        {
            var entry = new ProcessEntry { Size = (uint)Marshal.SizeOf<ProcessEntry>() };
            for (var ok = Process32FirstW(snapshot, ref entry); ok; ok = Process32NextW(snapshot, ref entry))
            {
                var exe = entry.ExeFile;
                all[entry.ProcessId] = new Entry(entry.ParentProcessId, exe.EndsWith(".exe", StringComparison.OrdinalIgnoreCase) ? exe[..^4] : exe);
            }
        }
        finally { CloseHandle(snapshot); }
        return all;
    }

    /// <summary>Lower-case names of up to <paramref name="hops"/> ancestors of <paramref name="pid"/>, nearest first. Stops at a missing parent.</summary>
    public static IReadOnlyList<string> Ancestors(IReadOnlyDictionary<uint, Entry> all, int pid, int hops)
    {
        var names = new List<string>();
        var current = (uint)pid;
        for (var hop = 0; hop < hops; hop++)
        {
            if (!all.TryGetValue(current, out var self) || self.Parent == 0 || !all.TryGetValue(self.Parent, out var parent)) break;
            names.Add(parent.Name.ToLowerInvariant());
            current = self.Parent;
        }
        return names;
    }

    private const uint SnapshotProcesses = 0x2;

    [DllImport("kernel32.dll", SetLastError = true)] private static extern IntPtr CreateToolhelp32Snapshot(uint flags, uint pid);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] private static extern bool Process32FirstW(IntPtr snapshot, ref ProcessEntry entry);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] private static extern bool Process32NextW(IntPtr snapshot, ref ProcessEntry entry);
    [DllImport("kernel32.dll")] private static extern bool CloseHandle(IntPtr handle);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct ProcessEntry
    {
        public uint Size, Usage, ProcessId;
        public IntPtr DefaultHeapId;
        public uint ModuleId, Threads, ParentProcessId;
        public int PriorityClassBase;
        public uint Flags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)] public string ExeFile;
    }
}
