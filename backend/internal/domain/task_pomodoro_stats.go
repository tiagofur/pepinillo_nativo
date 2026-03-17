package domain

// TaskPomodoroStats is a read-only aggregate returned by GetTaskStats.
type TaskPomodoroStats struct {
	TaskID           int   `json:"taskId"`
	TotalSessions    int   `json:"totalSessions"`
	CompletedCount   int   `json:"completedCount"`
	TotalFocusSeconds int  `json:"totalFocusSeconds"`
	TotalPauseSeconds int  `json:"totalPauseSeconds"`
	AverageFocus     int   `json:"averageFocusSeconds"`
}
