using System;
using System.Diagnostics;
using System.Reflection;
using System.Threading.Tasks;
using Microsoft.Win32;
using Windows.ApplicationModel;

namespace Pepinillo.WinUI.Services;

/// <summary>
/// Startup registration for packaged (StartupTask) and unpackaged (HKCU Run) hosts.
/// </summary>
public sealed class WindowsStartupService : IWindowsStartupService
{
    public const string StartupTaskId = "PepinilloStartup";
    public const string RunValueName = "Pepinillo";

    public string LastStatus { get; private set; } = "Startup: not applied yet";

    public async Task ApplyAsync(bool enabled)
    {
        try
        {
            if (TryIsPackaged())
            {
                await ApplyPackagedAsync(enabled).ConfigureAwait(false);
                return;
            }

            ApplyUnpackagedRunKey(enabled);
        }
        catch (Exception ex)
        {
            LastStatus = $"Startup: failed ({ex.Message})";
            Debug.WriteLine($"[Startup] Apply failed: {ex}");
        }
    }

    private async Task ApplyPackagedAsync(bool enabled)
    {
        try
        {
            var task = await StartupTask.GetAsync(StartupTaskId);
            switch (task.State)
            {
                case StartupTaskState.Disabled:
                    if (enabled)
                    {
                        var result = await task.RequestEnableAsync();
                        LastStatus = result switch
                        {
                            StartupTaskState.Enabled => "Startup: enabled (StartupTask)",
                            StartupTaskState.EnabledByPolicy => "Startup: enabled by policy",
                            StartupTaskState.DisabledByUser =>
                                "Startup: blocked by user — enable Pepinillo in Windows Startup Apps",
                            StartupTaskState.DisabledByPolicy =>
                                "Startup: blocked by policy",
                            _ => $"Startup: state {result}"
                        };
                    }
                    else
                    {
                        LastStatus = "Startup: already disabled";
                    }

                    break;

                case StartupTaskState.Enabled:
                case StartupTaskState.EnabledByPolicy:
                    if (!enabled)
                    {
                        task.Disable();
                        LastStatus = "Startup: disabled (StartupTask)";
                    }
                    else
                    {
                        LastStatus = "Startup: already enabled";
                    }

                    break;

                case StartupTaskState.DisabledByUser:
                    LastStatus = enabled
                        ? "Startup: user disabled Pepinillo in Startup Apps — re-enable there"
                        : "Startup: disabled by user";
                    break;

                case StartupTaskState.DisabledByPolicy:
                    LastStatus = "Startup: blocked by policy";
                    break;

                default:
                    LastStatus = $"Startup: unsupported state {task.State}";
                    break;
            }
        }
        catch (Exception ex)
        {
            // TaskId missing from manifest or API unavailable — fall through to Run key.
            Debug.WriteLine($"[Startup] StartupTask unavailable: {ex.Message}");
            ApplyUnpackagedRunKey(enabled);
        }
    }

    private void ApplyUnpackagedRunKey(bool enabled)
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(
                @"Software\Microsoft\Windows\CurrentVersion\Run",
                writable: true);

            if (key == null)
            {
                LastStatus = "Startup: Run key unavailable (unpackaged fallback failed)";
                return;
            }

            if (enabled)
            {
                var path = ResolveExecutablePath();
                if (string.IsNullOrWhiteSpace(path))
                {
                    LastStatus = "Startup: could not resolve app path for Run key";
                    return;
                }

                // Quote path for spaces; no extra args for a clean cold start.
                key.SetValue(RunValueName, $"\"{path}\"");
                LastStatus = "Startup: enabled (HKCU Run — unpackaged)";
            }
            else
            {
                key.DeleteValue(RunValueName, throwOnMissingValue: false);
                LastStatus = "Startup: disabled (HKCU Run)";
            }
        }
        catch (Exception ex)
        {
            LastStatus = $"Startup: Run key failed ({ex.Message})";
            Debug.WriteLine($"[Startup] Run key failed: {ex}");
        }
    }

    private static string? ResolveExecutablePath()
    {
        try
        {
            var processPath = Environment.ProcessPath;
            if (!string.IsNullOrWhiteSpace(processPath))
                return processPath;
        }
        catch
        {
            // ignore
        }

        try
        {
            return Assembly.GetEntryAssembly()?.Location;
        }
        catch
        {
            return null;
        }
    }

    private static bool TryIsPackaged()
    {
        try
        {
            var _ = Package.Current;
            return true;
        }
        catch
        {
            return false;
        }
    }
}
