# Pepinillo

Multi-platform **deep work / focus + tasks** product built with native mobile apps, wearable companions, and a lightweight Go backend.

Governed by an **Agentic Software Factory** with **Organic Driven Development (ODD)**, **Contract-First OpenAPI 3.1**, and **Stateless Clean-Context Reviews**.

---

## Architecture & Platforms

| Platform | Technology Stack | Status |
| :--- | :--- | :--- |
| **iOS / watchOS** | Swift 6, The Composable Architecture (TCA), SwiftUI | Active |
| **Android / Wear OS** | Kotlin, Jetpack Compose, Coroutines / Flow | Active |
| **Backend** | Go REST API | Active |
| **Windows Desktop** | C# / WinUI 3 / Windows App SDK | Paused experiment |
| **Web** | React + Vite | Paused experiment |

- **Product Source of Truth**: [`PRD/`](PRD/) (features, decisions, status in `PRD/09_CURRENT_STATUS.md`).
- **Operational Docs**: [`docs/`](docs/) & [`docs/strategy/`](docs/strategy/).

---

## Agentic Software Factory

Pepinillo uses strict engineering governance to prevent context rot, unapproved work, and self-review bias:

1. **Strict Authority**: GitHub Issues (`status:ready` / `status:approved`) are the sole authorized work queue.
2. **Cognitive Role Agents** ([`.agents/skills/`](.agents/skills/)):
   - `leader`: Orchestrates ODD execution and checkpoints `C1`–`C5`.
   - `explorer`: Read-only codebase mapping (<2k tokens) and Issue Triage / DoR.
   - `implementer`: Sole bounded writer per edit surface; follows TDD (V0/V1/V2).
   - `reviewer`: Stateless independent reviewer; never reads implementer chat history.
3. **Deterministic Checkpoints** ([`CHECKPOINTS.md`](CHECKPOINTS.md)):
   - `C1`: Preflight health check and Definition of Ready (`factory_preflight.py`).
   - `C2`: Hierarchy of truth (ADRs > PRD > Contracts > Docs > Code).
   - `C3`: Proportional test-first verification (V0, V1, V2) and conventional commits.
   - `C4`: Stateless clean-context review handoff (`factory_handoff.py`) and *Judgment Day* dual review for high-risk changes.
   - `C5`: PR metadata verification (`check_pr_metadata.py`).

---

## Quick Commands

```bash
make preflight        # Read-only factory health & git state check (C1)
make test             # Run factory guardrail tests and backend test suite (C3)
make test-factory     # Run factory script unit tests
make test-android     # Run Android and Wear OS unit tests
make test-backend     # Run Go backend unit tests
make contracts-lint   # Lint contracts/openapi.yaml with Spectral (C2)
make contracts-diff   # Check breaking OpenAPI changes against origin/main (C2)
make handoff          # Generate stateless clean-context review bundle (C4)
make labels           # Synchronize GitHub factory labels (status, type, priority, size)
```
