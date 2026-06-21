#!/bin/bash
set -e

create_issue() {
  local title="$1"
  local body="$2"
  echo "Creating issue: $title"
  gh issue create --title "$title" --body "$body" --label "bug"
}

# Issue 1: Silent data loss on transient errors (Quarantine logic)
create_issue "fix(ios): prevent silent database quarantine and data loss on transient SQLite locks" "### Pre-flight Checks
- [x] I have searched existing issues and this is not a duplicate
- [x] I understand this issue needs status:approved before a PR can be opened

### Bug Description
Any failure during \`makeModelContainer\` unconditionally triggers \`quarantineCorruptedStoreIfPresent()\`. This renames the database and resets it, causing silent user data loss on transient locks (like \`SQLITE_BUSY\`) instead of retrying or falling back safely.

### Affected Files
- \`ios/Shared/Persistence/AppGroupContainer.swift\` (line 609-623)

### Expected Behavior
Verify actual corruption via \`PRAGMA integrity_check\` before executing the quarantine rename.

### Operating System
macOS"

# Issue 2: Multiple ModelContainer instances created by widgets and intents
create_issue "perf(ios): cache ModelContainer singleton in widgets and intents to avoid lock contention" "### Pre-flight Checks
- [x] I have searched existing issues and this is not a duplicate
- [x] I understand this issue needs status:approved before a PR can be opened

### Bug Description
Widget providers (\`DashboardWidgetProvider\`, \`TasksWidgetProvider\`, \`FocusWidgetProvider\`) and Siri App Intents (\`CheckStatsIntent\`, etc.) construct a new \`ModelContainer\` instance from scratch on every timeline or intent run. This creates concurrent database connections to the same file, leading to lock contention (\`SQLITE_BUSY\`), extreme startup lag, and resource leaks.

### Affected Files
- \`ios/PepinilloWidget/DashboardWidgetProvider.swift\` (line 45)
- \`ios/PepinilloWidget/TasksWidgetProvider.swift\` (line 34)
- \`ios/PepinilloWidget/FocusWidgetProvider.swift\` (line 38)

### Expected Behavior
Cache and reuse a single shared \`ModelContainer\` instance as a static property.

### Operating System
macOS"

# Issue 3: Undefined SwiftUI APIs GlassEffectContainer used in iOS 26 checks
create_issue "fix(ios): resolve compile risks and missing definitions for GlassEffectContainer" "### Pre-flight Checks
- [x] I have searched existing issues and this is not a duplicate
- [x] I understand this issue needs status:approved before a PR can be opened

### Bug Description
The codebase references \`GlassEffectContainer\`, \`.glassEffect\`, and \`.glassEffectID\` which are undefined in the main codebase and are placed under \`#available(iOS 26.0, *)\` guards. This can lead to compilation failures depending on target SDK and build setup.

### Affected Files
- \`ios/Shared/Design/GlassModifiers.swift\` (lines 23, 46, 47, 88, 94, 132)
- \`ios/Features/Focus/FocusView.swift\` (lines 192, 205)
- \`ios/Features/Plan/PlanFilterPills.swift\` (line 16)

### Expected Behavior
Define the missing views/modifiers or replace them with standard SwiftUI styling.

### Operating System
macOS"

# Issue 4: WindowGroup .defaultSize modifier used without compile guards
create_issue "fix(ios): wrap defaultSize scene modifier in compile guards" "### Pre-flight Checks
- [x] I have searched existing issues and this is not a duplicate
- [x] I understand this issue needs status:approved before a PR can be opened

### Bug Description
The \`.defaultSize\` modifier is called unconditionally on \`WindowGroup\` in \`PepinilloApp.swift\`. This modifier is only available on macOS 13.0+ and visionOS, and is not available on iOS. This causes compile warnings/errors depending on target SDK environment.

### Affected Files
- \`ios/App/PepinilloApp.swift\` (line 348)

### Expected Behavior
Wrap the \`.defaultSize\` modifier in \`#if os(macOS)\` compile guards.

### Operating System
macOS"

# Issue 5: SQLite connection handle leak in checkpointWAL on open failure
create_issue "fix(ios): prevent sqlite3 connection leaks in checkpointWAL when open fails" "### Pre-flight Checks
- [x] I have searched existing issues and this is not a duplicate
- [x] I understand this issue needs status:approved before a PR can be opened

### Bug Description
When opening the database via \`sqlite3_open_v2\`, a connection handle can be allocated even if an error is returned. Returning from the guard block without calling \`sqlite3_close(db)\` leaks this handle and the associated file descriptor.

### Affected Files
- \`ios/Shared/Persistence/AppGroupContainer.swift\` (line 765)

### Expected Behavior
Store the return code of \`sqlite3_open_v2\`, and call \`sqlite3_close(db)\` if \`db != nil\` before returning on failure.

### Operating System
macOS"

# Issue 6: Background checkpointing task missing execution assertion
create_issue "fix(ios): wrap background WAL checkpointing in UIApplication background task assertion" "### Pre-flight Checks
- [x] I have searched existing issues and this is not a duplicate
- [x] I understand this issue needs status:approved before a PR can be opened

### Bug Description
When backgrounding, the app dispatches \`checkpointWAL\` on a global utility queue. Since this is not wrapped in an OS background execution assertion (\`UIApplication.shared.beginBackgroundTask\`), the system can suspend the process mid-write, potentially corrupting or locking the SQLite database.

### Affected Files
- \`ios/App/PepinilloApp.swift\` (lines 292-294)

### Expected Behavior
Wrap the background WAL checkpointing task in a \`beginBackgroundTask\` and \`endBackgroundTask\` block.

### Operating System
macOS"

# Issue 7: Soft-deleted tasks uploading loop
create_issue "fix(ios): sync deleted task state to server to prevent infinite upload cycles" "### Pre-flight Checks
- [x] I have searched existing issues and this is not a duplicate
- [x] I understand this issue needs status:approved before a PR can be opened

### Bug Description
Soft-deleted tasks (\`isDeleted = true\`) are pushed to the server, but their sync IDs are not included in the \`markTasksSynced\` call. As a result, soft-deleted tasks are never marked clean (\`isDirty = false\`) and are never purged from the local database, causing them to be uploaded repeatedly during every sync cycle.

### Affected Files
- \`ios/Domain/Clients/SyncClient.swift\` (line 93)

### Expected Behavior
Include \`deletedSyncIds\` in \`markTasksSynced\` to clear their dirty flag and allow the purge step to run.

### Operating System
macOS"

# Issue 8: Sequential N+1 subtask and session queries during task sync
create_issue "perf(ios): batch subtask and session queries during task sync to resolve N+1 latency" "### Pre-flight Checks
- [x] I have searched existing issues and this is not a duplicate
- [x] I understand this issue needs status:approved before a PR can be opened

### Bug Description
Inside the \`syncTasks\` task loop, the client makes sequential calls to fetch subtasks and sessions for each task. This causes N+1 database queries, resulting in high synchronization latency.

### Affected Files
- \`ios/Domain/Clients/SyncClient.swift\` (lines 109-122)

### Expected Behavior
Batch query the subtasks and sessions, or perform a single join query.

### Operating System
macOS"

# Issue 9: Fetching all tasks into memory to filter by ID in WidgetIntents
create_issue "perf(ios): use fetch predicate and limit for task lookups in widget intents" "### Pre-flight Checks
- [x] I have searched existing issues and this is not a duplicate
- [x] I understand this issue needs status:approved before a PR can be opened

### Bug Description
In \`taskTitle(for:)\` and \`CompleteTaskFromWidgetIntent.perform()\`, the database queries fetch *all* tasks into memory to filter them by ID. If the user has a large task list, this causes high memory usage and latency on widget interactions.

### Affected Files
- \`ios/PepinilloWidget/WidgetIntents.swift\` (lines 200, 242)

### Expected Behavior
Fetch tasks with a specific \`#Predicate\` matching the task UUID and set \`fetchLimit = 1\`.

### Operating System
macOS"

# Issue 10: Streak protection logic covers first miss for users with no focus history
create_issue "fix(ios): prevent streak protection from covering users with zero focus history" "### Pre-flight Checks
- [x] I have searched existing issues and this is not a duplicate
- [x] I understand this issue needs status:approved before a PR can be opened

### Bug Description
If a user has never completed a single focus session (all values in \`focusByDay\` are false), \`earliestFocusDate\` defaults to \`startDate\` (today/yesterday). This allows Pro streak protection to cover the first \"miss\", giving a user who has never focused a streak of 1 day instead of 0.

### Affected Files
- \`ios/Domain/Services/StreakProtectionService.swift\` (line 81)

### Expected Behavior
Return \`.zero\` immediately if there are no days with \`hadFocus == true\` in the history dictionary.

### Operating System
macOS"

echo "All issues created successfully!"
