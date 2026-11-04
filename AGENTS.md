# AGENTS.md — Pepinillo Agentic Software Factory Routing Map

Pepinillo is a multi-platform **deep work / focus + tasks** product in the **Growth Validation Phase** (priorities: Activation, Retention, Monetization, Reliability).
Development is governed by an **Agentic Software Factory** with **Organic Driven Development (ODD)** and **Contract-First OpenAPI 3.1**.

---

## 1. Hierarchy of Truth (Strict Order)

1. **Architecture Decision Records (`docs/architecture/adr/`)** — Active ADRs are binding. Propose a new ADR for structural shifts.
2. **Product Source of Truth (`PRD/`) & Executable Contracts (`contracts/openapi.yaml`)** — `PRD/09_CURRENT_STATUS.md` is live product status; OpenAPI is single source for HTTP APIs and RFC 9457 errors.
3. **Strategy & Operational Docs (`docs/strategy/`, `docs/`)** — Product direction, growth validation, platform decisions (`docs/strategy/PLATFORM_DECISIONS.md`).
4. **Existing Code** — Follow established patterns, never overriding tiers 1–3.

---

## 2. Start & Authorization Protocol

1. **Establish Authority**: GitHub Issues in `status:ready` or `status:approved` are the **sole operational work queue**.
2. **Read Cognitive Role Skill**: Load assigned role from `.agents/skills/<role>/SKILL.md` and check `.atl/skill-registry.md`.
3. **Run Read-Only Preflight**:
   ```bash
   python3 scripts/factory_preflight.py
   ```
4. **Scope Reads**: Read only affected platforms and stack standards. Never scan `odd/tasks/` globally at startup.

---

## 3. Portable ODD Execution Topologies

The repository enforces deterministic gates `C1`–`C5` ([`CHECKPOINTS.md`](CHECKPOINTS.md)):

| ODD Topology | When to Use | Execution Artifact |
| :--- | :--- | :--- |
| **Inline Direct** | Small, bounded change with contained risk; resumable from request + `git diff` | **None** (observe RED → GREEN, run focused test suite) |
| **Delegated Direct** | Multi-unit, cross-session, or cross-platform authorized work | **Single `odd/tasks/<issue>-<slug>.md`** |

### Core Factory Invariants
- **Single Writer per Unit**: Every issue has at most one active `implementer` bounded by declared `## Allowed edit surfaces`.
- **Stateless Clean-Context Review (`C4`)**: The independent `reviewer` **never** reads the implementer's chat transcript. It evaluates only the bundle from `python3 scripts/factory_handoff.py`.
- **Automatic Blind Dual Review (`judgment-day`)**: High-risk diffs (auth, security, migrations, contracts, or >400 lines) escalate to two independent judges.
- **Assertiveness Contract**: Resolve details using `docs/` and log under `## Decisions Made Without Asking` in PR body.

---

## 4. Cognitive Roles & Stack Skills

| Role / Stack | Skill Path | Reference Standard |
| :--- | :--- | :--- |
| **Leader / Orchestrator** | `.agents/skills/leader/SKILL.md` | `docs/factory/human-start.md` |
| **Explorer & Issue Triage (DoR)** | `.agents/skills/explorer/SKILL.md` | `docs/factory/human-start.md` |
| **Implementer (Sole Writer)** | `.agents/skills/implementer/SKILL.md` | `CHECKPOINTS.md` |
| **Independent Reviewer (Clean Context)** | `.agents/skills/reviewer/SKILL.md` | `docs/factory/clean-context-review.md` |
| **UX Brief (`ux:shape` issues)** | `.agents/skills/ux-brief/SKILL.md` | `CHECKPOINTS.md` (C1, C5) |
| **Go Backend** | `.agents/skills/go-backend/SKILL.md` | `backend/`, `ADR-0001` |
| **iOS / watchOS Native** | `.agents/skills/ios-native/SKILL.md` | `ios/` (Swift 6, TCA, SwiftUI) |
| **Android / Wear OS Native** | `.agents/skills/android-native/SKILL.md` | `android/` (Kotlin, Jetpack Compose) |

---

## 5. Platform Invariants & Rules

- **Active Platforms**: iOS, Android, watchOS, Wear OS, Go Backend.
- **Paused Experiments**: Windows and Web are **not active roadmap work**; do not expand them without explicit roadmap approval.
- **Cross-Platform Parity**: Fixes/features affecting timer or session state must preserve parity across iOS, Android, Wear OS, and watchOS.
- **Secrets**: Never commit API keys (`REVENUECAT_SECRET_KEY`, etc.). Use env/CI only.
- **Commits**: Conventional Commits in **English** (`feat:`, `fix:`, `refactor:`, ...). **No AI co-author trailers.**
- **File Budget**: Respect the ~500-line cognitive cap (`docs/agent-first-methodology.md`).

---

## 6. Quick Commands

```bash
make preflight        # Read-only factory health check (C1)
make test             # Run factory guardrails and backend tests (C3)
make test-factory     # Run factory script unit tests
make test-android     # Run Android and Wear OS unit tests
make test-backend     # Run Go backend unit tests
make contracts-lint   # Lint contracts/openapi.yaml with Spectral (C2)
make contracts-diff   # Check breaking OpenAPI changes against origin/main (C2)
make handoff          # Generate stateless clean-context review bundle (C4)
make labels           # Synchronize GitHub factory labels
```
