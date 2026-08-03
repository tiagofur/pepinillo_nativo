using System;
using System.IO;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Pepinillo.Core.Data;
using Pepinillo.Core.DependencyInjection;
using Pepinillo.Core.Services;
using Windows.Storage;

namespace Pepinillo.WinUI;

public partial class App : Application
{
    private Window? _mainWindow;

    /// <summary>Application-wide composition root.</summary>
    public static IServiceProvider Services { get; private set; } = null!;

    public static Window? MainWindowInstance { get; private set; }

    public App()
    {
        InitializeComponent();
        Services = ConfigureServices();
    }

    protected override async void OnLaunched(LaunchActivatedEventArgs args)
    {
        await EnsureDatabaseAsync();

        var settingsService = Services.GetRequiredService<ISettingsService>();
        var settings = await settingsService.GetSettingsAsync();

        _mainWindow = new MainWindow();
        MainWindowInstance = _mainWindow;
        ThemeHelper.ApplyTheme(settings.SelectedTheme, _mainWindow);
        _mainWindow.Activate();
    }

    private static IServiceProvider ConfigureServices()
    {
        var services = new ServiceCollection();
        var dbPath = ResolveDatabasePath();
        var directory = Path.GetDirectoryName(dbPath);
        if (!string.IsNullOrEmpty(directory))
            Directory.CreateDirectory(directory);

        services.AddPepinilloCore(dbPath);
        return services.BuildServiceProvider();
    }

    private static string ResolveDatabasePath()
    {
        try
        {
            return Path.Combine(ApplicationData.Current.LocalFolder.Path, "pepinillo.db");
        }
        catch
        {
            var fallback = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Pepinillo",
                "pepinillo.db");
            return fallback;
        }
    }

    private static async System.Threading.Tasks.Task EnsureDatabaseAsync()
    {
        var db = Services.GetRequiredService<PepinilloDbContext>();
        // P0: EnsureCreated for local MVP. Switch to EF migrations before production Store ship.
        await db.Database.EnsureCreatedAsync();
    }
}
