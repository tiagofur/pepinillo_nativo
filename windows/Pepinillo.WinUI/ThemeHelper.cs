using Microsoft.UI.Xaml;

namespace Pepinillo.WinUI;

public static class ThemeHelper
{
    /// <summary>
    /// Applies Light / Dark / System (and maps accent themes to Dark for P0).
    /// </summary>
    public static void ApplyTheme(string? themeName, Window? window = null)
    {
        var elementTheme = themeName switch
        {
            "Light" => ElementTheme.Light,
            "Dark" => ElementTheme.Dark,
            "Forest" => ElementTheme.Dark,
            "Ocean" => ElementTheme.Dark,
            "Sunset" => ElementTheme.Dark,
            "OLEDBlack" => ElementTheme.Dark,
            _ => ElementTheme.Default // System
        };

        window ??= App.MainWindowInstance;
        if (window?.Content is FrameworkElement root)
            root.RequestedTheme = elementTheme;
    }
}
