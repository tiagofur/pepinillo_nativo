using System;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Pepinillo.Core.Models;
using Pepinillo.Core.ViewModels;
using Windows.System;

namespace Pepinillo.WinUI.Views;

public sealed partial class TasksPage : Page
{
    public TasksViewModel ViewModel { get; }
    private TaskItem? _subtaskParent;

    public TasksPage()
    {
        ViewModel = App.Services.GetRequiredService<TasksViewModel>();
        InitializeComponent();
        Loaded += TasksPage_Loaded;
        Unloaded += TasksPage_Unloaded;
        ViewModel.PremiumFeatureRequested += OnPremiumFeatureRequested;
        ViewModel.FocusNewTaskRequested += OnFocusNewTaskRequested;
        ViewModel.PropertyChanged += OnViewModelPropertyChanged;
    }

    private async void TasksPage_Loaded(object sender, RoutedEventArgs e)
    {
        await ViewModel.LoadTasksAsync();
        ApplyFilterHeaders();
    }

    private void TasksPage_Unloaded(object sender, RoutedEventArgs e)
    {
        ViewModel.PremiumFeatureRequested -= OnPremiumFeatureRequested;
        ViewModel.FocusNewTaskRequested -= OnFocusNewTaskRequested;
        ViewModel.PropertyChanged -= OnViewModelPropertyChanged;
    }

    private void OnViewModelPropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(ViewModel.FilterTodayLabel)
            or nameof(ViewModel.FilterUpcomingLabel)
            or nameof(ViewModel.FilterInboxLabel)
            or nameof(ViewModel.FilterAllLabel))
        {
            ApplyFilterHeaders();
        }
    }

    private void OnPremiumFeatureRequested(object? sender, string feature)
    {
        if (Frame != null)
            Frame.Navigate(typeof(PaywallPage));
    }

    private void OnFocusNewTaskRequested(object? sender, EventArgs e) =>
        FocusNewTaskTitleBox();

    /// <summary>Ctrl+N — move keyboard focus to the new task title field.</summary>
    private void NewTaskAccelerator_Invoked(KeyboardAccelerator sender, KeyboardAcceleratorInvokedEventArgs args)
    {
        FocusNewTaskTitleBox();
        args.Handled = true;
    }

    private void FocusNewTaskTitleBox()
    {
        NewTaskTitleBox.Focus(FocusState.Programmatic);
    }

    private void EmptyCta_Click(object sender, RoutedEventArgs e) =>
        ViewModel.FocusNewTaskComposerCommand.Execute(null);

    private async void NewTaskTitleBox_KeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (e.Key != VirtualKey.Enter)
            return;

        e.Handled = true;
        if (ViewModel.CreateTaskCommand.CanExecute(null))
            await ViewModel.CreateTaskCommand.ExecuteAsync(null);
        // ViewModel raises FocusNewTaskRequested after success; also refocus on no-op empty title.
        FocusNewTaskTitleBox();
    }

    private async void SubtaskTitleBox_KeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (e.Key != VirtualKey.Enter)
            return;

        e.Handled = true;
        if (_subtaskParent == null)
            return;

        ViewModel.NewSubtaskTitle = SubtaskTitleBox.Text;
        await ViewModel.CreateSubtaskCommand.ExecuteAsync(_subtaskParent);
        _subtaskParent = null;
        SubtaskDialog.Hide();
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
