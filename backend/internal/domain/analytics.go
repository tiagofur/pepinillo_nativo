package domain

import "time"

type WeeklyReport struct {
	UserID    string    `json:"userId"`
	WeekStart time.Time `json:"weekStart"`
	WeekEnd   time.Time `json:"weekEnd"`

	// Overall stats
	TotalFocusTime int `json:"totalFocusTime"`
	TotalSessions  int `json:"totalSessions"`

	// Mode breakdown
	PomodoroStats  ModeStats `json:"pomodoroStats"`
	FlowtimeStats  ModeStats `json:"flowtimeStats"`
	TimeblockStats ModeStats `json:"timeblockStats"`
	StopwatchStats ModeStats `json:"stopwatchStats"`

	// Task stats
	TasksCompleted int `json:"tasksCompleted"`
	TasksCreated   int `json:"tasksCreated"`

	// Insights
	TopTasks         []TaskStat `json:"topTasks"`
	BestDayOfWeek    string     `json:"bestDayOfWeek"`
	AverageFocusTime int        `json:"averageFocusTime"`
	Streak           int        `json:"streak"`
}

type MonthlyReport struct {
	UserID     string    `json:"userId"`
	MonthStart time.Time `json:"monthStart"`
	MonthEnd   time.Time `json:"monthEnd"`

	// Overall stats
	TotalFocusTime int `json:"totalFocusTime"`
	TotalSessions  int `json:"totalSessions"`

	// Mode breakdown
	PomodoroStats  ModeStats `json:"pomodoroStats"`
	FlowtimeStats  ModeStats `json:"flowtimeStats"`
	TimeblockStats ModeStats `json:"timeblockStats"`
	StopwatchStats ModeStats `json:"stopwatchStats"`

	// Task stats
	TasksCompleted int `json:"tasksCompleted"`
	TasksCreated   int `json:"tasksCreated"`

	// Insights
	TopTasks         []TaskStat `json:"topTasks"`
	BestDayOfMonth   string     `json:"bestDayOfMonth"`
	AverageFocusTime int        `json:"averageFocusTime"`
	LongestStreak    int        `json:"longestStreak"`
}

type ModeStats struct {
	TotalTime    int `json:"totalTime"`
	SessionCount int `json:"sessionCount"`
	Completed    int `json:"completed"`
	AvgDuration  int `json:"avgDuration"`
}

type TaskStat struct {
	TaskID       int    `json:"taskId"`
	TaskTitle    string `json:"taskTitle"`
	FocusTime    int    `json:"focusTime"`
	SessionCount int    `json:"sessionCount"`
	Completed    bool   `json:"completed"`
}

type CompletionRateStats struct {
	UserID      string    `json:"userId"`
	PeriodStart time.Time `json:"periodStart"`
	PeriodEnd   time.Time `json:"periodEnd"`

	// Overall completion
	CompletionRate float64 `json:"completionRate"`

	// Mode-specific completion rates
	PomodoroRate  float64 `json:"pomodoroRate"`
	FlowtimeRate  float64 `json:"flowtimeRate"`
	TimeblockRate float64 `json:"timeblockRate"`

	// Session breakdown
	TotalSessions     int `json:"totalSessions"`
	CompletedSessions int `json:"completedSessions"`
	AbandonedSessions int `json:"abandonedSessions"`

	// Abandoned reasons
	AbandonedByMode map[string]int `json:"abandonedByMode"`
}

type StreakStats struct {
	UserID           string    `json:"userId"`
	CurrentStreak    int       `json:"currentStreak"`
	LongestStreak    int       `json:"longestStreak"`
	LastActivityDate time.Time `json:"lastActivityDate"`
	StreakStartDate  time.Time `json:"streakStartDate"`

	// Mode-specific streaks
	PomodoroStreak  int `json:"pomodoroStreak"`
	FlowtimeStreak  int `json:"flowtimeStreak"`
	TimeblockStreak int `json:"timeblockStreak"`
	StopwatchStreak int `json:"stopwatchStreak"`
}
