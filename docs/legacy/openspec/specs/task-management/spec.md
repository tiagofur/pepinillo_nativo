# Task Management Specification

## Purpose
Core requirements for managing tasks across all platforms.

## Requirements

### Requirement: Task Filtering (Inbox vs Active)
The system MUST support an "Inbox" filter that shows tasks that are not completed, not scheduled for today, and have no due date.

#### Scenario: Newly added task
- GIVEN a task added with no date or today flag
- WHEN the "Inbox" filter is selected
- THEN the task MUST be visible

### Requirement: Today Planning
The system MUST support a "Today" filter that shows tasks marked as "Scheduled for Today" that are not yet completed.

#### Scenario: Marking task for today
- GIVEN a task in the Inbox
- WHEN the user marks it for "Today"
- THEN it MUST appear in the Today list
- AND it MUST be removed from the Inbox list
