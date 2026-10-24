# Focus Recovery Test Coverage Specification

## Purpose
Verify focus timer lifecycle recovery, pause behavior, and race-condition handling.

## Requirements

### Requirement: Pause and Recovery Elapsed Reconstruction
The system MUST correctly reconstruct elapsed time when a focus session is paused and resumed.

#### Scenario: Recovery resumes from correct elapsed
- GIVEN a session with 10 minutes elapsed before pause
- WHEN the user resumes the session
- THEN the elapsed timer MUST continue from 10 minutes, not reset to zero

#### Scenario: Multiple pause-resume cycles
- GIVEN a session paused and resumed three times
- WHEN the session completes
- THEN total elapsed MUST equal the sum of all active intervals

### Requirement: Paused State Restore
The system MUST restore the Paused state correctly across process death or app restart.

#### Scenario: Paused state survives process death
- GIVEN a session in Paused state with 5:32 remaining
- WHEN the app process is killed and relaunched
- THEN the session MUST show 5:32 remaining in Paused state

### Requirement: Start-to-Stop Race Condition
The system MUST handle concurrent start and stop signals without corruption.

#### Scenario: Stop signal arrives during start
- GIVEN a start signal is in flight
- WHEN a stop signal is received before start completes
- THEN the session MUST end with no orphaned timer

#### Scenario: Duplicate start signals ignored
- GIVEN a session already started
- WHEN duplicate start signals arrive
- THEN only one timer MUST be active

### Requirement: Silent Completion When Notifications Denied
The system MUST complete the session silently when notification permission is denied.

#### Scenario: Completion without permission
- GIVEN notification permission is denied
- WHEN the focus timer reaches zero
- THEN the session MUST complete with status COMPLETED
- AND no notification MUST be sent or crash triggered