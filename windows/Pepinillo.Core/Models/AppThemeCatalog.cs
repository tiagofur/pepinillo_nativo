using System;
using System.Collections.Generic;
using System.Linq;

namespace Pepinillo.Core.Models;

/// <summary>
/// Named app theme entry for picker UI and entitlement checks.
/// Storage values stay stable: System, Light, Dark, Forest, Ocean, Sunset (OLEDBlack aliases Dark).
/// </summary>
public sealed record AppThemeInfo(string Name, bool IsPremium, string DisplayName)
{
    public string PremiumBadge => IsPremium ? "Premium" : string.Empty;
}

/// <summary>
/// Catalog of selectable themes. Free = Classic family (System/Light/Dark + OLEDBlack alias).
/// Premium = Forest, Ocean, Sunset (Pepinillo+ / Everywhere).
/// </summary>
public static class AppThemeCatalog
{
    public static readonly AppThemeInfo System = new("System", false, "System");
    public static readonly AppThemeInfo Light = new("Light", false, "Light");
    public static readonly AppThemeInfo Dark = new("Dark", false, "Dark");
    public static readonly AppThemeInfo Forest = new("Forest", true, "Forest");
    public static readonly AppThemeInfo Ocean = new("Ocean", true, "Ocean");
    public static readonly AppThemeInfo Sunset = new("Sunset", true, "Sunset");

    /// <summary>Picker order for Settings (replaces OLED radio with Sunset).</summary>
    public static IReadOnlyList<AppThemeInfo> All { get; } = new[]
    {
        System,
        Light,
        Dark,
        Forest,
        Ocean,
        Sunset
    };

    public static IReadOnlyList<string> FreeThemeNames { get; } =
        new[] { "System", "Light", "Dark", "OLEDBlack" };

    public static IReadOnlyList<string> PremiumThemeNames { get; } =
        new[] { "Forest", "Ocean", "Sunset" };

    /// <summary>Normalizes legacy OLEDBlack → Dark for UI index; keeps storage-compatible names.</summary>
    public static string Normalize(string? themeName)
    {
        if (string.IsNullOrWhiteSpace(themeName))
            return "System";

        return themeName.Trim() switch
        {
            "OLEDBlack" => "Dark",
            "oledblack" => "Dark",
            "system" => "System",
            "light" => "Light",
            "dark" => "Dark",
            "forest" => "Forest",
            "ocean" => "Ocean",
            "sunset" => "Sunset",
            var n => n
        };
    }

    public static bool IsPremiumTheme(string? themeName)
    {
        var n = Normalize(themeName);
        return PremiumThemeNames.Contains(n, StringComparer.OrdinalIgnoreCase);
    }

    public static bool IsFreeTheme(string? themeName)
    {
        var n = Normalize(themeName);
        // OLEDBlack normalizes to Dark (free). Unknown names are not free.
        return n is "System" or "Light" or "Dark";
    }

    public static int ToIndex(string? themeName)
    {
        var n = Normalize(themeName);
        for (var i = 0; i < All.Count; i++)
        {
            if (string.Equals(All[i].Name, n, StringComparison.OrdinalIgnoreCase))
                return i;
        }

        return 0;
    }

    public static string FromIndex(int index)
    {
        if (index < 0 || index >= All.Count)
            return System.Name;
        return All[index].Name;
    }

    public static AppThemeInfo? Find(string? themeName)
    {
        var n = Normalize(themeName);
        return All.FirstOrDefault(t => string.Equals(t.Name, n, StringComparison.OrdinalIgnoreCase));
    }
}
