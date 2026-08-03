namespace Pepinillo.Core.Models;

public class SoundscapeTrack
{
    public string Id { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Category { get; set; } = "Naturaleza"; // Naturaleza, Urbano, Ambiente, Ruido
    public string AudioFileName { get; set; } = string.Empty;
    public double Volume { get; set; } = 0.5;
    public bool IsPlaying { get; set; }
    public bool IsPremium { get; set; }
}
