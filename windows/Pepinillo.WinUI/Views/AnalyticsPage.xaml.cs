using Microsoft.UI.Xaml.Controls;
using Pepinillo.Core.ViewModels;

namespace Pepinillo.WinUI.Views;

public sealed partial class AnalyticsPage : Page
{
    public AnalyticsViewModel ViewModel { get; } = new();

    public AnalyticsPage()
    {
        this.InitializeComponent();
    }
}
