using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml.Controls;
using Pepinillo.Core.ViewModels;

namespace Pepinillo.WinUI.Views;

public sealed partial class PaywallPage : Page
{
    public PaywallViewModel ViewModel { get; }

    public PaywallPage()
    {
        ViewModel = App.Services.GetRequiredService<PaywallViewModel>();
        InitializeComponent();
        Loaded += async (_, _) => await ViewModel.LoadAsync();
    }
}
