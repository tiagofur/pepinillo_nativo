using System;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml.Controls;
using Pepinillo.Core.ViewModels;

namespace Pepinillo.WinUI.Views;

public sealed partial class OnboardingPage : Page
{
    public OnboardingViewModel ViewModel { get; }

    public OnboardingPage()
    {
        ViewModel = App.Services.GetRequiredService<OnboardingViewModel>();
        InitializeComponent();
        ViewModel.Completed += OnOnboardingCompleted;
        Unloaded += (_, _) => ViewModel.Completed -= OnOnboardingCompleted;
    }

    private void OnOnboardingCompleted(object? sender, EventArgs e)
    {
        if (App.MainWindowInstance is MainWindow main)
        {
            main.ExitOnboardingMode();
            main.NavigateToTag("Focus");
        }
        else if (Frame != null)
        {
            Frame.Navigate(typeof(FocusPage));
        }
    }
}
