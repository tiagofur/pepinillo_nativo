using System;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Pepinillo.Core.Data;
using Pepinillo.Core.Services;
using Pepinillo.Core.ViewModels;

namespace Pepinillo.Core.DependencyInjection;

public static class ServiceCollectionExtensions
{
    /// <summary>
    /// Registers Pepinillo Core services, EF Core SQLite, and view models.
    /// </summary>
    /// <param name="services">Service collection.</param>
    /// <param name="sqliteDbPath">Absolute path to the SQLite database file.</param>
    public static IServiceCollection AddPepinilloCore(this IServiceCollection services, string sqliteDbPath)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(sqliteDbPath);

        var connectionString = $"Data Source={sqliteDbPath}";

        services.AddDbContext<PepinilloDbContext>(options =>
            options.UseSqlite(connectionString),
            contextLifetime: ServiceLifetime.Singleton,
            optionsLifetime: ServiceLifetime.Singleton);

        services.AddSingleton<IAuthTokenStore, MemoryAuthTokenStore>();
        services.AddSingleton<IFocusEngineService, FocusEngineService>();
        services.AddSingleton<ISettingsService, SettingsService>();
        services.AddSingleton<IFocusSessionService, FocusSessionService>();
        services.AddSingleton<INotificationService, NotificationService>();
        services.AddSingleton<IFocusAssistService, FocusAssistService>();
        services.AddSingleton<IAudioPlayerService, AudioPlayerService>();
        services.AddSingleton<ISoundscapeSessionCoordinator, SoundscapeSessionCoordinator>();
        services.AddSingleton<ILocalizationService, LocalizationService>();
        services.AddSingleton(_ => new System.Net.Http.HttpClient());
        services.AddSingleton<IBackendApiClient, BackendApiClient>();
        services.AddSingleton<IStoreCommerceService, StoreCommerceService>();
        services.AddSingleton<IEntitlementService, EntitlementService>();
        services.AddSingleton<ITaskService, TaskService>();
        services.AddSingleton<ISyncService, SyncService>();
        services.AddSingleton<IReflectService, ReflectService>();

        services.AddSingleton<FocusViewModel>();
        services.AddTransient<TasksViewModel>();
        services.AddSingleton<SettingsViewModel>();
        services.AddTransient<AnalyticsViewModel>();
        services.AddTransient<SoundscapesViewModel>();
        services.AddTransient<AuthViewModel>();
        services.AddTransient<PaywallViewModel>();

        return services;
    }
}
