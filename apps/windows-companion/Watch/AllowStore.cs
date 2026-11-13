using System.Text.Json;

namespace LockIn.Companion.Watch;

/// <summary>
/// The apps and sites a person said are for their work, remembered per task. "Studying" can keep
/// YouTube allowed and "Gaming night" can keep Discord, so nobody has to answer the same question
/// twice. It holds names only ("youtube", "discord"), never page titles or contents.
/// </summary>
public sealed class AllowStore
{
    private readonly string path;
    private readonly object gate = new();

    public AllowStore(string dir) => path = Path.Combine(dir, "allowed-apps.json");

    private static string TaskKey(string? task) => (task ?? "").Trim().ToLowerInvariant();

    public HashSet<string> For(string? task)
    {
        lock (gate)
        {
            var all = Read();
            return all.TryGetValue(TaskKey(task), out var list)
                ? new HashSet<string>(list, StringComparer.OrdinalIgnoreCase)
                : new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        }
    }

    public void Add(string? task, string key)
    {
        lock (gate)
        {
            var all = Read();
            var taskKey = TaskKey(task);
            var list = all.TryGetValue(taskKey, out var existing) ? existing.ToList() : new List<string>();
            if (list.Contains(key, StringComparer.OrdinalIgnoreCase)) return;
            list.Add(key);
            all[taskKey] = list.ToArray();
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(path)!);
                File.WriteAllText(path, JsonSerializer.Serialize(all));
            }
            catch (IOException) { /* not remembered next time; this session still keeps it */ }
            catch (UnauthorizedAccessException) { }
        }
    }

    private Dictionary<string, string[]> Read()
    {
        try
        {
            if (File.Exists(path))
                return JsonSerializer.Deserialize<Dictionary<string, string[]>>(File.ReadAllText(path)) ?? new();
        }
        catch (JsonException) { /* a damaged file is treated as empty */ }
        catch (IOException) { }
        return new();
    }
}
