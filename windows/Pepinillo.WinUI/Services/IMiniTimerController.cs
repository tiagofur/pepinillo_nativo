using System;

namespace Pepinillo.WinUI.Services;

/// <summary>
/// Owns the Compact Overlay mini timer window without leaking Window types into Core VMs.
/// </summary>
public interface IMiniTimerController : IDisposable
{
    bool IsOpen { get; }

    void Show();

    void Hide();

    void Toggle();
}
