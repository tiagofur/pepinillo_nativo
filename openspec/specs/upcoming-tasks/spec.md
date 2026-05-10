# Upcoming Tasks Specification

## Purpose
Define the behavior for the 7-day upcoming tasks view to ensure parity between platforms and consistent scheduling logic.

## Requirements

### Requirement: Upcoming Filter Range
The system MUST filter tasks that are not completed, not scheduled for today, and have a due date within the next 7 days (including today's remaining time).

#### Scenario: Task due in 2 days
- GIVEN a task with a due date 2 days from now
- AND the task is not completed
- WHEN the "Upcoming" filter is selected
- THEN the task MUST be visible in the list

#### Scenario: Task due in 10 days
- GIVEN a task with a due date 10 days from now
- WHEN the "Upcoming" filter is selected
- THEN the task MUST NOT be visible in the list

### Requirement: Today Exclusion
The Upcoming filter MUST NOT show tasks that are explicitly marked as "Scheduled for Today", even if their due date is within the range.

#### Scenario: Task due tomorrow but scheduled for today
- GIVEN a task with a due date set for tomorrow
- AND the "Scheduled for Today" flag is TRUE
- WHEN the "Upcoming" filter is selected
- THEN the task MUST NOT be visible (it belongs to the Today filter)
