using System.Diagnostics;
using Microsoft.Win32;

/// <summary>
/// Makes the one downloaded file behave like an installed app, for this Windows user only (no admin):
/// the first double-click copies it to %LOCALAPPDATA%\Programs\SwipeLater, adds Start menu and desktop
/// shortcuts, starts it with Windows (in the tray), adds "SwipeLater" to Settings &gt; Apps for uninstalling,
/// and opens the installed copy. Running it again updates the installed copy the same way.
/// </summary>
public static class Installer
{
    public const string AppName = "SwipeLater";
    /// <summary>The app's old name. An install under it is moved over, so the PC never runs two copies.</summary>
    private const string LegacyName = "Nogbox";
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string UninstallRoot = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\";
    private const string UninstallKey = UninstallRoot + AppName;

    public static string InstallDir =>
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", AppName);
    public static string InstalledExe => Path.Combine(InstallDir, AppName + ".exe");
    private static string StartMenuLink =>
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), AppName + ".lnk");
    private static string DesktopLink =>
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), AppName + ".lnk");

    public static string ExtensionDir => Path.Combine(InstallDir, "extension");

    /// <summary>Writes the browser extension next to the app (always the version built into this exe).</summary>
    public static string ExtractExtension()
    {
        Directory.CreateDirectory(ExtensionDir);
        var asm = typeof(Installer).Assembly;
        foreach (var name in new[] { "manifest.json", "background.js", "content.js" })
        {
            using var src = asm.GetManifestResourceStream("ext/" + name) ?? throw new InvalidOperationException(name);
            using var dst = File.Create(Path.Combine(ExtensionDir, name));
            src.CopyTo(dst);
        }
        return ExtensionDir;
    }

    /// <summary>Opens the extension folder and the browser's extensions page so the user can click Load unpacked.</summary>
    public static void OpenExtensionHelp()
    {
        var dir = ExtractExtension();
        // The folder path goes on the clipboard, so the Load unpacked dialog only needs a paste.
        try { System.Windows.Forms.Clipboard.SetText(dir); } catch (Exception) { }
        // Browsers refuse to open their own extensions page from another app, so the window tells the user
        // to type it; the folder path is already on the clipboard for the Load unpacked box.
    }

    /// <summary>True when this process is the installed copy.</summary>
    public static bool IsInstalledCopy(string exePath) =>
        string.Equals(Path.GetFullPath(exePath), Path.GetFullPath(InstalledExe), StringComparison.OrdinalIgnoreCase);

    /// <summary>
    /// Installs (or updates) from the downloaded file and starts the installed copy. Returns false when
    /// installing failed, so the caller can just run from where it is.
    /// </summary>
    public static bool InstallAndLaunch(string exePath)
    {
        try
        {
            // An older copy may be running from the install folder: close it so the file can be replaced.
            foreach (var running in Process.GetProcessesByName(AppName))
            {
                try
                {
                    if (running.Id != Environment.ProcessId && running.MainModule?.FileName is { } file && IsInstalledCopy(file))
                    {
                        running.Kill();
                        running.WaitForExit(5000);
                    }
                }
                catch (Exception) { /* not ours to touch, or already gone */ }
            }
            RemoveLegacyInstall();
            Directory.CreateDirectory(InstallDir);
            File.Copy(exePath, InstalledExe, overwrite: true);
            try { ExtractExtension(); } catch (Exception) { }
            CreateShortcut(StartMenuLink, InstalledExe, "");
            CreateShortcut(DesktopLink, InstalledExe, "");
            SetStartWithWindows(true);
            using (var key = Registry.CurrentUser.CreateSubKey(UninstallKey))
            {
                key.SetValue("DisplayName", AppName);
                key.SetValue("Publisher", AppName);
                key.SetValue("DisplayIcon", InstalledExe);
                key.SetValue("InstallLocation", InstallDir);
                key.SetValue("UninstallString", $"\"{InstalledExe}\" --uninstall");
                key.SetValue("NoModify", 1, RegistryValueKind.DWord);
                key.SetValue("NoRepair", 1, RegistryValueKind.DWord);
            }
            Process.Start(new ProcessStartInfo(InstalledExe) { UseShellExecute = true, WorkingDirectory = InstallDir });
            return true;
        }
        catch (Exception)
        {
            return false;
        }
    }

    /// <summary>
    /// Closes and removes a copy installed under the old name: its process, startup entry, shortcuts,
    /// Settings &gt; Apps entry and folder. Settings and pairing live in %LOCALAPPDATA%\LockIn and stay.
    /// </summary>
    private static void RemoveLegacyInstall()
    {
        var legacyDir = Path.Combine(Path.GetDirectoryName(InstallDir)!, LegacyName);
        var legacyExe = Path.Combine(legacyDir, LegacyName + ".exe");
        foreach (var running in Process.GetProcessesByName(LegacyName))
        {
            try
            {
                if (running.Id != Environment.ProcessId && running.MainModule?.FileName is { } file
                    && string.Equals(Path.GetFullPath(file), Path.GetFullPath(legacyExe), StringComparison.OrdinalIgnoreCase))
                {
                    running.Kill();
                    running.WaitForExit(5000);
                }
            }
            catch (Exception) { }
        }
        try
        {
            using var run = Registry.CurrentUser.CreateSubKey(RunKey);
            run.DeleteValue(LegacyName, throwOnMissingValue: false);
        }
        catch (Exception) { }
        foreach (var folder in new[] { Environment.SpecialFolder.Programs, Environment.SpecialFolder.DesktopDirectory })
            try { var link = Path.Combine(Environment.GetFolderPath(folder), LegacyName + ".lnk"); if (File.Exists(link)) File.Delete(link); } catch (Exception) { }
        try { Registry.CurrentUser.DeleteSubKeyTree(UninstallRoot + LegacyName, throwOnMissingSubKey: false); } catch (Exception) { }
        try { if (Directory.Exists(legacyDir)) Directory.Delete(legacyDir, recursive: true); } catch (Exception) { /* a locked file: harmless leftovers */ }
    }

    public static bool StartsWithWindows()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKey);
        return key?.GetValue(AppName) is string;
    }

    public static void SetStartWithWindows(bool on)
    {
        using var key = Registry.CurrentUser.CreateSubKey(RunKey);
        if (on) key.SetValue(AppName, $"\"{InstalledExe}\" --tray");
        else key.DeleteValue(AppName, throwOnMissingValue: false);
    }

    /// <summary>Removes everything the installer added, then deletes the folder once this program has exited.</summary>
    public static void Uninstall(Action unregisterBrowsers)
    {
        try { unregisterBrowsers(); } catch (Exception) { }
        SetStartWithWindows(false);
        foreach (var link in new[] { StartMenuLink, DesktopLink })
            try { if (File.Exists(link)) File.Delete(link); } catch (Exception) { }
        try { Registry.CurrentUser.DeleteSubKeyTree(UninstallKey, throwOnMissingSubKey: false); } catch (Exception) { }
        try
        {
            // The running exe cannot delete itself: a short-lived cmd waits a moment, then removes the folder.
            Process.Start(new ProcessStartInfo("cmd.exe", $"/c timeout /t 2 /nobreak >nul & rmdir /s /q \"{InstallDir}\"")
            { CreateNoWindow = true, UseShellExecute = false });
        }
        catch (Exception) { }
    }

    private static void CreateShortcut(string linkPath, string target, string arguments)
    {
        var shellType = Type.GetTypeFromProgID("WScript.Shell") ?? throw new InvalidOperationException("No shell");
        dynamic shell = Activator.CreateInstance(shellType)!;
        try
        {
            dynamic link = shell.CreateShortcut(linkPath);
            link.TargetPath = target;
            link.Arguments = arguments;
            link.WorkingDirectory = Path.GetDirectoryName(target);
            link.IconLocation = target + ",0";
            link.Description = "SwipeLater focus buddy";
            link.Save();
        }
        finally
        {
            System.Runtime.InteropServices.Marshal.FinalReleaseComObject(shell);
        }
    }
}
