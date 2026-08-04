using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Pepinillo.Core.ViewModels;

namespace Pepinillo.WinUI.Views;

public sealed partial class AccountPage : Page
{
    public AuthViewModel ViewModel { get; }

    public AccountPage()
    {
        ViewModel = App.Services.GetRequiredService<AuthViewModel>();
        InitializeComponent();
        Loaded += async (_, _) => await ViewModel.InitializeAsync();
    }

    private void PasswordBox_PasswordChanged(object sender, RoutedEventArgs e)
    {
        if (sender is PasswordBox box)
            ViewModel.Password = box.Password;
    }
}
