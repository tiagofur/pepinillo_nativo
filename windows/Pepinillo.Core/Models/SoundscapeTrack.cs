namespace Pepinillo.Core.Models;

public class SoundscapeTrack
{
    public string Id { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Category { get; set; } = "Nature"; // Nature, Urban, Ambient, Noise
    public string AudioFileName { get; set; } = string.Empty;
    public double Volume { get; set; } = 0.5;
    public bool IsPlaying { get; set; }
    public bool IsPremium { get; set; }

    /// <summary>Empty when free — avoids Visibility converters in WinUI x:Bind.</summary>
    public string PremiumLabel => IsPremium ? "Premium" : string.Empty;
}
