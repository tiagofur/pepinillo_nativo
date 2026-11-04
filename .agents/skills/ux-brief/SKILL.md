---
name: ux-brief
description: "Trigger: issues labeled `ux:shape`, or a request for the UX brief of a screen or flow. Unattended factory handoff that produces a UX brief and publishes it as an issue comment BEFORE implementation. Never writes product code."
metadata:
  version: "1.0"
---

## Activation Contract

Load this skill when an issue carries the `ux:shape` label and has no current brief, or when asked for the UX brief of a screen/flow. It is a cognitive step performed by the `explorer` role (not a separate agent). The design method itself is project/user-level (for example a design skill); this skill defines the factory handoff contract around it.

## Hard Rules

- Unattended: never ask the user questions. Every assumption is written as an explicit assumption.
- Zero code: no implementation, no mockup files. The single deliverable is one issue comment.
- Publish with `gh issue comment N --body-file <file>`; a brief that lives only in chat does not exist.
- Respect the project's design docs when present (`docs/design/*`, `docs/stack/*`) and the Hierarchy of Truth in `AGENTS.md`.
- If the issue contradicts an ADR, a domain invariant (`AGENTS.md` §5), or the design docs: do NOT design. Comment the contradiction and set `status:blocked` + `needs-human`.

## Decision Gates

| Condition | Action |
| :--- | :--- |
| A current surface brief already exists | Extend it; the addition inherits its visual world |
| New surface inside an established visual world | Full shape; the world is inherited and fixed |
| No visual world exists yet (new product or identity) | Deliver the brief with assumptions and flag that an attended design session is required |
| Missing context for a material decision | Marked assumption, never silent invention |

## Execution Steps

1. Read the issue and its comments, the relevant product docs, the design docs, any existing brief, and the current screen code.
2. Produce a minimal brief: visitor mode/goal, composition thesis, states (empty/loading/error/offline), key interactions, accessibility notes, and the memorable moment.
3. Publish it as an issue comment with heading `## UX Brief` and a final `### Assumptions` list.
4. Return to the orchestrator: comment URL, a 3-line summary, the assumption list, and whether an attended design session is required.

## Downstream Contract

- `implementer` honors the brief and attaches **Visual Evidence** in the PR (`## Visual Evidence`): screenshots per device class, naming which file proves what and linking the brief.
- `reviewer` checks fidelity to the brief and the presence of visual evidence; missing evidence on a `ux:shape` PR is a P1.
