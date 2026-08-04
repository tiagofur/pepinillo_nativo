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

    /// <summary>Inverse of <see cref="IsBusy"/> for XAML IsEnabled bindings.</summary>
    public bool CanInteract => !IsBusy;

    public PaywallViewModel(
        IStoreCommerceService commerce,
        IEntitlementService? entitlements = null)
    {
        _commerce = commerce;
        _entitlements = entitlements;
    }

    partial void OnIsBusyChanged(bool value)
    {
        OnPropertyChanged(nameof(CanInteract));
        NotifyCommerceCommandsCanExecuteChanged();
    }

    private bool CanRunCommerce() => !IsBusy;

    public async Task LoadAsync()
    {
        try
        {
            var status = await _commerce.CheckStoreEntitlementsAsync();
            ApplyTierToUi(status);
            NotifyEntitlements(status);
        }
        catch
        {
            CurrentTierLabel = "Current tier: Free";
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
                StatusMessage = "Purchases restored. Your plan is active.";
            }
            else if (!string.IsNullOrWhiteSpace(_commerce.LastError))
            {
                StatusMessage = _commerce.LastError!;
            }
            else
            {
                StatusMessage = "No active purchases found. You're on Free — upgrade anytime.";
            }
        }
        catch (Exception ex)
        {
            StatusMessage = $"Restore error: {ex.Message}";
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
            StatusMessage = $"Purchase error: {ex.Message}";
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
        CurrentTierLabel = $"Current tier: {FormatTier(status.Tier)} · source: {source}";
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

    private static string FormatTier(EntitlementTier tier) =>
        tier switch
        {
            EntitlementTier.PepinilloPlus => "Pepinillo+",
            EntitlementTier.EverywherePlus => "Everywhere / AI+",
            _ => "Free"
        };
}
