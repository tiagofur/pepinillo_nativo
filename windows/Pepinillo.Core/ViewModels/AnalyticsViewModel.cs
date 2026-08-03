using System;
using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.ViewModels;

public partial class AnalyticsViewModel : ObservableObject
{
    [ObservableProperty]
    private int _todayFocusMinutes = 125;

    [ObservableProperty]
    private int _weeklyFocusHours = 14;

    [ObservableProperty]
    private int _currentStreakDays = 5;

    [ObservableProperty]
    private int _bestStreakDays = 12;

    [ObservableProperty]
    private string _aiReportSummary = "Has mantenido un excelente enfoque por las mañanas entre las 9 AM y las 11:30 AM. Recomendación: Programa tus tareas más complejas en ese bloque de tiempo.";

    [ObservableProperty]
    private ObservableCollection<FocusSession> _recentSessions = new();

    public AnalyticsViewModel()
    {
        // Load recent focus analytics and AI insights
    }
}
