# Skill Registry — Pepinillo Agentic Software Factory

This registry maps **cognitive roles**, **stack/contract contexts**, and **global Gentle-AI / ODD skills** to their canonical file paths and activation rules.

---

## 1. Cognitive Role Skills (Project-Local, Task-Oriented)

We separate **cognitive task roles** from **technology stack knowledge**. Every execution unit loads exactly one primary cognitive role skill:

| Skill | Path | Trigger / Activation Rule |
| :--- | :--- | :--- |
| `leader` | `.agents/skills/leader/SKILL.md` | Orchestrating an issue end-to-end (`C1`–`C5`), choosing ODD `Inline Direct` vs `Delegated Direct`, dispatching bounded workers, generating stateless review bundles (`scripts/factory_handoff.py`), or preparing PR delivery (`scripts/check_pr_metadata.py`). |
| `explorer` | `.agents/skills/explorer/SKILL.md` | Read-only codebase/context mapping (`<2k` token handoff with `path:line` evidence) OR GitHub Issue Triage converting `status:new` issues into verifiable `status:ready` specifications with DoR and taxonomy labels. |
| `implementer` | `.agents/skills/implementer/SKILL.md` | Sole-writer implementation on an isolated branch within `## Allowed edit surfaces`, Contract-First OpenAPI workflow, RED → GREEN → Refactor test-first execution, proportional `V0`/`V1`/`V2` verification, and atomic work-unit commits. |
| `reviewer` | `.agents/skills/reviewer/SKILL.md` | Stateless Clean-Context Independent Review (`C4`) with **zero** access to implementer chat transcripts, evaluating only the deterministic `scripts/factory_handoff.py` bundle against the `P0`–`P3` rubric and `judgment-day` escalation rules. |
| `ux-brief` | `.agents/skills/ux-brief/SKILL.md` | Issue labeled `ux:shape` without a current brief: unattended UX brief published as an issue comment before implementation (performed by the `explorer` role; never writes code). |

---

## 2. Stack & Surface Context Skills (Project-Local, On-Demand)

Stack skills are loaded **on demand** by `explorer`, `implementer`, or `reviewer` when the task or touched file paths match the surface:

| Skill | Path | File / Path Triggers | Task Intent Triggers |
| :--- | :--- | :--- | :--- |
| `go-backend` | `.agents/skills/go-backend/SKILL.md` | `backend/**`, `cmd/**`, `internal/**`, `*.go`, `go.mod`, `contracts/openapi.yaml` | Go clean/hexagonal architecture, OpenAPI server stubs, RFC 9457 Problem Details, `slog`, `go test ./...`. |
| `ios-native` | `.agents/skills/ios-native/SKILL.md` | `ios/**`, `*.swift`, `*.xcodeproj`, `*.xcworkspace` | Swift 6, The Composable Architecture (TCA), SwiftUI, watchOS companion UI/sync, `xcodebuild test`. |
| `android-native` | `.agents/skills/android-native/SKILL.md` | `android/**`, `*.kt`, `*.gradle*` | Kotlin, Jetpack Compose, Coroutines/Flow, Wear OS companion UI/sync, `./gradlew :app:testDebugUnitTest :wear:testDebugUnitTest`. |
| `critique` | `.agents/skills/critique/SKILL.md` | UI/UX reviews | Evaluate design from a UX perspective, visual hierarchy, cognitive load, accessibility. |
| `frontend-design` | `.agents/skills/frontend-design/SKILL.md` | Web/UI components | Production-grade UI/frontend styling guidelines. |

---

## 3. Global Gentle-AI & ODD Workflow Skills

When installed in the operator's global `~/.agents/skills/` environment, these skills govern cross-cutting commit, PR slicing, and adversarial review workflows:

| Skill | Global Path | Trigger / Activation Rule |
| :--- | :--- | :--- |
| `work-unit-commits` | `~/.agents/skills/work-unit-commits/SKILL.md` | Planning or closing an ODD task with an atomic, self-contained Conventional Commit that pairs code, tests, and docs. |
| `chained-pr` | `~/.agents/skills/chained-pr/SKILL.md` | Forecast or running changed-line count exceeds **400 lines**, requiring Stacked PRs or Feature Branch Chain slicing. |
| `branch-pr` | `~/.agents/skills/branch-pr/SKILL.md` | Creating branches, opening pull requests, or validating PR body structure and labels against repository templates. |
| `judgment-day` | `~/.agents/skills/judgment-day/SKILL.md` | Blind parallel dual review (`jd-judge-a` + `jd-judge-b`) when a trigger from `CHECKPOINTS.md` C4.4 fires (the handoff bundle reports path triggers as `judgment_day_required`). |
| `go-testing` | `~/.agents/skills/go-testing/SKILL.md` | Writing table-driven Go unit tests, subtests, or race-detector suites. |
| `issue-creation` | `~/.agents/skills/issue-creation/SKILL.md` | Authoring or refining GitHub Issues with verifiable acceptance criteria (`S1..Sn`), exclusions, and taxonomy labels. |

---

## 4. Resolution Protocol

1. Before starting any task, identify your **Cognitive Role** (`leader`, `explorer`, `implementer`, or `reviewer`) and read its `SKILL.md`.
2. Inspect the target file paths (`## Allowed edit surfaces` or diff paths) and load all matching **Stack & Surface Context Skills**.
3. When delegating to a subagent, inject the resolved skill paths explicitly and require `skill_resolution: paths-injected` in the worker report.
