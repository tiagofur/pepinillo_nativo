# ViewModel Orchestration Test Coverage Specification

## Purpose
Verify ViewModel filter logic, undo timing, and concurrent state transitions.

## Requirements

### Requirement: Filter Matrix Includes Far-Future Due Dates
The task filter MUST include tasks with far-future due dates in the appropriate filter category.

#### Scenario: Due date one year ahead
- GIVEN a task with due date 365 days in the future
- WHEN the "Upcoming" filter is applied
- THEN the task MUST appear in the filtered list

#### Scenario: Due date in distant past
- GIVEN a task with due date 30 days in the past, not completed
- WHEN the "Overdue" filter is applied
- THEN the task MUST appear in the filtered list

### Requirement: Undo Timing Window
The system MUST provide a configurable undo window after task completion.

#### Scenario: Undo within window
- GIVEN a task completed 3 seconds ago with a 5-second undo window
- WHEN the user taps Undo
- THEN the task MUST revert to incomplete state

#### Scenario: Undo after window expires
- GIVEN a task completed 10 seconds ago with a 5-second undo window
- WHEN the user taps Undo
- THEN the undo action MUST be unavailable or ignored

### Requirement: Concurrent Update and Complete Race
The system MUST handle simultaneous update and complete signals without state corruption.

#### Scenario: Update and complete arrive concurrently
- GIVEN a task receiving an update signal and a complete signal simultaneously
- WHEN both signals are processed
- THEN the final state MUST be deterministic (either completed or updated, not partial)

### Requirement: Recurrence Complete
The system MUST correctly handle recurrence completion by creating the next occurrence.

#### Scenario: Recurring task completes
- GIVEN a daily recurring task marked complete today
- WHEN completion is processed
- THEN a new instance MUST be created for tomorrow
- AND the completed instance MUST retain its completion timestamp