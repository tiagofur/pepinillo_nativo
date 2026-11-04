# Agent-First Codebase Methodology

An **Agent-First Codebase** is engineered simultaneously for human maintainability and LLM cognitive reliability.
Modern coding agents fail far more often from **context pollution**, **monolithic files**, and **ambiguous implicit conventions** than from raw reasoning limitations.

---

## 1. Scientific Foundations

Our repository rules are grounded in empirical research on Large Language Model (LLM) attention and Agent-Computer Interfaces (ACI):

1. **Lost in the Middle (Liu et al., 2023)**:
   - Transformer attention follows a U-shaped recall curve: information at the very beginning and very end of a context window is retrieved reliably, while constraints buried in the middle of a 2,000-line file or a 50-turn chat transcript suffer steep recall degradation.
   - **Factory Countermeasure**: Keep files under a soft **~500-line cognitive budget** and keep `AGENTS.md` under 150 lines so critical invariants always sit near attention peaks.
2. **Context Rot & Rationale Contamination (Chroma / Anthropic ACI Research)**:
   - As an agent iterates on a problem, failed hypotheses, verbose stack traces, and self-justifications accumulate in the session transcript. If the same session reviews its own code—or passes its chat history to a reviewer—the reviewer inherits the implementer's blind spots ("gaslighting by rationale").
   - **Factory Countermeasure**: Enforce **Stateless Clean-Context Review** (`docs/factory/clean-context-review.md`). The reviewer inspects only the deterministic diff packet produced by `scripts/factory_handoff.py`.
3. **Agent-Computer Interface (ACI) Design (SWE-agent, Yang et al., 2024)**:
   - Agents perform best when repository navigation is deterministic, error messages are machine-actionable, and verification commands return concise pass/fail signals.
   - **Factory Countermeasure**: Standardized `Makefile` targets (`make preflight`, `make test`, `make contracts-lint`, `make handoff`) and fail-closed Python guardrails.

---

## 2. Structural Rules for Every Surface

### 2.1 The ~500-Line Cognitive Budget
- **Soft Cap**: Production source files should stay between **150 and 500 lines**.
- **Hard Trigger**: Any file exceeding **500 lines** requires an explicit cohesion check before adding new logic. If a file mixes transport, domain policy, and persistence, split it along responsibility boundaries.
- **Anti-Fragmentation Guard**: Do not create twenty 15-line files that force an agent to open ten files to trace one function call. Group cohesive types and their primary methods in a single domain file.

### 2.2 Screaming / Vertical-Slice Organization
Organize directories by **domain capability** (`internal/modules/billing/`, `src/features/invoicing/`) rather than generic horizontal layers (`controllers/`, `models/`, `utils/`).
- An agent assigned to an issue in `billing` should be able to read 3–5 files in one directory and hold the entire vertical slice in working memory.
- Forbidden catch-all names: `utils.go`, `helpers.ts`, `common.py`, `misc.rs`. Name files after their concrete responsibility (`money_format.go`, `rfc9457_error.ts`, `pagination_cursor.go`).

### 2.3 Greppable, Unambiguous Symbol Names
Agents navigate primarily via `grep` / `ripgrep` and symbol search before opening full files:
- Prefer explicit, globally searchable symbol names (`CreateInvoiceCommand`, `PostgresInvoiceRepository`, ` useInvoiceListQuery`) over overloaded generic names (`Manager`, `Handler`, `Process`, `Data`).
- Exported functions and types must have deterministic signatures and explicit error types so callers never have to read the implementation body just to learn what errors can occur.

### 2.4 Explicit Module Boundaries & Dependency Direction
Dependencies always point **inward** toward pure domain logic:
```text
Transport / UI Adapter (HTTP, Tauri Command, CLI, React View)
        │
        ▼
Application / Use-Case Service (Orchestration, Transactions, Ports)
        │
        ▼
Domain Model (Pure Entities, Value Objects, Invariants — zero I/O imports)
```
Database adapters (`postgres`, `sqlite`), external HTTP clients, and OS bridges implement interfaces defined by the Application/Domain layer.

---

## 3. Progressive Disclosure Context Loading

Never dump the entire `docs/` tree into an agent's prompt:

1. **Level 0 — Root Map**: Read `AGENTS.md` (<150 lines) and `factory.manifest.json`.
2. **Level 1 — Role Skill**: Load only `.agents/skills/<assigned-role>/SKILL.md`.
3. **Level 2 — Stack Skill & ADR**: Load only the stack skill and ADR matching the touched files (e.g., `.agents/skills/go-backend/SKILL.md` + `ADR-0001` when editing `backend/`).
4. **Level 3 — Scoped Source Files**: Read only the files inside `## Allowed edit surfaces` and their direct contract/interface dependencies.

---

## 4. Legacy & Monolithic File Touch Protocol

When an authorized task requires modifying an existing file that already exceeds 500 lines:
1. **Do not rewrite the world**: Keep your diff bounded to the authorized issue scope.
2. **Extract the touched seam**: If you are adding a new handler, query, or validator to an oversized file, place the new cohesive unit in a dedicated sibling file within the same package/module.
3. **Respect the 400-Line Review Budget**: Keep each PR slice around **≤400 changed lines** (`.agents/skills/work-unit-commits/SKILL.md` and `.agents/skills/chained-pr/SKILL.md`). If a structural extraction would exceed the budget, split the mechanical extraction commit from the behavior change commit.
