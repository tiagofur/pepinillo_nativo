package domain

type FocusMode string

const (
	FocusModePomodoro  FocusMode = "pomodoro"
	FocusModeFlowtime  FocusMode = "flowtime"
	FocusModeTimeBlock FocusMode = "timeblock"
	FocusModeStopwatch FocusMode = "stopwatch"
)

func (m FocusMode) String() string {
	return string(m)
}

func (m FocusMode) IsValid() bool {
	switch m {
	case FocusModePomodoro, FocusModeFlowtime, FocusModeTimeBlock, FocusModeStopwatch:
		return true
	default:
		return false
	}
}

type FocusPhase string

const (
	FocusPhaseWork       FocusPhase = "work"
	FocusPhaseShortBreak FocusPhase = "short_break"
	FocusPhaseLongBreak  FocusPhase = "long_break"
	FocusPhaseFlow       FocusPhase = "flow"
	FocusPhaseBreak      FocusPhase = "break"
	FocusPhaseCheckIn    FocusPhase = "check_in"
	FocusPhaseFreeform   FocusPhase = "freeform"
)

func (p FocusPhase) String() string {
	return string(p)
}

func (p FocusPhase) IsValid() bool {
	switch p {
	case FocusPhaseWork, FocusPhaseShortBreak, FocusPhaseLongBreak,
		FocusPhaseFlow, FocusPhaseBreak, FocusPhaseCheckIn, FocusPhaseFreeform:
		return true
	default:
		return false
	}
}
