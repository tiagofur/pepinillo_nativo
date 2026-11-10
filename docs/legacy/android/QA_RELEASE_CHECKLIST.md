# Android + Wear OS — Pre-Release QA Checklist

## Execution info

| Field | Value |
|---|---|
| Date | |
| Tester | |
| Phone model | |
| Phone Android version | |
| Watch model | |
| Watch Wear OS version | |
| App version (phone) | |
| App version (wear) | |

---

## Legend

| Status | Meaning |
|---|---|
| ✅ PASS | Works as expected |
| ❌ FAIL | Does not work — block release |
| ⚠️ WARN | Works but degraded — evaluate risk |
| ⬜ SKIP | Not applicable |

---

## Section 1 — Preconditions

| # | Check | Status | Notes |
|---|---|---|---|
| P1 | Phone and watch paired and connected | | |
| P2 | User logged in on phone | | |
| P3 | App installed on both devices (release build) | | |
| P4 | Clocks synced (correct time on both devices) | | |

---

## Section 2 — Initial Sync

| # | Scenario | Expected | Status | Notes |
|---|---|---|---|---|
| S1 | Open phone app, then open watch app | Watch shows current timer, tasks and stats from phone | | |
| S2 | Phone has a linked task → open watch | Watch shows the correct linked task name | | |
| S3 | Kill watch app, reopen | Last known state shown (no blank/default state) | | |
| S4 | Kill phone app, reopen | Timer and tasks still visible on watch (snapshot from last sync) | | |

---

## Section 3 — Timer Commands (Watch → Phone)

| # | Action on Watch | Expected on Phone | Status | Notes |
|---|---|---|---|---|
| T1 | Start Pomodoro | Phone timer starts in Pomodoro mode | | |
| T2 | Pause timer (while running) | Phone timer pauses | | |
| T3 | Resume timer (while paused) | Phone timer resumes | | |
| T4 | Skip phase | Phone advances to next phase | | |
| T5 | Stop timer | Phone timer stops and returns to Idle | | |
| T6 | Start Flowtime | Phone timer starts in Flowtime mode | | |
| T7 | Start Time Block | Phone timer starts in Time Block mode | | |
| T8 | Start Stopwatch | Phone timer starts in Stopwatch mode | | |

---

## Section 4 — Timer Sync (Phone → Watch)

| # | Action on Phone | Expected on Watch | Status | Notes |
|---|---|---|---|---|
| P1 | Start timer | Watch updates to Running state within ~2s | | |
| P2 | Pause timer | Watch updates to Paused state | | |
| P3 | Phase ends naturally | Watch vibrates double pulse | | |
| P4 | Phase ends — watch timer shows next phase | Watch tile and complication update | | |
| P5 | Stop timer | Watch updates to Idle | | |

---

## Section 5 — Task Operations

| # | Action | Expected | Status | Notes |
|---|---|---|---|---|
| TK1 | Complete a task from watch | Task disappears on watch, marked done on phone | | |
| TK2 | Link a task from watch | Linked task name shows on both phone and watch | | |
| TK3 | Unlink a task from watch | Task unlinked on both devices | | |
| TK4 | Add a task on phone | New task appears on watch after sync | | |

---

## Section 6 — Offline / Reconnect (critical)

| # | Scenario | Expected | Status | Notes |
|---|---|---|---|---|
| R1 | Disconnect watch, run 2-3 commands (Pause/Resume/Skip), reconnect | Queued commands execute on reconnect, final state consistent | | |
| R2 | Disconnect watch mid-session (timer running), reconnect | Watch resumes displaying correct running timer | | |
| R3 | Watch shows "Disconnected" when phone Bluetooth is off | Disconnected state shown, no crash | | |
| R4 | Phone Bluetooth off → back on | Watch sync resumes automatically | | |

---

## Section 7 — Tiles and Complications

| # | Surface | Expected | Status | Notes |
|---|---|---|---|---|
| TC1 | Focus tile | Shows current timer state; updates after phone action | | |
| TC2 | Tasks tile | Shows current task list; updates after sync | | |
| TC3 | Focus complication | Shows correct timer state (SHORT_TEXT, LONG_TEXT, RANGED_VALUE) | | |

---

## Section 8 — Theme Sync

| # | Scenario | Expected | Status | Notes |
|---|---|---|---|---|
| TH1 | Change theme on phone | Watch updates theme colors after sync | | |
| TH2 | Cold start watch after theme change | Watch shows correct theme colors from snapshot | | |

---

## Section 9 — Cold Start / App Lifecycle

| # | Scenario | Expected | Status | Notes |
|---|---|---|---|---|
| L1 | Force close watch app, reopen | Last state visible within 1s (no blank screen) | | |
| L2 | Force close both apps, open watch first | Watch shows last persisted state | | |
| L3 | Phone killed (process), watch still open | Watch shows Disconnected, no crash | | |
| L4 | Reboot phone, open watch | Watch auto-syncs on phone reconnect | | |

---

## Section 10 — Stability

| # | Check | Expected | Status | Notes |
|---|---|---|---|---|
| ST1 | 0 ANRs during testing | No ANR dialogs | | |
| ST2 | 0 crashes on phone | Logcat clean from fatal exceptions | | |
| ST3 | 0 crashes on watch | Watch logcat clean from fatal exceptions | | |
| ST4 | Pending commands count resets to 0 after reconnect | No leaked commands in diagnostics | | |

---

## Go / No-Go Decision

| Criterion | Result |
|---|---|
| All Section 6 (Reconnect) items: PASS | |
| All Section 3 timer commands: PASS | |
| 0 crashes / ANRs (Section 10) | |
| States consistent phone↔watch after all scenarios | |

**Overall decision:**
- [ ] ✅ GO — release approved
- [ ] ❌ NO-GO — issues blocking release (list below)

### Blocking issues

| # | Description | Severity | Assigned to |
|---|---|---|---|
| | | | |

---

## Relevant commands for build validation

```bash
# Unit tests
cd android && ./gradlew :app:testDebugUnitTest :wear:testDebugUnitTest --console=plain

# Debug build pair
cd android && ./gradlew :app:assembleDebug :wear:assembleDebug --console=plain

# Release build pair
cd android && ./gradlew :app:assembleRelease :wear:assembleRelease --console=plain

# Wear sync validation script
powershell -ExecutionPolicy Bypass -File scripts/validate_wear_sync.ps1
```
