using System;
using System.Threading.Tasks;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;
using Pepinillo.Core.ViewModels;
using Xunit;

namespace Pepinillo.Core.Tests;

public class OnboardingViewModelTests
{
    private sealed class FakeSettingsService : ISettingsService
    {
        public UserSettings Settings { get; set; } = new();
        public int SaveCount { get; private set; }

        public Task<UserSettings> GetSettingsAsync() => Task.FromResult(Settings);

        public Task SaveSettingsAsync(UserSettings settings)
        {
            Settings = settings;
            SaveCount++;
            return Task.CompletedTask;
        }
    }

    private static OnboardingViewModel CreateVm(
        FakeSettingsService? settings = null,
        ILocalizationService? localizer = null) =>
        new(settings ?? new FakeSettingsService(), localizer);

    [Fact]
    public void StartsAtStepZero_CannotGoBack()
    {
        var vm = CreateVm();

        Assert.Equal(0, vm.CurrentStep);
        Assert.True(vm.IsFirstStep);
        Assert.False(vm.CanGoBack);
        Assert.False(vm.BackCommand.CanExecute(null));
        Assert.Equal("Step 1 of 5", vm.StepProgressLabel);
        Assert.Equal("Next", vm.PrimaryButtonLabel);
    }

    [Fact]
    public async Task Next_AdvancesUntilLast_ThenPrimaryIsGetStarted()
    {
        var vm = CreateVm();

        for (var i = 0; i < OnboardingViewModel.StepCount - 1; i++)
            await vm.NextCommand.ExecuteAsync(null);

        Assert.Equal(OnboardingViewModel.StepCount - 1, vm.CurrentStep);
        Assert.True(vm.IsLastStep);
        Assert.True(vm.IsDoneStep);
        Assert.Equal("Get started", vm.PrimaryButtonLabel);
        Assert.Equal("Step 5 of 5", vm.StepProgressLabel);
        Assert.True(vm.CanGoBack);
    }

    [Fact]
    public async Task Back_DoesNotGoBeforeZero()
    {
        var vm = CreateVm();
        vm.BackCommand.Execute(null);
        Assert.Equal(0, vm.CurrentStep);
        Assert.False(vm.CanGoBack);

        await vm.NextCommand.ExecuteAsync(null);
        Assert.Equal(1, vm.CurrentStep);
        vm.BackCommand.Execute(null);
        Assert.Equal(0, vm.CurrentStep);
        Assert.False(vm.CanGoBack);
    }

    [Fact]
    public async Task Skip_CompletesOnboarding_AndRaisesEvent()
    {
        var settings = new FakeSettingsService
        {
            Settings = new UserSettings { HasCompletedOnboarding = false }
        };
        var vm = CreateVm(settings);
        var completed = false;
        vm.Completed += (_, _) => completed = true;

        await vm.SkipCommand.ExecuteAsync(null);

        Assert.True(settings.Settings.HasCompletedOnboarding);
        Assert.Equal(1, settings.SaveCount);
        Assert.True(completed);
        Assert.Equal("Pomodoro", settings.Settings.PreferredFocusMode);
    }

    [Fact]
    public async Task Finish_OnLastStep_CompletesOnboarding()
    {
        var settings = new FakeSettingsService();
        var vm = CreateVm(settings);
        vm.SelectModeCommand.Execute("Stopwatch");

        for (var i = 0; i < OnboardingViewModel.StepCount - 1; i++)
            await vm.NextCommand.ExecuteAsync(null);

        Assert.True(vm.IsLastStep);
        var completed = false;
        vm.Completed += (_, _) => completed = true;

        await vm.FinishCommand.ExecuteAsync(null);

        Assert.True(settings.Settings.HasCompletedOnboarding);
        Assert.Equal(FocusMode.Stopwatch, vm.SelectedDefaultMode);
        Assert.Equal("Stopwatch", settings.Settings.PreferredFocusMode);
        Assert.True(completed);
    }

    [Fact]
    public async Task Next_OnLastStep_Finishes()
    {
        var settings = new FakeSettingsService();
        var vm = CreateVm(settings);
        for (var i = 0; i < OnboardingViewModel.StepCount - 1; i++)
            await vm.NextCommand.ExecuteAsync(null);

        var completed = false;
        vm.Completed += (_, _) => completed = true;

        await vm.NextCommand.ExecuteAsync(null);

        Assert.True(settings.Settings.HasCompletedOnboarding);
        Assert.True(completed);
    }

    [Fact]
    public void SelectMode_ParsesKnownModes()
    {
        var vm = CreateVm();
        vm.SelectModeCommand.Execute("Flowtime");
        Assert.Equal(FocusMode.Flowtime, vm.SelectedDefaultMode);
        Assert.True(vm.IsFlowtimeSelected);

        vm.SelectModeCommand.Execute("TimeBlocking");
        Assert.Equal(FocusMode.TimeBlocking, vm.SelectedDefaultMode);

        vm.SelectModeCommand.Execute("not-a-mode");
        Assert.Equal(FocusMode.TimeBlocking, vm.SelectedDefaultMode);
    }

    [Fact]
    public async Task ResetWizard_ReturnsToStepZero()
    {
        var vm = CreateVm();
        await vm.NextCommand.ExecuteAsync(null);
        vm.SelectModeCommand.Execute("Stopwatch");
        vm.ResetWizard();

        Assert.Equal(0, vm.CurrentStep);
        Assert.Equal(FocusMode.Pomodoro, vm.SelectedDefaultMode);
        Assert.False(vm.CanGoBack);
    }

    [Fact]
    public async Task StepTitles_ChangeWithPreferredLanguage()
    {
        var settings = new FakeSettingsService
        {
            Settings = new UserSettings { PreferredLanguage = "es" }
        };
        var loc = new LocalizationService();
        var vm = CreateVm(settings, loc);

        await vm.ApplyLanguageFromSettingsAsync();

        Assert.Equal("Bienvenido a Pepinillo", vm.StepTitle);
        Assert.Equal("Siguiente", vm.PrimaryButtonLabel);
        Assert.Equal("Omitir", vm.SkipLabel);

        settings.Settings.PreferredLanguage = "pt";
        await vm.ApplyLanguageFromSettingsAsync();

        Assert.Equal("Bem-vindo ao Pepinillo", vm.StepTitle);
        Assert.Equal("Próximo", vm.PrimaryButtonLabel);
        Assert.Equal("Pular", vm.SkipLabel);
    }
}
