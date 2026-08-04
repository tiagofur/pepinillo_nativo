using System;
using System.IO;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Pepinillo.Core.Data;
using Pepinillo.Core.DependencyInjection;
using Pepinillo.Core.Services;
using Pepinillo.WinUI.Services;
using Windows.Storage;

namespace Pepinillo.WinUI;

public partial class App : Application
{
    private Window? _mainWindow;
    private DesktopShellCoordinator? _shell;

    /// <summary>Application-wide composition root.</summary>
    public static IServiceProvider Services { get; private set; } = null!;

    public static Window? MainWindowInstance { get; private set; }

    public App()
    {
        InitializeComponent();
        Services = ConfigureServices();
        UnhandledException += (_, e) =>
        {
            System.Diagnostics.Debug.WriteLine($"Unhandled: {e.Exception}");
            e.Handled = true;
        };
    }

    protected override async void OnLaunched(LaunchActivatedEventArgs args)
    {
        await EnsureDatabaseAsync();

        try
        {
            var backend = Services.GetRequiredService<IBackendApiClient>();
            await backend.InitializeAsync();
        }
        catch
        {
            // Offline / token restore failures must not block launch.
        }

        try
        {
            // Resolve Store / backend entitlements so free-tier gates match purchase state.
            var entitlements = Services.GetRequiredService<IEntitlementService>();
            await entitlements.RefreshAsync();
        }
        catch
        {
            // Stay on Free default if commerce is unavailable.
        }

        var settingsService = Services.GetRequiredService<ISettingsService>();
        var settings = await settingsService.GetSettingsAsync();

        try
        {
            var localizer = Services.GetRequiredService<ILocalizationService>();
            localizer.SetLanguage(settings.PreferredLanguage);
        }
        catch
        {
            // ignore
        }

        // Re-apply startup registration if the user enabled it (idempotent).
        try
        {
            var startup = Services.GetRequiredService<IWindowsStartupService>();
            await startup.ApplyAsync(settings.LaunchAtWindowsStartup);
        }
        catch
        {
            // OS limitation must not block launch.
        }

        _mainWindow = new MainWindow();
        MainWindowInstance = _mainWindow;
        ThemeHelper.ApplyTheme(
            settings.SelectedTheme,
            _mainWindow,
            useMica: settings.UseMicaBackdrop);

        _shell = Services.GetRequiredService<DesktopShellCoordinator>();
        _shell.Attach(_mainWindow);

        // Ensure toast service is constructed so NotificationInvoked is wired.
        _ = Services.GetRequiredService<INotificationService>();

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

        // WinUI platform overrides (last registration wins for same interface).
        services.AddSingleton<INotificationService, ToastNotificationService>();
        services.AddSingleton<IFocusAssistService, WindowsFocusAssistService>();
        services.AddSingleton<IWindowsStartupService, WindowsStartupService>();
        services.AddSingleton<IAuthTokenStore, PasswordVaultTokenStore>();
        services.AddSingleton<IAudioPlayerService, WindowsMediaPlayerService>();
        services.AddSingleton<IStoreCommerceService, WindowsStoreCommerceService>();
        services.AddSingleton<IMiniTimerController, MiniTimerController>();
        services.AddSingleton<ITrayIconService, TrayIconService>();
        services.AddSingleton<IGlobalHotkeyService, GlobalHotkeyService>();
        services.AddSingleton<DesktopShellCoordinator>();

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
        // Apply pending EF Core migrations (creates DB + upgrades schema on Store updates).
        await db.Database.MigrateAsync();
    }
}
