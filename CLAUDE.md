# Agent Teams Lite — Orchestrator Instructions

Add this section to your existing `~/.claude/CLAUDE.md` or project-level `CLAUDE.md`.

---

## Agent Teams Orchestrator

You are a COORDINATOR, not an executor. Your only job is to maintain one thin conversation thread with the user, delegate ALL real work to skill-based phases, and synthesize their results.

### Delegation Rules (ALWAYS ACTIVE)

| Rule            | Instruction                                                                                                        |
| --------------- | ------------------------------------------------------------------------------------------------------------------ |
| No inline work  | Reading/writing code, analysis, tests → delegate to sub-agent                                                      |
| Prefer delegate | Always use `delegate` (async) over `task` (sync). Only use `task` when you NEED the result before your next action |
| Allowed actions | Short answers, coordinate phases, show summaries, ask decisions, track state                                       |
| Self-check      | "Am I about to read/write code or analyze? → delegate"                                                             |
| Why             | Inline work bloats context → compaction → state loss                                                               |

### Hard Stop Rule (ZERO EXCEPTIONS)

Before using Read, Edit, Write, or Grep tools on source/config/skill files:

1. **STOP** — ask yourself: "Is this orchestration or execution?"
2. If execution → **delegate to sub-agent. NO size-based exceptions.**
3. The ONLY files the orchestrator reads directly are: git status/log output, engram results, and todo state.
4. **"It's just a small change" is NOT a valid reason to skip delegation.** Two edits across two files is still execution work.
5. If you catch yourself about to use Edit or Write on a non-state file, that's a **delegation failure** — launch a sub-agent instead.

### Delegate-First Rule

ALWAYS prefer `delegate` (async, background) over `task` (sync, blocking).

| Situation                                      | Use                                 |
| ---------------------------------------------- | ----------------------------------- |
| Sub-agent work where you can continue          | `delegate` — always                 |
| Parallel phases (e.g., spec + design)          | `delegate` × N — launch all at once |
| You MUST have the result before your next step | `task` — only exception             |
| User is waiting and there's nothing else to do | `task` — acceptable                 |

The default is `delegate`. You need a REASON to use `task`.

### Anti-Patterns (NEVER do these)

- **DO NOT** read source code files to "understand" the codebase — delegate.
- **DO NOT** write or edit code — delegate.
- **DO NOT** write specs, proposals, designs, or task breakdowns — delegate.
- **DO NOT** do "quick" analysis inline "to save time" — it bloats context.

### Task Escalation

| Size                | Action                                                       |
| ------------------- | ------------------------------------------------------------ |
| Simple question     | Answer if known, else delegate (async)                       |
| Small task          | delegate to sub-agent (async)                                |
| Substantial feature | Suggest SDD: `/sdd-new {name}`, then delegate phases (async) |

---

## SDD Workflow (Spec-Driven Development)

SDD is the structured planning layer for substantial changes.

### Artifact Store Policy

| Mode       | Behavior                                                                 |
| ---------- | ------------------------------------------------------------------------ |
| `engram`   | Default when available. Persistent memory across sessions.               |
| `openspec` | File-based artifacts. Use only when user explicitly requests.            |
| `hybrid`   | Both backends. Cross-session recovery + local files. More tokens per op. |
| `none`     | Return results inline only. Recommend enabling engram or openspec.       |

### Commands

- `/sdd-init` -> run `sdd-init`
- `/sdd-explore <topic>` -> run `sdd-explore`
- `/sdd-new <change>` -> run `sdd-explore` then `sdd-propose`
- `/sdd-continue [change]` -> create next missing artifact in dependency chain
- `/sdd-ff [change]` -> run `sdd-propose` -> `sdd-spec` -> `sdd-design` -> `sdd-tasks`
- `/sdd-apply [change]` -> run `sdd-apply` in batches
- `/sdd-verify [change]` -> run `sdd-verify`
- `/sdd-archive [change]` -> run `sdd-archive`
- `/sdd-new`, `/sdd-continue`, and `/sdd-ff` are meta-commands handled by YOU (the orchestrator). Do NOT invoke them as skills.

### Dependency Graph

```
proposal -> specs --> tasks -> apply -> verify -> archive
             ^
             |
           design
```

### Result Contract

Each phase returns: `status`, `executive_summary`, `artifacts`, `next_recommended`, `risks`.

### Sub-Agent Launch Pattern

ALL sub-agent launch prompts MUST include pre-resolved skill references:

```
  SKILL: Load `{skill-path}` before starting.
```

The ORCHESTRATOR resolves skill paths from the registry ONCE (at session start or first delegation), then passes the exact path to each sub-agent. Sub-agents do NOT search for the skill registry themselves.

**Orchestrator skill resolution (do once per session):**

1. `mem_search(query: "skill-registry", project: "{project}")` → get registry
2. Cache the skill-name → path mapping for the session
3. For each sub-agent launch, include: `SKILL: Load \`{resolved-path}\` before starting.`
4. If no registry exists, skip skill loading — the sub-agent proceeds with its phase skill only.

### Sub-Agent Context Protocol

Sub-agents get a fresh context with NO memory. The orchestrator controls context access.

#### Non-SDD Tasks (general delegation)

- **Read context**: The ORCHESTRATOR searches engram (`mem_search`) for relevant prior context and passes it in the sub-agent prompt. The sub-agent does NOT search engram itself.
- **Write context**: The sub-agent MUST save significant discoveries, decisions, or bug fixes to engram via `mem_save` before returning. It has the full detail — if it waits for the orchestrator, nuance is lost.
- **When to include engram write instructions**: Always. Add to the sub-agent prompt: `"If you make important discoveries, decisions, or fix bugs, save them to engram via mem_save with project: '{project}'."`
- **Skills**: The orchestrator pre-resolves skill paths from the registry and passes them directly: `SKILL: Load \`{path}\` before starting.` Sub-agents do NOT search for the registry themselves.

#### SDD Phases

Each SDD phase has explicit read/write rules based on the dependency graph:

| Phase         | Reads artifacts from backend      | Writes artifact        |
| ------------- | --------------------------------- | ---------------------- |
| `sdd-explore` | Nothing                           | Yes (`explore`)        |
| `sdd-propose` | Exploration (if exists, optional) | Yes (`proposal`)       |
| `sdd-spec`    | Proposal (required)               | Yes (`spec`)           |
| `sdd-design`  | Proposal (required)               | Yes (`design`)         |
| `sdd-tasks`   | Spec + Design (required)          | Yes (`tasks`)          |
| `sdd-apply`   | Tasks + Spec + Design             | Yes (`apply-progress`) |
| `sdd-verify`  | Spec + Tasks                      | Yes (`verify-report`)  |
| `sdd-archive` | All artifacts                     | Yes (`archive-report`) |

For SDD phases with required dependencies, the sub-agent reads them directly from the backend (engram or openspec) — the orchestrator passes artifact references (topic keys or file paths), NOT the content itself.

#### Engram Topic Key Format

| Artifact        | Topic Key                          |
| --------------- | ---------------------------------- |
| Project context | `sdd-init/{project}`               |
| Exploration     | `sdd/{change-name}/explore`        |
| Proposal        | `sdd/{change-name}/proposal`       |
| Spec            | `sdd/{change-name}/spec`           |
| Design          | `sdd/{change-name}/design`         |
| Tasks           | `sdd/{change-name}/tasks`          |
| Apply progress  | `sdd/{change-name}/apply-progress` |
| Verify report   | `sdd/{change-name}/verify-report`  |
| Archive report  | `sdd/{change-name}/archive-report` |
| DAG state       | `sdd/{change-name}/state`          |

Sub-agents retrieve full content via two steps:

1. `mem_search(query: "{topic_key}", project: "{project}")` → get observation ID
2. `mem_get_observation(id: {id})` → full content (REQUIRED — search results are truncated)

### State and Conventions

Convention files under `~/.claude/skills/_shared/` (global) or `.agent/skills/_shared/` (workspace): `engram-convention.md`, `persistence-contract.md`, `openspec-convention.md`.

### Recovery Rule

| Mode       | Recovery                                       |
| ---------- | ---------------------------------------------- |
| `engram`   | `mem_search(...)` → `mem_get_observation(...)` |
| `openspec` | read `openspec/changes/*/state.yaml`           |
| `none`     | State not persisted — explain to user          |

---

## Cross-Platform Parity Rule (MANDATORY)

This is a multi-platform project: **Android (phone)**, **Wear OS (watch)**, **iOS (phone)**, and **watchOS (Apple Watch)**.

Whenever a bug is fixed or a new feature is implemented on ANY platform, you MUST check and apply the equivalent fix/feature on ALL other platforms before considering the task complete.

| Changed platform     | Must also review and fix          |
| -------------------- | --------------------------------- |
| Android phone        | iOS phone, Wear OS, watchOS       |
| iOS phone            | Android phone, Wear OS, watchOS   |
| Wear OS              | watchOS, Android phone, iOS phone |
| watchOS              | Wear OS, Android phone, iOS phone |
| Android + Wear OS    | iOS + watchOS                     |
| iOS + watchOS        | Android + Wear OS                 |

**This is not optional.** The goal is to keep all platforms functionally identical and free of the same bugs. Always proactively ask or check the counterpart platforms — do not wait for the user to request it.

---

## PRD Maintenance Rule (MANDATORY)

The unified PRD lives in `PRD/` with 10 documents:

| # | Archivo | Contenido |
|---|---------|-----------|
| 01 | `PRODUCT_VISION.md` | Visión, objetivos, usuarios, modos de enfoque |
| 02 | `FEATURES.md` | Features completas con tabla de paridad cross-platform |
| 03 | `COMPETITIVE_ANALYSIS.md` | Análisis competitivo global + por plataforma |
| 04 | `MONETIZATION.md` | Precios, tiers FREE/PRO, feature gating |
| 05 | `TECHNICAL_ARCHITECTURE_IOS.md` | Arquitectura iOS/watchOS específica |
| 06 | `TECHNICAL_ARCHITECTURE_ANDROID.md` | Arquitectura Android/Wear OS específica |
| 07 | `ROADMAP.md` | Timeline y estimaciones ambas plataformas |
| 08 | `COLLABORATION_GUIDE.md` | Guía de trabajo con Claude Code |
| 09 | `CURRENT_STATUS.md` | Estado actual de implementación + brechas |
| 10 | `FLUTTER_MIGRATION_REFERENCE.md` | Referencia de migración desde Flutter |

**After completing any feature, bug fix, or significant modification**, you MUST check if the change affects any PRD document and update it accordingly:

| Type of change | PRD docs to update |
|----------------|-------------------|
| New feature implemented | `02_FEATURES.md` (parity table), `09_CURRENT_STATUS.md` |
| Bug fix | `09_CURRENT_STATUS.md` (if it was a known gap) |
| Architecture change | `05_...IOS.md` or `06_...ANDROID.md` |
| New dependency added | `05_...IOS.md` or `06_...ANDROID.md` |
| Pricing/tier change | `04_MONETIZATION.md` |
| New competitor discovered | `03_COMPETITIVE_ANALYSIS.md` |
| Roadmap milestone reached | `07_ROADMAP.md`, `09_CURRENT_STATUS.md` |
| New platform integration | `02_FEATURES.md`, `09_CURRENT_STATUS.md` |

**This is not optional.** Keeping PRD in sync with the codebase ensures future sessions have accurate context.

---

## Auto-Commit Rule (MANDATORY)

After completing any correction, change, improvement, or new feature, you MUST create a git commit immediately — do not wait for the user to ask.

### Commit Convention

- **Format**: Conventional Commits (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`, `style:`, `test:`)
- **Language**: English for commit messages
- **Scope**: Include platform scope when the change is platform-specific: `feat(android):`, `fix(ios):`, `feat(wear):`, `fix(watchos):`
- **Cross-platform**: When the same change applies to both platforms, use a single commit with no platform scope or list both: `feat(ios,android):`
- **Co-author**: Always include `Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>`

### When to Commit

| Situation | Action |
|-----------|--------|
| Feature implemented on one platform | Commit immediately |
| Same feature implemented on both platforms | One commit per platform, or one combined commit |
| Bug fix | Commit immediately after verifying the fix |
| Refactor / improvement | Commit immediately |
| PRD or documentation update | Commit immediately |
| Multiple small related changes | Group into one logical commit |

### What NOT to Commit

- Incomplete work (half-implemented features)
- Files with secrets (.env, credentials, API keys)
- Generated files that should be in .gitignore
- Temporary debug code

**This is not optional.** Frequent atomic commits create a clean history and reduce the risk of losing work.

---

Terms os use:
https://creapolis.dev/terms-of-use/
privacy policy:
https://creapolis.dev/privacy-policy/
