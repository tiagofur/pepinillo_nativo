# Room Migration Test Coverage Specification

## Purpose
Verify Room database migration correctness and sync critical-path integrity across supported version ranges.

## Requirements

### Requirement: Migration Version Range Coverage
The test suite MUST cover every Room schema migration in the supported upgrade path (MIGRATION_10_11 and earlier) and run against each supported API level.

#### Scenario: Forward migration succeeds
- GIVEN a pre-populated database at schema version N
- WHEN the migration helper applies MIGRATION_N_to_N+1
- THEN the schema MUST match version N+1 without data loss

#### Scenario: Migration skips unsupported downgrade
- GIVEN a database at schema version N+2
- WHEN a downgrade migration to version N is attempted
- THEN the system MUST throw an expected exception

### Requirement: serverId Preservation Through Migration
The migration MUST preserve the `serverId` field for all tasks across schema transitions.

#### Scenario: serverId survives migration
- GIVEN tasks with non-null serverId values in schema N
- WHEN migration to schema N+1 completes
- THEN each task MUST retain its original serverId
- AND serverId MUST NOT be nullified or regenerated

### Requirement: Mode and Phase Mapping Integrity
The migration MUST correctly map mode and phase enum values when schema definitions change.

#### Scenario: Mode enum value mapping
- GIVEN tasks with mode=TIMER in schema N
- WHEN migration maps to new enum representation in schema N+1
- THEN the mode MUST resolve to the correct domain value

#### Scenario: Phase transitions preserved
- GIVEN tasks in various active phases (focus, break, paused)
- WHEN migration completes
- THEN each task MUST retain its original phase state

### Requirement: Dirty Session Skip During Migration
The migration MUST skip or safely handle tasks with dirty session state (incomplete focus session).

#### Scenario: Dirty session task is skipped or fixed
- GIVEN a task with an orphaned active session (no start timestamp)
- WHEN migration runs
- THEN the task MUST be marked idle with no crash
- AND no orphaned session record MUST remain

### Requirement: Multi-Process Room Contract
The system MUST document and test the Room multi-process access contract to prevent concurrent migration corruption.

#### Scenario: Concurrent migration attempt blocked
- GIVEN a migration in progress on process A
- WHEN process B attempts to open the same database
- THEN process B MUST receive a lock or exception, not a partial schema