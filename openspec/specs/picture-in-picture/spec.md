# Picture-in-Picture (PiP) Specification

## Purpose
Allow users to track their focus timer in a small overlay while using other applications.

## Requirements

### Requirement: PiP Entry
The system MUST allow entering Picture-in-Picture mode when a focus session is active and the user leaves the application.

#### Scenario: Enter PiP during Focus
- GIVEN a focus session is running
- WHEN the user presses the Home button or swipes up
- THEN the application SHALL enter Picture-in-Picture mode
- AND the timer MUST continue running in the PiP window.

### Requirement: PiP UI
The PiP window MUST display the current timer value and phase (Focus/Break).

#### Scenario: PiP Display
- GIVEN the app is in PiP mode
- WHEN the timer ticks
- THEN the PiP window MUST update the displayed time in real-time.

### Requirement: PiP Actions
The PiP window SHOULD provide a quick action to pause/resume the timer.

#### Scenario: Pause from PiP
- GIVEN the app is in PiP mode and running
- WHEN the user taps the Pause action in the PiP window
- THEN the timer MUST pause
- AND the UI MUST update to show the Play action.
