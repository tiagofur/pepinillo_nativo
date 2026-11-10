# Wear OS Test Coverage Specification

## Purpose
Verify Wear OS peer communication, foreground service lifecycle, and Pro gating.

## Requirements

### Requirement: Disconnect Does Not Clobber Running Status
A Wear OS peer disconnect MUST NOT overwrite an active focus session's Running status.

#### Scenario: Disconnect during active focus
- GIVEN an active focus session on the phone (status RUNNING)
- WHEN the Wear OS companion disconnects
- THEN the phone session status MUST remain RUNNING
- AND reconnection MUST resume without restart

### Requirement: Resume Remaining Time on Reconnect
When a Wear OS companion reconnects, it MUST receive and display the correct remaining time.

#### Scenario: Reconnect after 3 minutes of focus
- GIVEN 7 minutes remaining on a 10-minute session
- WHEN the Wear OS companion reconnects
- THEN it MUST display 7 minutes remaining
- AND it MUST NOT restart the timer from 10 minutes

### Requirement: Pro Gate on Start Command
Wear OS MUST enforce Pro status before allowing a focus session start.

#### Scenario: Free user attempts start
- GIVEN a user without Pro status on Wear OS
- WHEN the start command is sent from the companion
- THEN the start MUST be rejected with a Pro-required indicator
- AND no focus session MUST be created

#### Scenario: Pro user attempts start
- GIVEN a user with active Pro status on Wear OS
- WHEN the start command is sent from the companion
- THEN the focus session MUST start successfully

### Requirement: phase_complete Call Site
The Wear OS companion MUST call phase_complete at the correct call site during session transitions.

#### Scenario: Phase transitions trigger call
- GIVEN a focus session transitioning from focus to break
- WHEN the phase boundary is reached
- THEN phase_complete MUST be called with the completed phase identifier
- AND the next phase MUST begin without delay