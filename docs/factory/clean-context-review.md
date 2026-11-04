# Stateless Clean-Context Review Protocol

Code review is the primary quality firewall of the Software Factory. In multi-agent systems, review fails when the reviewer shares the implementer's conversational memory. This document defines our **Stateless Clean-Context Review** architecture (`Checkpoint C4`).

---

## 1. Why Clean Context Is Mandatory ("Gaslighting by Rationale")

When an LLM implements a feature over 20–40 tool calls, its context window fills with:
- Intermediate debugging hypotheses that were partially right.
- Verbose explanations of why a shortcut or workaround was "necessary."
- Framing bias that focuses attention on the happy path the agent worked hardest to make pass.

If the same agent session performs self-review—or if its conversation transcript is forwarded to a reviewer subagent—the reviewer suffers from **rationale contamination**: it evaluates the *plausibility of the implementer's story* rather than the *objective correctness of the diff against the specification*.

### The Clean-Context Rule
> The `reviewer` agent MUST be instantiated in a fresh, isolated context window. It receives **zero** implementer chat messages, **zero** intermediate reasoning logs, and **zero** unpublished scratch notes.

---

## 2. Deterministic Review Handoff Packet (`scripts/factory_handoff.py`)

Instead of conversational context, the reviewer receives a single immutable markdown bundle produced by `scripts/factory_handoff.py`:

```bash
python3 scripts/factory_handoff.py \
  --base origin/main \
  --head HEAD \
  --issue 42 \
  --verification-file /tmp/verification-42.txt \
  --out /tmp/handoff-issue-42.md
```

The script **fails closed** (`HANDOFF_BLOCKED`, exit 3) when it cannot resolve acceptance criteria or verification evidence, instead of emitting placeholder text that a reviewer could mistake for proof.

### Contents of the Handoff Packet
1. **Pinned Cryptographic Identity**:
   - `base_sha` / `head_sha`: exact Git commit SHAs of the base and the candidate.
   - `scope_sha256`: SHA-256 over issue number, `base_sha`, `head_sha`, the sorted changed paths, and the SHA-256 of the full diff. Any subsequent commit invalidates the digest.
2. **Authority & Specification** (first source found wins): `--issue-body-file`, `--acceptance`, `odd/tasks/<issue>-<slug>.md` (`## Specs`), or `gh issue view`.
3. **Scope Control**: the declared `## Allowed edit surfaces` (parsed from the same source) and the list of changed files outside them, so out-of-scope mutations (P0) are visible without extra lookups.
4. **Objective Change Surface**: changed files, `git diff --stat`, total changed lines against the 400-line review budget, and the **full unified diff** embedded in the markdown bundle.
5. **Verification Evidence**: the captured `V0`/`V1`/`V2` command output from `--verification-file` (recommended) or `--verification-note`. Include the implementer's `## Decisions Made Without Asking` and `Risk:` lines in that file — they are declarations, not rationale.
6. **Path-Detected Risk**: `high_risk_triggers` and `judgment_day_required` (rules in [`CHECKPOINTS.md`](../../CHECKPOINTS.md) C4.4).

The reviewer may additionally read repository files at `head_sha`, ADRs, and `contracts/openapi.yaml` read-only.

---

## 3. Severity Rubric, Verdicts & Correction Bound

- **Severity rubric (`P0`–`P3`), evidence requirement, and verdicts**: canonical in [`reviewer/SKILL.md` §3](../../.agents/skills/reviewer/SKILL.md).
- **Single correction round**: canonical in [`CHECKPOINTS.md`](../../CHECKPOINTS.md) C4.3. It exists to prevent implementer↔reviewer ping-pong; after one failed round a human decides.

---

## 4. Blind Dual Review (`judgment-day`)

Standard single-reviewer review is sufficient for routine work units. High-risk diffs escalate to two independent read-only judges (`jd-judge-a`, `jd-judge-b`) inspecting the identical frozen packet without seeing each other's output. Triggers, and how judge agreement/contradiction is resolved, are canonical in [`CHECKPOINTS.md`](../../CHECKPOINTS.md) C4.4.

Path detection uses whole-word tokens, never substrings: an earlier substring matcher flagged `package-lock.json` ("lock") and `AUTHORS.md` ("auth"), paying for two judges on harmless diffs.
