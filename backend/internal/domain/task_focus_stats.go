package domain

type TaskFocusStats struct {
	TaskID            int     `json:"taskId"`
	TotalSessions     int     `json:"totalSessions"`
	CompletedCount    int     `json:"completedCount"`
	TotalFocusSeconds int     `json:"totalFocusSeconds"`
	TotalPauseSeconds int     `json:"totalPauseSeconds"`
	AverageFocus      float64 `json:"averageFocus"`

	// Mode-specific stats
	PomodoroSessions  int `json:"pomodoroSessions"`
	FlowtimeSessions  int `json:"flowtimeSessions"`
	TimeblockSessions int `json:"timeblockSessions"`
	StopwatchSessions int `json:"stopwatchSessions"`
}
