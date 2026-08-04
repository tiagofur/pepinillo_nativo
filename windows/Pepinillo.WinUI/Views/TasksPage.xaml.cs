using System;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Pepinillo.Core.Models;
using Pepinillo.Core.ViewModels;

namespace Pepinillo.WinUI.Views;

public sealed partial class TasksPage : Page
{
    public TasksViewModel ViewModel { get; }
    private TaskItem? _subtaskParent;

    public TasksPage()
    {
        ViewModel = App.Services.GetRequiredService<TasksViewModel>();
        InitializeComponent();
        Loaded += async (_, _) =>
        {
            await ViewModel.LoadTasksAsync();
            ApplyFilterHeaders();
        };
        ViewModel.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName is nameof(ViewModel.FilterTodayLabel)
                or nameof(ViewModel.FilterUpcomingLabel)
                or nameof(ViewModel.FilterInboxLabel)
                or nameof(ViewModel.FilterAllLabel))
            {
                ApplyFilterHeaders();
            }
        };
    }

    /// <summary>Ctrl+N — move keyboard focus to the new task title field.</summary>
    private void NewTaskAccelerator_Invoked(KeyboardAccelerator sender, KeyboardAcceleratorInvokedEventArgs args)
    {
        NewTaskTitleBox.Focus(FocusState.Programmatic);
        args.Handled = true;
    }

    private void ApplyFilterHeaders()
    {
        FilterTodayItem.Header = ViewModel.FilterTodayLabel;
        FilterUpcomingItem.Header = ViewModel.FilterUpcomingLabel;
        FilterInboxItem.Header = ViewModel.FilterInboxLabel;
        FilterAllItem.Header = ViewModel.FilterAllLabel;
    }

    private async void FilterPivot_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (FilterPivot.SelectedItem is PivotItem item && item.Tag is string filter)
            await ViewModel.FilterTasksCommand.ExecuteAsync(filter);
    }

    private async void TaskCheck_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: TaskItem task })
            await ViewModel.ToggleTaskCommand.ExecuteAsync(task);
    }

    private async void SubtaskCheck_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: TaskItem subtask })
            await ViewModel.ToggleSubtaskCommand.ExecuteAsync(subtask);
    }

    private async void DeleteTask_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: TaskItem task })
            await ViewModel.DeleteTaskCommand.ExecuteAsync(task);
    }

    private async void AddSubtask_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not FrameworkElement { Tag: TaskItem parent })
            return;

        _subtaskParent = parent;
        SubtaskTitleBox.Text = string.Empty;
        SubtaskDialog.XamlRoot = XamlRoot;
        await SubtaskDialog.ShowAsync();
    }

    private async void SubtaskDialog_PrimaryButtonClick(ContentDialog sender, ContentDialogButtonClickEventArgs args)
    {
        if (_subtaskParent == null)
            return;

        ViewModel.NewSubtaskTitle = SubtaskTitleBox.Text;
        await ViewModel.CreateSubtaskCommand.ExecuteAsync(_subtaskParent);
        _subtaskParent = null;
    }
}
