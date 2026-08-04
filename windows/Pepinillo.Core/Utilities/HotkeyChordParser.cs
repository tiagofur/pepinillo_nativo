using System;
using System.Text;

namespace Pepinillo.Core.Utilities;

/// <summary>
/// Parsed global-hotkey chord (modifiers + single alphanumeric key).
/// Platform hosts map this to OS-specific register APIs (e.g. Win32 RegisterHotKey).
/// </summary>
public readonly record struct HotkeyChord(bool Win, bool Shift, bool Ctrl, bool Alt, char Key)
{
    public bool HasModifier => Win || Shift || Ctrl || Alt;

    public string Format()
    {
        var sb = new StringBuilder();
        if (Win) Append(sb, "Win");
        if (Ctrl) Append(sb, "Ctrl");
        if (Alt) Append(sb, "Alt");
        if (Shift) Append(sb, "Shift");
        Append(sb, char.ToUpperInvariant(Key).ToString());
        return sb.ToString();
    }

    private static void Append(StringBuilder sb, string part)
    {
        if (sb.Length > 0)
            sb.Append('+');
        sb.Append(part);
    }
}

/// <summary>
/// Parses simple chords like <c>Win+Shift+P</c>, <c>Ctrl+Alt+1</c>.
/// Requires at least one modifier and a single A–Z or 0–9 key.
/// </summary>
public static class HotkeyChordParser
{
    public const string DefaultPlayPause = "Win+Shift+P";
    public const string DefaultSkip = "Win+Shift+S";
    public const string DefaultMiniTimer = "Win+Shift+M";

    /// <summary>
    /// Tries to parse <paramref name="text"/>. Returns false for null/empty/invalid chords.
    /// </summary>
    public static bool TryParse(string? text, out HotkeyChord chord)
    {
        chord = default;
        if (string.IsNullOrWhiteSpace(text))
            return false;

        var win = false;
        var shift = false;
        var ctrl = false;
        var alt = false;
        char key = '\0';

        var parts = text.Split('+', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (parts.Length < 2)
            return false;

        foreach (var part in parts)
        {
            switch (part.ToLowerInvariant())
            {
                case "win":
                case "windows":
                case "meta":
                case "cmd":
                    win = true;
                    break;
                case "shift":
                    shift = true;
                    break;
                case "ctrl":
                case "control":
                    ctrl = true;
                    break;
                case "alt":
                case "menu":
                    alt = true;
                    break;
                default:
                    if (part.Length == 1)
                    {
                        var ch = char.ToUpperInvariant(part[0]);
                        if (ch is >= 'A' and <= 'Z' or >= '0' and <= '9')
                        {
                            if (key != '\0')
                                return false; // only one key allowed
                            key = ch;
                            break;
                        }
                    }

                    return false;
            }
        }

        if (key == '\0')
            return false;
        if (!win && !shift && !ctrl && !alt)
            return false;

        chord = new HotkeyChord(win, shift, ctrl, alt, key);
        return true;
    }

    /// <summary>
    /// Parses or returns the fallback string when parse fails.
    /// </summary>
    public static string NormalizeOrDefault(string? text, string fallback)
    {
        if (TryParse(text, out var chord))
            return chord.Format();
        return fallback;
    }

    /// <summary>
    /// Returns true when the chord string is valid (or empty is treated as invalid).
    /// </summary>
    public static bool IsValid(string? text) => TryParse(text, out _);
}
