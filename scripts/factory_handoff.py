#!/usr/bin/env python3
"""Stateless Clean-Context Review Handoff Generator (Checkpoint C4).

Builds a deterministic, SHA-256-pinned review bundle for the independent
`reviewer` skill. Crucially, this script NEVER includes the implementer's chat
history or conversational rationale—preventing reviewer rationalization bias.

The bundle is self-sufficient: it embeds the full diff, the acceptance criteria,
the declared allowed edit surfaces, and the observed verification evidence, so
the reviewer does not need to reconstruct context. It fails closed
(`HANDOFF_BLOCKED`, exit 3) when the acceptance criteria or the verification
evidence are missing, instead of emitting placeholder text.

High-risk triggers are canonical in `CHECKPOINTS.md` (C4 — Judgment-Day Triggers).
"""

from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

REVIEW_BUDGET_LINES = 400
EXIT_BLOCKED = 3

# Path prefixes and exact files that always require blind dual review.
HIGH_RISK_PATH_PREFIXES = (
    "contracts/",
    "scripts/",
    ".github/workflows/",
    "docs/architecture/adr/",
)
HIGH_RISK_FILES = ("CHECKPOINTS.md",)
HIGH_RISK_BASENAMES = ("tauri.conf.json",)
HIGH_RISK_PATH_FRAGMENTS = ("src-tauri/capabilities/",)

# Whole-word tokens (split on path separators, punctuation, and camelCase).
# Substring matching is deliberately avoided: "lock" matched package-lock.json
# and "auth" matched AUTHORS.md, triggering costly false-positive dual reviews.
HIGH_RISK_TOKENS = frozenset(
    {
        "auth",
        "oauth",
        "authn",
        "authz",
        "authentication",
        "authorization",
        "rbac",
        "permission",
        "permissions",
        "security",
        "secret",
        "secrets",
        "crypto",
        "migration",
        "migrations",
    }
)
_TOKEN_RE = re.compile(r"[A-Z]+(?![a-z])|[A-Z]?[a-z]+|\d+")


def git_output(root: Path, *args: str) -> str:
    res = subprocess.run(
        ["git", *args],
        cwd=root,
        capture_output=True,
        text=True,
        check=True,
    )
    return res.stdout


def path_tokens(path: str) -> set[str]:
    return {token.lower() for token in _TOKEN_RE.findall(path)}


def detect_high_risk_triggers(changed_files: list[str]) -> list[str]:
    triggers: list[str] = []
    for path in changed_files:
        basename = path.rsplit("/", 1)[-1]
        if (
            path.startswith(HIGH_RISK_PATH_PREFIXES)
            or path in HIGH_RISK_FILES
            or basename in HIGH_RISK_BASENAMES
            or any(fragment in path for fragment in HIGH_RISK_PATH_FRAGMENTS)
        ):
            triggers.append(f"sensitive-surface:{path}")
        elif path_tokens(path) & HIGH_RISK_TOKENS:
            triggers.append(f"high-risk-keyword:{path}")
    return sorted(set(triggers))


def count_changed_lines(numstat: str) -> int:
    total = 0
    for line in numstat.splitlines():
        parts = line.split("\t")
        if len(parts) >= 2:
            for value in parts[:2]:
                if value.isdigit():  # binary files report "-"
                    total += int(value)
    return total


def fenced(content: str, lang: str = "") -> list[str]:
    """Wrap content in a code fence longer than any backtick run it contains."""
    longest = max((len(run) for run in re.findall(r"`+", content)), default=0)
    fence = "`" * max(3, longest + 1)
    return [f"{fence}{lang}", content, fence]


def extract_section(markdown: str, heading: str) -> str:
    """Return the body of `## <heading>` up to the next level-2 heading."""
    pattern = re.compile(rf"^##\s+{re.escape(heading)}\s*$", re.IGNORECASE | re.MULTILINE)
    match = pattern.search(markdown)
    if not match:
        return ""
    rest = markdown[match.end():]
    next_heading = re.search(r"^##\s", rest, re.MULTILINE)
    return rest[: next_heading.start()] if next_heading else rest


def parse_allowed_surfaces(markdown: str) -> list[str]:
    section = extract_section(markdown, "Allowed edit surfaces")
    surfaces: list[str] = []
    for line in section.splitlines():
        stripped = line.strip()
        if not stripped.startswith(("-", "*")):
            continue
        ticked = re.findall(r"`([^`]+)`", stripped)
        surfaces.extend(ticked if ticked else [stripped.lstrip("-* ").strip()])
    return [s for s in surfaces if s]


def is_within_surface(path: str, surface: str) -> bool:
    if surface.endswith("/"):
        return path.startswith(surface)
    if surface.endswith("/**"):
        return path.startswith(surface[:-2])
    return path == surface or fnmatch.fnmatchcase(path, surface)


def find_task_file(root: Path, issue: int) -> Path | None:
    matches = sorted((root / "odd" / "tasks").glob(f"{issue}-*.md"))
    return matches[0] if matches else None


def fetch_issue_body(root: Path, issue: int) -> str:
    try:
        res = subprocess.run(
            ["gh", "issue", "view", str(issue), "--json", "title,body", "-q", '"# " + .title + "\\n\\n" + .body'],
            cwd=root,
            capture_output=True,
            text=True,
            timeout=30,
        )
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return res.stdout.strip() if res.returncode == 0 else ""


def resolve_acceptance(args: argparse.Namespace, root: Path) -> tuple[str, str, str]:
    """Return (acceptance_text, source_label, surfaces_markdown)."""
    if args.issue_body_file:
        text = args.issue_body_file.read_text(encoding="utf-8")
        return text, f"file:{args.issue_body_file}", text
    if args.acceptance:
        return args.acceptance, "argument:--acceptance", args.acceptance
    task_file = find_task_file(root, args.issue)
    if task_file:
        text = task_file.read_text(encoding="utf-8")
        specs = extract_section(text, "Specs") or text
        return specs.strip(), f"task:{task_file.relative_to(root)}", text
    body = fetch_issue_body(root, args.issue)
    if body:
        return body, f"gh:issue#{args.issue}", body
    return "", "", ""


def resolve_verification(args: argparse.Namespace) -> str:
    if args.verification_file:
        return args.verification_file.read_text(encoding="utf-8").strip()
    return (args.verification_note or "").strip()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Build stateless clean-context reviewer handoff packet.")
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
        help="Repository root directory.",
    )
    parser.add_argument("--base", required=True, help="Base git ref or commit SHA.")
    parser.add_argument("--head", default="HEAD", help="Head git ref or commit SHA.")
    parser.add_argument("--issue", type=int, required=True, help="Authorized GitHub Issue number.")
    parser.add_argument(
        "--issue-body-file",
        type=Path,
        help="Issue body markdown (acceptance criteria, exclusions, allowed edit surfaces).",
    )
    parser.add_argument("--acceptance", help="Verbatim acceptance criteria text.")
    parser.add_argument("--verification-file", type=Path, help="File with captured V0/V1/V2 command output.")
    parser.add_argument("--verification-note", help="Observed V0/V1/V2 command output (inline).")
    parser.add_argument("--output-json", type=Path, help="Optional path to write JSON bundle.")
    parser.add_argument("--out", "--output-md", dest="output_md", type=Path, help="Path to write Markdown bundle.")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    root = args.root.resolve()

    acceptance, acceptance_source, surfaces_markdown = resolve_acceptance(args, root)
    verification = resolve_verification(args)
    blockers: list[str] = []
    if not acceptance:
        blockers.append(
            "no acceptance criteria source (use --issue-body-file, --acceptance, "
            f"odd/tasks/{args.issue}-<slug>.md, or an authenticated `gh`)"
        )
    if not verification:
        blockers.append("no verification evidence (use --verification-file or --verification-note)")
    if blockers:
        for blocker in blockers:
            print(f"HANDOFF_BLOCKED: {blocker}", file=sys.stderr)
        return EXIT_BLOCKED

    try:
        base_sha = git_output(root, "rev-parse", args.base).strip()
        head_sha = git_output(root, "rev-parse", args.head).strip()
        names_raw = git_output(root, "diff", "--name-only", f"{base_sha}...{head_sha}")
        diff_stat = git_output(root, "diff", "--stat", f"{base_sha}...{head_sha}").strip()
        numstat = git_output(root, "diff", "--numstat", f"{base_sha}...{head_sha}")
        diff_patch = git_output(root, "diff", f"{base_sha}...{head_sha}")
    except subprocess.CalledProcessError as exc:
        print(f"ERROR running git for handoff: {exc.stderr or exc}", file=sys.stderr)
        return 1

    changed_files = [line.strip() for line in names_raw.splitlines() if line.strip()]
    changed_lines = count_changed_lines(numstat)
    high_risk_triggers = detect_high_risk_triggers(changed_files)
    if changed_lines > REVIEW_BUDGET_LINES:
        high_risk_triggers.append(f"size-exception:{changed_lines} changed lines > {REVIEW_BUDGET_LINES}")
    judgment_day_required = len(high_risk_triggers) > 0

    allowed_surfaces = parse_allowed_surfaces(surfaces_markdown)
    out_of_scope = (
        [p for p in changed_files if not any(is_within_surface(p, s) for s in allowed_surfaces)]
        if allowed_surfaces
        else []
    )

    canonical_scope = json.dumps(
        {
            "issue": args.issue,
            "base_sha": base_sha,
            "head_sha": head_sha,
            "changed_files": changed_files,
            "diff_sha256": hashlib.sha256(diff_patch.encode("utf-8")).hexdigest(),
        },
        sort_keys=True,
    )
    scope_sha256 = hashlib.sha256(canonical_scope.encode("utf-8")).hexdigest()

    bundle = {
        "schema": "software-factory.clean-context-handoff.v2",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "context_isolation": "STATELESS_CLEAN_CONTEXT_NO_CHAT_HISTORY",
        "issue": args.issue,
        "base_sha": base_sha,
        "head_sha": head_sha,
        "scope_sha256": scope_sha256,
        "changed_files": changed_files,
        "changed_lines": changed_lines,
        "diff_stat": diff_stat,
        "acceptance_source": acceptance_source,
        "acceptance_criteria": acceptance,
        "allowed_edit_surfaces": allowed_surfaces,
        "out_of_scope_files": out_of_scope,
        "verification_evidence": verification,
        "high_risk_triggers": high_risk_triggers,
        "judgment_day_required": judgment_day_required,
        "diff": diff_patch,
    }

    if allowed_surfaces:
        surface_lines = [f"- `{s}`" for s in allowed_surfaces]
        scope_lines = [f"- ⚠️ `{p}`" for p in out_of_scope] or ["- None (all changed files are within declared surfaces)"]
    else:
        surface_lines = ["- Not declared (Inline Direct): verify scope against the Issue exclusions."]
        scope_lines = ["- Not computed (no declared surfaces)."]

    md_lines = [
        f"# Clean-Context Review Bundle — Issue #{args.issue}",
        "",
        "> **Context Isolation Notice**: This packet is generated deterministically from git state.",
        "> Do NOT read the implementer's conversation history. Evaluate strictly against the",
        "> Issue acceptance criteria, Hierarchy of Truth (`AGENTS.md`), and `CHECKPOINTS.md`.",
        "",
        "## Pinned Identity",
        f"- **Issue**: `#{args.issue}`",
        f"- **Base SHA**: `{base_sha}`",
        f"- **Head SHA**: `{head_sha}`",
        f"- **Scope Digest (SHA-256)**: `{scope_sha256}`",
        f"- **Changed Lines**: `{changed_lines}` (review budget: {REVIEW_BUDGET_LINES})",
        f"- **Blind Dual Review (`judgment-day`) Required**: `{judgment_day_required}`",
        "",
        "## High-Risk Triggers",
        *([f"- `{t}`" for t in high_risk_triggers] or ["- None detected by path (reviewer still judges semantic risk)"]),
        "",
        f"## Acceptance Criteria (source: `{acceptance_source}`)",
        acceptance,
        "",
        "## Allowed Edit Surfaces",
        *surface_lines,
        "",
        "## Files Outside Allowed Edit Surfaces",
        *scope_lines,
        "",
        "## Observed Verification Evidence (V0/V1/V2)",
        *fenced(verification, "text"),
        "",
        "## Changed Files",
        *[f"- `{p}`" for p in changed_files],
        "",
        "## Diff Stat",
        *fenced(diff_stat or "(no file changes)", "text"),
        "",
        "## Full Diff",
        *fenced(diff_patch.rstrip("\n") or "(empty diff)", "diff"),
    ]
    md_content = "\n".join(md_lines) + "\n"

    if args.output_json:
        args.output_json.parent.mkdir(parents=True, exist_ok=True)
        args.output_json.write_text(json.dumps(bundle, indent=2) + "\n", encoding="utf-8")

    if args.output_md:
        args.output_md.parent.mkdir(parents=True, exist_ok=True)
        args.output_md.write_text(md_content, encoding="utf-8")

    if not args.output_json and not args.output_md:
        print(md_content)
    else:
        print(
            f"HANDOFF_READY issue=#{args.issue} base={base_sha[:7]} head={head_sha[:7]} "
            f"scope_sha256={scope_sha256[:12]} judgment_day={judgment_day_required} "
            f"out_of_scope={len(out_of_scope)}"
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
