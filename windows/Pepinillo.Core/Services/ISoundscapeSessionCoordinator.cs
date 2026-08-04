using System.Threading.Tasks;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

/// <summary>
/// Drives ambient soundscape playback from focus engine state transitions.
/// Break policy: <b>pause</b> on break start (not duck to 30%) for clarity; resume on work.
/// </summary>
public interface ISoundscapeSessionCoordinator
{
    /// <summary>
    /// React to engine state change. Safe to call from UI thread; never throws.
    /// </summary>
    Task OnSessionStateChangedAsync(SessionState previous, SessionState newState, bool isOnBreak);

    /// <summary>Display name of preferred / last track for Focus chip UI.</summary>
    Task<string?> GetPreferredTrackDisplayNameAsync();
}
