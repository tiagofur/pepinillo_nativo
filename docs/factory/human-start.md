# Human & Agent Operational Guide (`human-start.md`)

This document defines how human operators and autonomous agents collaborate inside the Software Factory from **Day 0 project initialization** to **merged Pull Requests**.

---

## 1. Day-0 Project Bootstrap (`init-project.sh`)

When starting a new repository from this template, initialize its topology and manifest before creating feature issues:

```bash
./scripts/init-project.sh \
  --name my-product \
  --db postgres \
  --surfaces backend,web,desktop-tauri
```

### Supported Flags
- `--name <slug>`: Project identifier written to `factory.manifest.json`.
- `--db <postgres|sqlite|custom>`: Selects the primary persistence strategy under [`ADR-0001`](../architecture/adr/ADR-0001-go-backend-and-db-matrix.md).
- `--surfaces <csv>`: Comma-separated list of active surfaces (`backend`, `web`, `desktop-tauri`, `mobile-tauri`, `ios-native`, `android-native`) governed by [`ADR-0002`](../architecture/adr/ADR-0002-client-surfaces-and-mobile-matrix.md).
- `--non-interactive`: Runs without prompts (required for CI and automated tests).

After initialization, synchronize GitHub labels once:
```bash
./scripts/setup-labels.sh
```

---

## 2. GitHub Issues as the Single Work Queue

GitHub Issues is the **only** operational backlog. Agents never invent tasks from `TODO` comments or `feature_list.json` (`feature_list.json` is capability context only).

### Issue Lifecycle State Machine

```text
[status:new] ──(explorer triage + DoR check)──► [status:ready]
                                                       │
                                      (leader assigns implementer)
                                                       ▼
[status:blocked] ◄──(missing external input)── [status:in-progress]
                                                       │
                                    (C1-C3 pass + C4 clean-context review)
                                                       ▼
                                          [status:in-review / PR open]
                                                       │
                                        (C5 metadata + CI + human merge)
                                                       ▼
                                                   [Closed]
```

### Definition of Ready (DoR) Checklist
Before an issue transitions from `status:new` to `status:ready`, `explorer` verifies:
1. Clear problem statement and user/system outcome.
2. Numbered, testable acceptance criteria (`S1`, `S2`, ...).
3. Explicit **Out of Scope / Exclusions** section.
4. Required labels: one `type:*`, one `priority:p0..p2`, one `size:xs..l`, and `ux:shape` when user-facing flows change.

---

## 3. Portable ODD Execution Topologies

Once an issue is authorized, the `leader` selects the lightest ODD topology that preserves safety:

| Topology | Selection Criteria | State Artifact | Commit Strategy |
| :--- | :--- | :--- | :--- |
| **Inline Direct** | Small, understood change with contained risk (no High-Risk Item from `CHECKPOINTS.md` C3), resumable from the request + `git diff` alone. File count never decides topology. | None (`git diff` + Issue are sufficient) | Single atomic Conventional Commit |
| **Delegated Direct** | Multi-unit feature, parallel disjoint edit surfaces (`backend` + `web`), or cross-session work | `odd/tasks/<issue>-<slug>.md` (mirrored to Engram when available) | One atomic work-unit commit per completed task (`T1..Tn`) |

### `odd/tasks/<issue>-<slug>.md` Contract
When **Delegated Direct** is active, the task file contains:
- **`## Specs (`S1..Sn`)`**: Mapped directly from the GitHub Issue acceptance criteria, with concrete verification commands.
- **`## Allowed edit surfaces`**: Exact directory/file whitelist for each delegated writer. Writers refuse to touch any path outside this list.
- **`## Tasks (`T1..Tn`)`**: Bounded work units linking `S#`, execution route (`inline` or `delegated`), verification result, `Risk:` note, and commit SHA.
- **`## Log`**: Chronological audit trail of user decisions and architectural milestones.

---

## 4. Proportional Verification Matrix (`V0` / `V1` / `V2`)

Every work unit must prove correctness in the foreground before committing:

| Verification Tier | When Required | Mandatory Commands |
| :--- | :--- | :--- |
| **V0 — Structural** | Docs, ADRs, markdown templates, non-executable config | `python3 scripts/factory_preflight.py` + file/link checks |
| **V1 — Focused RED/GREEN** | Standard application logic, UI components, bug fixes | Observe deterministic failing test (**RED**) → implement minimal fix (**GREEN**) → run module tests + linter |
| **V2 — Contract & Integration** | OpenAPI changes, DB schema/queries, auth, concurrency, CI/factory scripts | V1 + `make contracts-lint contracts-diff` + container/SQLite integration suite + `make test` |

---

## 5. Assertiveness Contract ("Process Default Beats Asking")

Agents are engineered to maximize autonomous flow without reckless guessing:

1. **Resolve Technical Choices via Stack Defaults**:
   - If an issue does not specify a router, validation library, error format, or folder layout, follow `docs/architecture/adr/` and `docs/stack/` defaults immediately.
   - Document every autonomous technical choice under `## Decisions Made Without Asking` in the PR body.
2. **When to Pause (`status:blocked` + `needs-human`)**: only for the closed list in [`CHECKPOINTS.md`](../../CHECKPOINTS.md) § Escalation Contract.

---

## 6. Clean-Context Review & Human Merge (`C4`–`C5`)

1. When implementation and `V0`/`V1`/`V2` checks complete, save their output to a file and generate the deterministic review bundle (fails closed with `HANDOFF_BLOCKED` if acceptance criteria or evidence are missing):
   ```bash
   python3 scripts/factory_handoff.py --base origin/main --head HEAD --issue <ISSUE_NUMBER> --verification-file /tmp/verification.txt --out /tmp/handoff.md
   ```
2. Invoke the independent `reviewer` with **only** `/tmp/handoff.md` (zero implementer chat history).
3. If the bundle reports `judgment_day_required: True`, or the diff semantically hits a trigger in [`CHECKPOINTS.md`](../../CHECKPOINTS.md) C4.4, run blind dual review (`judgment-day`).
4. Validate PR metadata before opening or updating the PR (requires real SHAs, scope digest, and an `APPROVED` verdict):
   ```bash
   python3 scripts/check_pr_metadata.py --body-file /tmp/pr_body.md
   ```
5. Report `PR_READY_FOR_HUMAN_MERGE` once `C1`–`C5` and CI checks are green.
