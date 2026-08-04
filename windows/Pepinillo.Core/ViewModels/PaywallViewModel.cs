using System;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;

namespace Pepinillo.Core.ViewModels;

public partial class PaywallViewModel : ObservableObject
{
    private readonly IStoreCommerceService _commerce;
    private readonly IEntitlementService? _entitlements;
    private readonly ILocalizationService? _localizer;
    private readonly ISettingsService? _settings;

    [ObservableProperty]
    private string _currentTierLabel = "Current tier: Free";

    [ObservableProperty]
    private string _statusMessage = string.Empty;

    [ObservableProperty]
    private bool _isBusy;

    [ObservableProperty]
    private string _pepinilloPlusPrice = ProductCatalog.PepinilloPlusPriceDisplay;

    [ObservableProperty]
    private string _everywhereMonthlyPrice = ProductCatalog.EverywhereMonthlyPriceDisplay;

    [ObservableProperty]
    private string _everywhereAnnualPrice = ProductCatalog.EverywhereAnnualPriceDisplay;

    [ObservableProperty]
    private string _priceDisclaimer = ProductCatalog.PriceDisclaimer;

    [ObservableProperty]
    private string _pepinilloPlusPurchaseType = ProductCatalog.PepinilloPlusPurchaseType;

    [ObservableProperty]
    private bool _isFreeTier = true;

    [ObservableProperty]
    private string _titleLabel = "Upgrade Pepinillo";

    [ObservableProperty]
    private string _freeBlurbLabel =
        "Free includes Pomodoro, Stopwatch, 3 active tasks, and 7-day analytics. Upgrade for Flowtime, Time Blocking, unlimited tasks, premium themes, soundscapes, and cloud sync.";

    [ObservableProperty]
    private string _plusFeaturesLabel =
        "Flowtime, Time Blocking, unlimited local tasks, premium themes (Forest, Ocean, Sunset), premium soundscapes, desktop power features.";

    [ObservableProperty]
    private string _everywhereFeaturesLabel =
        "Cloud sync across platforms, AI reports, and cross-device entitlement.";

    [ObservableProperty]
    private string _subscriptionLabel = "Subscription";

    [ObservableProperty]
    private string _buyPlusLabel = "Buy Pepinillo+";

    [ObservableProperty]
    private string _subscribeMonthlyLabel = "Subscribe monthly";

    [ObservableProperty]
    private string _subscribeAnnualLabel = "Subscribe annual";

    [ObservableProperty]
    private string _restoreLabel = "Restore purchases";

    [ObservableProperty]
    private string _manageStoreLabel = "Manage purchases in Microsoft Store";

    [ObservableProperty]
    private string _notASubscriptionLabel = "One-time purchase — not a subscription";

    /// <summary>Inverse of <see cref="IsBusy"/> for XAML IsEnabled bindings.</summary>
    public bool CanInteract => !IsBusy;

    public PaywallViewModel(
        IStoreCommerceService commerce,
        IEntitlementService? entitlements = null,
        ILocalizationService? localizer = null,
        ISettingsService? settings = null)
    {
        _commerce = commerce;
        _entitlements = entitlements;
        _localizer = localizer;
        _settings = settings;
    }

    partial void OnIsBusyChanged(bool value)
    {
        OnPropertyChanged(nameof(CanInteract));
        NotifyCommerceCommandsCanExecuteChanged();
    }

    private bool CanRunCommerce() => !IsBusy;

    public async Task LoadAsync()
    {
        await ApplyLanguageAsync();
        try
        {
            var status = await _commerce.CheckStoreEntitlementsAsync();
            ApplyTierToUi(status);
            NotifyEntitlements(status);
        }
        catch
        {
            CurrentTierLabel = T("Paywall.CurrentTierFree", "Current tier: Free");
            IsFreeTier = true;
        }
    }

    [RelayCommand(CanExecute = nameof(CanRunCommerce))]
    private async Task PurchasePepinilloPlusAsync()
    {
        await RunCommerceAsync(() => _commerce.PurchasePepinilloPlusAsync());
    }

    [RelayCommand(CanExecute = nameof(CanRunCommerce))]
    private async Task SubscribeMonthlyAsync()
    {
        await RunCommerceAsync(() => _commerce.SubscribeEverywherePlusAsync(annual: false));
    }

    [RelayCommand(CanExecute = nameof(CanRunCommerce))]
    private async Task SubscribeAnnualAsync()
    {
        await RunCommerceAsync(() => _commerce.SubscribeEverywherePlusAsync(annual: true));
    }

    [RelayCommand(CanExecute = nameof(CanRunCommerce))]
    private async Task RestorePurchasesAsync()
    {
        IsBusy = true;
        try
        {
            var status = await _commerce.RestorePurchasesAsync();
            ApplyTierToUi(status);
            NotifyEntitlements(status);

            if (status.IsActive)
            {
                StatusMessage = T("Paywall.RestoreSuccess", "Purchases restored. Your plan is active.");
            }
            else if (!string.IsNullOrWhiteSpace(_commerce.LastError))
            {
                StatusMessage = _commerce.LastError!;
            }
            else
            {
                StatusMessage = T("Paywall.RestoreNone",
                    "No active purchases found. You're on Free — upgrade anytime.");
            }
        }
        catch (Exception ex)
        {
            StatusMessage = string.Format(
                T("Paywall.RestoreError", "Restore error: {0}"),
                ex.Message);
        }
        finally
        {
            IsBusy = false;
        }
    }

    private async Task RunCommerceAsync(Func<Task<CommerceResult>> action)
    {
        IsBusy = true;
        try
        {
            var result = await action();
            StatusMessage = result.Message;

            if (result.Status != null)
            {
                ApplyTierToUi(result.Status);
                NotifyEntitlements(result.Status);
            }
            else
            {
                var status = await _commerce.CheckStoreEntitlementsAsync();
                ApplyTierToUi(status);
                if (result.Success)
                    NotifyEntitlements(status);
            }
        }
        catch (Exception ex)
        {
            StatusMessage = string.Format(
                T("Paywall.PurchaseError", "Purchase error: {0}"),
                ex.Message);
        }
        finally
        {
            IsBusy = false;
        }
    }

    private void ApplyTierToUi(SubscriptionStatus status)
    {
        var source = string.IsNullOrWhiteSpace(status.SourceStore)
            ? "local"
            : status.SourceStore;
        CurrentTierLabel = string.Format(
            T("Paywall.CurrentTier", "Current tier: {0} · source: {1}"),
            FormatTier(status.Tier),
            source);
        IsFreeTier = status.Tier == EntitlementTier.Free;
    }

    private void NotifyEntitlements(SubscriptionStatus status)
    {
        _entitlements?.ApplyStatus(status);
    }

    private void NotifyCommerceCommandsCanExecuteChanged()
    {
        PurchasePepinilloPlusCommand.NotifyCanExecuteChanged();
        SubscribeMonthlyCommand.NotifyCanExecuteChanged();
        SubscribeAnnualCommand.NotifyCanExecuteChanged();
        RestorePurchasesCommand.NotifyCanExecuteChanged();
    }

    private string FormatTier(EntitlementTier tier) =>
        tier switch
        {
            EntitlementTier.PepinilloPlus => T("Paywall.TierPlus", "Pepinillo+"),
            EntitlementTier.EverywherePlus => T("Paywall.TierEverywhere", "Everywhere / AI+"),
            _ => T("Paywall.TierFree", "Free")
        };

    private async Task ApplyLanguageAsync()
    {
        if (_localizer == null) return;

        if (_settings != null)
        {
            try
            {
                var settings = await _settings.GetSettingsAsync();
                _localizer.SetLanguage(settings.PreferredLanguage);
            }
            catch
            {
                // keep current
            }
        }

        TitleLabel = T("Paywall.Title", "Upgrade Pepinillo");
        FreeBlurbLabel = T("Paywall.FreeBlurb", FreeBlurbLabel);
        PlusFeaturesLabel = T("Paywall.PlusFeatures", PlusFeaturesLabel);
        EverywhereFeaturesLabel = T("Paywall.EverywhereFeatures", EverywhereFeaturesLabel);
        SubscriptionLabel = T("Paywall.Subscription", "Subscription");
        BuyPlusLabel = T("Paywall.BuyPlus", "Buy Pepinillo+");
        SubscribeMonthlyLabel = T("Paywall.SubscribeMonthly", "Subscribe monthly");
        SubscribeAnnualLabel = T("Paywall.SubscribeAnnual", "Subscribe annual");
        RestoreLabel = T("Paywall.Restore", "Restore purchases");
        ManageStoreLabel = T("Paywall.ManageStore", "Manage purchases in Microsoft Store");
        NotASubscriptionLabel = T("Paywall.NotASubscription",
            "One-time purchase — not a subscription");

        // Prefer localized one-time badge over catalog English when available.
        PepinilloPlusPurchaseType = NotASubscriptionLabel;
    }

    private string T(string key, string fallback) =>
        _localizer?.GetString(key) ?? fallback;
}
