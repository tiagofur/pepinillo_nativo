using System.Threading.Tasks;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;
using Pepinillo.Core.ViewModels;
using Xunit;

namespace Pepinillo.Core.Tests;

public class ThemeEntitlementTests
{
    private static EntitlementService FreeEntitlements()
    {
        var e = new EntitlementService(new StoreCommerceService(new NoAuthBackend()));
        e.ApplyStatus(new SubscriptionStatus { Tier = EntitlementTier.Free });
        return e;
    }

    private static EntitlementService PlusEntitlements()
    {
        var e = new EntitlementService(new StoreCommerceService(new NoAuthBackend()));
        e.ApplyStatus(new SubscriptionStatus { Tier = EntitlementTier.PepinilloPlus });
        return e;
    }

    private static EntitlementService EverywhereEntitlements()
    {
        var e = new EntitlementService(new StoreCommerceService(new NoAuthBackend()));
        e.ApplyStatus(new SubscriptionStatus { Tier = EntitlementTier.EverywherePlus });
        return e;
    }

    [Theory]
    [InlineData("System")]
    [InlineData("Light")]
    [InlineData("Dark")]
    [InlineData("OLEDBlack")]
    [InlineData("system")]
    public void Free_CanUseClassicThemes(string theme)
    {
        var entitlements = FreeEntitlements();
        Assert.True(entitlements.CanUseTheme(theme));
    }

    [Theory]
    [InlineData("Forest")]
    [InlineData("Ocean")]
    [InlineData("Sunset")]
    [InlineData("forest")]
    public void Free_CannotUsePremiumThemes(string theme)
    {
        var entitlements = FreeEntitlements();
        Assert.False(entitlements.CanUseTheme(theme));
    }

    [Theory]
    [InlineData("Forest")]
    [InlineData("Ocean")]
    [InlineData("Sunset")]
    [InlineData("System")]
    [InlineData("Dark")]
    public void Plus_CanUseAllThemes(string theme)
    {
        var entitlements = PlusEntitlements();
        Assert.True(entitlements.CanUseTheme(theme));
    }

    [Fact]
    public void Everywhere_CanUsePremiumThemes()
    {
        var entitlements = EverywhereEntitlements();
        Assert.True(entitlements.CanUseTheme("Sunset"));
        Assert.True(entitlements.IsPremium);
    }

    [Fact]
    public void Catalog_PickerOrder_ReplacesOledWithSunset()
    {
        Assert.Equal(6, AppThemeCatalog.All.Count);
        Assert.Equal("System", AppThemeCatalog.All[0].Name);
        Assert.Equal("Light", AppThemeCatalog.All[1].Name);
        Assert.Equal("Dark", AppThemeCatalog.All[2].Name);
        Assert.Equal("Forest", AppThemeCatalog.All[3].Name);
        Assert.Equal("Ocean", AppThemeCatalog.All[4].Name);
        Assert.Equal("Sunset", AppThemeCatalog.All[5].Name);
        Assert.True(AppThemeCatalog.All[3].IsPremium);
        Assert.True(AppThemeCatalog.All[4].IsPremium);
        Assert.True(AppThemeCatalog.All[5].IsPremium);
        Assert.False(AppThemeCatalog.All[0].IsPremium);
    }

    [Fact]
    public void Catalog_Normalize_OledBlackAliasesDark()
    {
        Assert.Equal("Dark", AppThemeCatalog.Normalize("OLEDBlack"));
        Assert.Equal(2, AppThemeCatalog.ToIndex("OLEDBlack"));
        Assert.Equal("Sunset", AppThemeCatalog.FromIndex(5));
    }

    [Fact]
    public async Task SettingsViewModel_Free_BlocksPremiumThemeIndex()
    {
        var settings = new FakeSettingsService();
        var entitlements = FreeEntitlements();
        var vm = new SettingsViewModel(settings, entitlements: entitlements);
        await vm.LoadAsync();

        string? requested = null;
        vm.PremiumFeatureRequested += (_, feature) => requested = feature;

        // Index 5 = Sunset (premium)
        vm.SelectedThemeIndex = 5;

        Assert.NotEqual(5, vm.SelectedThemeIndex);
        Assert.Equal("System", vm.Settings.SelectedTheme);
        Assert.Equal("Upgrade to Pepinillo+ for premium themes.", vm.StatusMessage);
        Assert.Equal("Sunset", requested);
        Assert.Equal("Sunset", vm.PaywallFeatureHint);
    }

    [Fact]
    public async Task SettingsViewModel_Plus_AllowsSunsetAndSaves()
    {
        var settings = new FakeSettingsService();
        var entitlements = PlusEntitlements();
        var vm = new SettingsViewModel(settings, entitlements: entitlements);
        await vm.LoadAsync();

        UserSettings? saved = null;
        vm.SettingsSaved += (_, s) => saved = s;

        vm.SelectedThemeIndex = 5; // Sunset
        await vm.SaveSettingsCommand.ExecuteAsync(null);

        Assert.Equal("Sunset", vm.Settings.SelectedTheme);
        Assert.NotNull(saved);
        Assert.Equal("Sunset", saved!.SelectedTheme);
        Assert.Equal(string.Empty, vm.PaywallFeatureHint);
    }

    [Fact]
    public async Task SettingsViewModel_SelectThemeCommand_Free_BlocksForest()
    {
        var settings = new FakeSettingsService();
        var entitlements = FreeEntitlements();
        var vm = new SettingsViewModel(settings, entitlements: entitlements);
        await vm.LoadAsync();

        await vm.SelectThemeCommand.ExecuteAsync("Forest");

        Assert.Equal("System", vm.Settings.SelectedTheme);
        Assert.Contains("Pepinillo+", vm.StatusMessage);
    }

    private sealed class FakeSettingsService : ISettingsService
    {
        private UserSettings _settings = new();

        public Task<UserSettings> GetSettingsAsync() => Task.FromResult(_settings);

        public Task SaveSettingsAsync(UserSettings settings)
        {
            _settings = settings;
            return Task.CompletedTask;
        }
    }

    private sealed class NoAuthBackend : IBackendApiClient
    {
        public bool IsAuthenticated => false;
        public string? AuthToken => null;
        public int? LastStatusCode => null;
        public string? LastError => null;
        public Task InitializeAsync() => Task.CompletedTask;
        public Task<bool> LoginAsync(string email, string password) => Task.FromResult(false);
        public Task<bool> RegisterAsync(string email, string password, string name) => Task.FromResult(false);
        public Task<bool> RefreshAsync() => Task.FromResult(false);
        public Task LogoutAsync() => Task.CompletedTask;
        public Task<Pepinillo.Core.Models.Sync.SessionSyncClientResult> SyncSessionsAsync(
            System.Collections.Generic.IEnumerable<FocusSession> sessions,
            System.DateTime? lastSyncAt = null) =>
            Task.FromResult(new Pepinillo.Core.Models.Sync.SessionSyncClientResult { Success = false });
        public Task<Pepinillo.Core.Models.Sync.FullSyncClientResult> PullSessionsAsync(
            int limit = 100, string? sessionCursor = null) =>
            Task.FromResult(new Pepinillo.Core.Models.Sync.FullSyncClientResult { Success = false });
        public Task<SubscriptionStatus> GetSubscriptionStatusAsync() =>
            Task.FromResult(new SubscriptionStatus { Tier = EntitlementTier.Free });

    }
}
