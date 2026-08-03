using Microsoft.UI.Xaml.Controls;
using Pepinillo.Core.ViewModels;

namespace Pepinillo.WinUI.Views;

public sealed partial class TasksPage : Page
{
    public TasksViewModel ViewModel { get; }

    public TasksPage(TasksViewModel viewModel)
    {
        ViewModel = viewModel;
        this.InitializeComponent();
        this.Loaded += async (s, e) => await ViewModel.LoadTasksAsync();
    }
}
