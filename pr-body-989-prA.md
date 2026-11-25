Closes #989
Delivery: partial

## Summary
- PR-A of the chain documented in the issue and `odd/tasks/989-task-sync-contract.md`: the task contract and the backend now cover the fields clients kept locally — `dueDate`, `completedAt`, `scheduledForToday`, `sortOrder` — while the overloaded legacy `finishDate` stays mirrored for old clients (deprecated in the contract).
- Migration `000020_task_sync_dates` adds the four columns, backfills them from `finish_date` with a completion-window heuristic, normalizes the legacy energy vocabulary (`Deep/Regular/Light`, `low/medium/high`) onto the canonical `deep/shallow/admin` enum, and adds a CHECK constraint.
- Android already sends `dueDate`/`scheduledForToday`/`sortOrder` (its DTO predates the contract): starting with this deploy those values persist and round-trip with no client change. iOS and web keep their current wire behavior; PR-B (iOS+Android `finishDate` retirement) and PR-C (web + shared fixture, S7) complete S4–S7.
- Known residual (documented, fixed by PR-B): iOS does not send the new fields yet, so an iOS LWW win still erases `due_date`/`completed_at` on that row (full-row save with NULLs). Strictly better than today, when those values never reached the server at all.

## Platform Parity
- iOS: Not impacted (wire behavior unchanged; PR-B migrates the Apple client)
- watchOS: Not impacted (same as iOS)
- macOS: Not impacted (same as iOS)
- Android: Impacted — uploads of `dueDate`/`scheduledForToday`/`sortOrder` now persist and return on pull; no code change needed
- Wear OS: Not impacted (inherits the Android app behavior)
- Backend: Impacted — schema, sync upserts, read paths and recurrence generation

## Decisions Made Without Asking
- Backfill heuristic: `due_date := finish_date` for unfinished rows, and for finished rows only when `finish_date` is NOT within 1 hour of `updated_at`; `completed_at := finish_date` for finished rows within the window. Rationale: Android stamps the completion instant right before upload while Apple preserves the due date; rehearsed against all four legacy row shapes on a scratch DB (evidence in the verification file).
- `energyLevel` stays a documented string (not a strict enum) in PR-A to keep `contracts-diff` green; the enum lands in PR-C once all clients normalize.
- Empty-string energy becomes NULL; unknown values fail safe to `shallow` (never `deep`).
- Recurring instances now mirror the canonical `dueDate` and inherit the template's `sortOrder` (parity with Android local generation).

## Verification Evidence
- Level (`V0` | `V1` | `V2`): `V2`
- Commands executed and observed output:
  - `make contracts-lint`: 0 errors (90 pre-existing warnings)
  - `make contracts-diff`: "No breaking changes to report"
  - `go test ./...` (backend): 14 packages ok, 0 FAIL — RED observed first (missing symbols) before implementation
  - `make test` (factory guardrails + backend): PASS
  - Migrations `000001..000020` applied clean on a scratch DB; backfill heuristic rehearsed against iOS/Android finished+unfinished shapes; `down` verified to restore state 000019
  - `TASK_TEST_DATABASE_URL=... go test -run TestTaskSyncPersistsAndNormalizesNewFields -v`: PASS against a real database (round-trip of the 4 fields, energy normalization, COALESCE reads); SKIPs without the env (CI-safe)
  - Full evidence: `verification-989-prA.txt` in the worktree

## Commits (Work Units)
- `36f3e6f1` feat(contracts): add dueDate, completedAt, scheduledForToday and sortOrder to the Task schema — S1, contract-first
- `7e2a7ed7` feat(backend): persist canonical task date/order fields and normalize energy levels — S2/S3 + artifact

## Visual Evidence
N/A

## Clean-Context Review Handoff
- **Base SHA**: `a491ee33`
- **Head SHA**: `7e2a7ed7`
- **Scope Digest (SHA-256)**: `77a98d55bd2e`
- **Independent Reviewer Verdict**: PENDING → dual blind review (judgment-day, `contracts/**` + migration triggers). Consolidated verdict recorded here before human merge.

## PRD Impact
- Classification: No PRD update required
- Files changed:
  - (none — no user-facing behavior changes in PR-A; `docs/product-map.md` §Tareas and the contract are updated in PR-B/PR-C when clients ship the fields)

## Rollback
- Revert the commits listed above; migration has a symmetric `down` (`000020_task_sync_dates.down.sql`, rehearsed). Backfilled values are not recoverable after a `down` on prod (documented in the migration header) — rollback before clients rely on the columns.

## Risk
Risk: item 1 (migration backfills due_date/completed_at on existing prod rows; rehearsed up/down on scratch DBs) and item 3 (contract consumed by four clients; change verified additive with oasdiff and old clients keep the mirrored finishDate)

## Checklist
- [x] CI green on every touched surface
- [x] Tests ship with the behavior they verify
- [x] Docs updated in the same PR (execution artifact `odd/tasks/989-task-sync-contract.md`; contract descriptions)
- [x] ≤ 400 changed lines (487 total — sliced as PR-A of the documented chain; judgment-day dual review triggered and required regardless)
- [x] Scope = this issue only (follow-ups go to new issues)
- [x] Domain invariants in `AGENTS.md` §3 respected (offline-first untouched; contract-first honored)
- [x] No breaking OpenAPI change (oasdiff clean; no `contract-break` label needed)
- [x] Self-review of the full diff done
