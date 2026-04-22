# Skill Registry

**Delegator use only.** Any agent that launches sub-agents reads this registry to resolve compact rules, then injects them directly into sub-agent prompts. Sub-agents do NOT read this registry or individual SKILL.md files.

Generated: 2026-04-21 | Project: pepinillo_nativo

---

## User Skills

| Trigger | Skill | Path |
|---------|-------|------|
| "judgment day", "judgment-day", "review adversarial", "dual review", "doble review", "juzgar", "que lo juzguen" | judgment-day | `/Users/tiagofur/.claude/skills/judgment-day/SKILL.md` |
| Writing Go tests, using teatest, or adding test coverage | go-testing | `/Users/tiagofur/.claude/skills/go-testing/SKILL.md` |
| Create a new skill, add agent instructions, document patterns for AI | skill-creator | `/Users/tiagofur/.claude/skills/skill-creator/SKILL.md` |
| Creating a pull request, opening a PR, preparing changes for review | branch-pr | `/Users/tiagofur/.claude/skills/branch-pr/SKILL.md` |
| Creating a GitHub issue, reporting a bug, or requesting a feature | issue-creation | `/Users/tiagofur/.claude/skills/issue-creation/SKILL.md` |
| Review, critique, evaluate, or give feedback on a design or component | critique | `/Users/tiagofur/dev/pepinillo_nativo/.agents/skills/critique/SKILL.md` |
| Build web components, pages, artifacts, posters, or applications | frontend-design | `/Users/tiagofur/dev/pepinillo_nativo/.agents/skills/frontend-design/SKILL.md` |
| One-time setup: gather design context for a new project | teach-impeccable | `/Users/tiagofur/dev/pepinillo_nativo/.agents/skills/teach-impeccable/SKILL.md` |

---

## Compact Rules

Pre-digested rules per skill. Delegators copy matching blocks into sub-agent prompts as `## Project Standards (auto-resolved)`.

### judgment-day
- Launch TWO independent judge sub-agents simultaneously (blind to each other) — never review yourself
- Each judge receives the same target + project standards (compact rules from registry)
- Judges MUST classify every WARNING as either "real" (confirmed impact) or "theoretical" (possible but unverified)
- After synthesis: delegate a Fix Agent only for confirmed CRITICALs and confirmed real WARNINGs
- Round 2+: only re-judge if confirmed CRITICALs remain; theoretical warnings → report as INFO, do NOT fix or re-judge
- APPROVED: 0 confirmed CRITICALs + 0 confirmed real WARNINGs (suggestions and theoretical warnings may remain)
- Never skip skill resolution (Pattern 0) — resolve compact rules before launching judges

### go-testing
- Use table-driven tests: struct slice with `name`, `input`, `expected`, `wantErr` fields, loop with `t.Run`
- Bubbletea: test model state transitions by calling `m.Update(msg)` directly, assert on model fields
- Teatest integration: `teatest.NewTestModel(t, m)`, send keys via `tm.Send()`, use `WaitFinished` with timeout
- Golden files: use `testdata/` directory, update with `-update` flag via `flag.Bool("update", false, "...")`
- Always use `t.Helper()` in assertion helpers; use `t.Parallel()` for independent unit tests

### skill-creator
- A skill must encode REUSABLE patterns (not one-off tasks): ask "would this be used 3+ times?"
- Required frontmatter: `name`, `description` (with Trigger line), `license`
- Critical Patterns section MUST contain only actionable rules — no motivation or when-to-use prose
- Skills are loaded by path — keep the SKILL.md self-contained and < 200 lines when possible
- Validate: pattern is reusable, critical patterns are clear, skill is < 200 lines

### branch-pr
- Every PR MUST link an approved issue (`status:approved` label) — no exceptions
- Branch naming: `type/description` — regex `^(feat|fix|chore|docs|style|refactor|perf|test|build|ci|revert)\/[a-z0-9._-]+$`
- PR body MUST contain: `Closes #N` (or `Fixes #N`/`Resolves #N`), description, test plan
- Every PR MUST have exactly one `type:*` label
- Run shellcheck on modified scripts before opening PR
- Do NOT open PR if the linked issue lacks `status:approved`

### issue-creation
- MUST use a template (bug report or feature request) — blank issues are disabled
- Bug reports require: reproduction steps, expected vs actual behavior, environment
- Feature requests require: problem statement, proposed solution, acceptance criteria
- A maintainer MUST add `status:approved` before any PR can be opened against the issue
- Label `priority:high` for critical bugs or urgent features

### critique
- MUST run `/frontend-design` first (it has design principles + Context Gathering Protocol)
- Run `/teach-impeccable` if no design context exists yet in instructions or `.impeccable.md`
- Check for AI slop first (most important): AI color palette, gradient text, glassmorphism, glowing accents, hero metric layouts, generic fonts
- Evaluate: visual hierarchy, information architecture, emotional resonance, cognitive load
- Score quantitatively; apply persona-based testing; provide actionable feedback

### frontend-design
- Gather design context BEFORE any design work: check instructions → `.impeccable.md` → run `/teach-impeccable`
- NEVER infer design context from the codebase — only the creator can provide brand/audience/tone
- Avoid AI slop aesthetics: no generic gradients, glassmorphism, glowing accents, hero metric card grids
- Implement real working code with exceptional attention to aesthetic detail
- Required context: target audience, use cases, brand personality/tone

### teach-impeccable
- One-time setup skill: runs once per project to gather and persist design context
- Explores codebase + asks user for target audience, use cases, brand personality/tone
- Saves context to `.impeccable.md` in project root for all future design sessions
- Run before any design work if `.impeccable.md` does not exist

---

## Project Conventions

| File | Path | Notes |
|------|------|-------|
| CLAUDE.md | `/Users/tiagofur/dev/pepinillo_nativo/CLAUDE.md` | Primary project conventions: commit rules, cross-platform parity, PRD maintenance, auto-commit |
| AGENTS.md | `/Users/tiagofur/dev/pepinillo_nativo/AGENTS.md` | Agent instructions: dev env tips, testing, PR instructions, repository map |

Read the convention files listed above for project-specific patterns and rules.
