using System.Threading.Tasks;

namespace Pepinillo.WinUI.Services;

/// <summary>
/// Registers or clears "launch Pepinillo when Windows starts".
/// Packaged: <c>Windows.ApplicationModel.StartupTask</c>.
/// Unpackaged: best-effort HKCU Run key (or documented no-op if unavailable).
/// </summary>
public interface IWindowsStartupService
{
    /// <summary>Last apply result / diagnostic for Settings UI.</summary>
    string LastStatus { get; }

    /// <summary>
    /// Apply the desired enabled state. Never throws to callers for OS limitations.
    /// </summary>
    Task ApplyAsync(bool enabled);
}
