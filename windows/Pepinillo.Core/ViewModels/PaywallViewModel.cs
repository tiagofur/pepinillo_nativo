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

    [ObservableProperty]
    private string _currentTierLabel = "Free";

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

    public PaywallViewModel(IStoreCommerceService commerce)
    {
        _commerce = commerce;
    }

    public async Task LoadAsync()
    {
        try
        {
            var status = await _commerce.CheckStoreEntitlementsAsync();
            CurrentTierLabel = "Current tier: " + status.Tier;
        }
        catch
        {
            CurrentTierLabel = "Current tier: Free";
        }
    }

    [RelayCommand]
    private async Task PurchasePepinilloPlusAsync()
    {
        IsBusy = true;
        try
        {
            var ok = await _commerce.PurchasePepinilloPlusAsync();
            StatusMessage = ok
                ? "Purchase flow completed (or simulated)."
                : "Purchase unavailable (no Store identity or cancelled).";
            await LoadAsync();
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

    [RelayCommand]
    private async Task SubscribeMonthlyAsync()
    {
        await SubscribeAsync(annual: false);
    }

    [RelayCommand]
    private async Task SubscribeAnnualAsync()
    {
        await SubscribeAsync(annual: true);
    }

    private async Task SubscribeAsync(bool annual)
    {
        IsBusy = true;
        try
        {
            var ok = await _commerce.SubscribeEverywherePlusAsync(annual);
            StatusMessage = ok
                ? "Subscription flow completed (or simulated)."
                : "Subscription unavailable (no Store identity or cancelled).";
            await LoadAsync();
        }
        catch (Exception ex)
        {
            StatusMessage = $"Subscription error: {ex.Message}";
        }
        finally
        {
            IsBusy = false;
        }
    }
}
