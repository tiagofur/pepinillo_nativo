using System;
using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using Windows.UI;

namespace Pepinillo.WinUI;

/// <summary>
/// Applies ElementTheme, named-theme accent tokens, and optional Mica backdrop.
/// </summary>
public static class ThemeHelper
{
    /// <summary>
    /// Applies Light/Dark/System element theme, named accent brushes, and Mica when requested.
    /// </summary>
    public static void ApplyTheme(string? themeName, Window? window = null, bool? useMica = null)
    {
        window ??= App.MainWindowInstance;

        var elementTheme = ResolveElementTheme(themeName);
        if (window?.Content is FrameworkElement root)
            root.RequestedTheme = elementTheme;

        ApplyNamedThemeTokens(themeName);

        if (useMica.HasValue)
            ApplyMica(window, useMica.Value);
    }

    /// <summary>
    /// Enables or clears <see cref="MicaBackdrop"/> on the main window.
    /// </summary>
    public static void ApplyMica(Window? window, bool useMica)
    {
        if (window == null)
            return;

        try
        {
            window.SystemBackdrop = useMica ? new MicaBackdrop() : null;
        }
        catch
        {
            // Older OS / DWM without backdrop support — leave default background.
            try
            {
                window.SystemBackdrop = null;
            }
            catch
            {
                // ignore
            }
        }
    }

    public static ElementTheme ResolveElementTheme(string? themeName) => themeName switch
    {
        "Light" => ElementTheme.Light,
        "Dark" => ElementTheme.Dark,
        "Forest" => ElementTheme.Dark,
        "Ocean" => ElementTheme.Dark,
        "Sunset" => ElementTheme.Dark,
        "OLEDBlack" => ElementTheme.Dark,
        _ => ElementTheme.Default // System
    };

    /// <summary>
    /// Updates Application-level Pepinillo accent / paywall brushes for the named theme.
    /// </summary>
    public static void ApplyNamedThemeTokens(string? themeName)
    {
        var resources = Application.Current?.Resources;
        if (resources == null)
            return;

        var accent = ResolveAccentColor(themeName);
        SetBrush(resources, "PepinilloThemeAccentBrush", accent);
        SetBrush(resources, "PepinilloAccentBrush", accent);
        SetColor(resources, "PepinilloThemeAccentColor", accent);

        // Paywall hint stays gold-tinted but slightly shifted per theme family.
        var hint = themeName switch
        {
            "Forest" => ColorFromHex("#A5D6A7"),
            "Ocean" => ColorFromHex("#81D4FA"),
            "Sunset" => ColorFromHex("#FFB74D"),
            _ => ColorFromHex("#C9A227")
        };
        SetBrush(resources, "PepinilloPaywallHintBrush", hint);
        SetBrush(resources, "PepinilloPremiumBadgeBrush", hint);

        if (string.Equals(themeName, "OLEDBlack", StringComparison.OrdinalIgnoreCase) ||
            string.Equals(themeName, "Dark", StringComparison.OrdinalIgnoreCase))
        {
            // Near-black page surface for OLED/Dark classic (best-effort resource override).
            SetBrush(resources, "PepinilloOledSurfaceBrush", ColorFromHex("#000000"));
        }
    }

    private static Color ResolveAccentColor(string? themeName) => themeName switch
    {
        "Forest" => ColorFromHex("#2E7D32"),
        "Ocean" => ColorFromHex("#0277BD"),
        "Sunset" => ColorFromHex("#EF6C00"),
        "Light" => ColorFromHex("#0078D4"),
        "Dark" or "OLEDBlack" => ColorFromHex("#60CDFF"),
        _ => ColorFromHex("#0078D4") // System default-ish
    };

    private static void SetBrush(ResourceDictionary resources, string key, Color color)
    {
        resources[key] = new SolidColorBrush(color);
    }

    private static void SetColor(ResourceDictionary resources, string key, Color color)
    {
        resources[key] = color;
    }

    private static Color ColorFromHex(string hex)
    {
        hex = hex.TrimStart('#');
        if (hex.Length == 6)
        {
            var r = Convert.ToByte(hex[..2], 16);
            var g = Convert.ToByte(hex[2..4], 16);
            var b = Convert.ToByte(hex[4..6], 16);
            return Color.FromArgb(255, r, g, b);
        }

        return Colors.DodgerBlue;
    }
}
