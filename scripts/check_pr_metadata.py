#!/usr/bin/env python3
"""Fail-closed PR Metadata & Delivery Contract Validator (Checkpoint C5).

Enforces the Software Factory PR body contract:
- Line 1: `Closes #N` | `Fixes #N` | `Resolves #N` (when `Delivery: complete`)
          OR `Refs #N` (when `Delivery: partial`)
- Line 2: `Delivery: complete` | `Delivery: partial`
- Required Markdown headings:
  - `## Summary`
  - `## Decisions Made Without Asking`
  - `## Verification Evidence`
  - `## Clean-Context Review Handoff`
  - `## Risk`
- Explicit risk line matching `Risk: none` or `Risk: item <1-6> (<reason>)`
  (items are the canonical high-risk list in `CHECKPOINTS.md` C3)
- Mechanical proof of the C4 clean-context review inside
  `## Clean-Context Review Handoff`: full 40-hex base/head SHAs, a 64-hex scope
  digest, and an `APPROVED` reviewer verdict. Template placeholders fail.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

ISSUE_NUMBER = r"#([1-9]\d*)"
LINE1_COMPLETE_RE = re.compile(rf"^(Closes|Fixes|Resolves)\s+{ISSUE_NUMBER}\s*$")
LINE1_PARTIAL_RE = re.compile(rf"^Refs\s+{ISSUE_NUMBER}\s*$")
LINE2_DELIVERY_RE = re.compile(r"^Delivery:\s+(complete|partial)\s*$")
RISK_LINE_RE = re.compile(r"^Risk:\s+(none|item\s+[1-6]\s+\(.+\))\s*$", re.MULTILINE)

REVIEW_SECTION = "## Clean-Context Review Handoff"
REVIEW_FIELDS = {
    "Base SHA": re.compile(r"Base SHA\**:\s*`?([0-9a-f]{40})`?\s*$", re.MULTILINE),
    "Head SHA": re.compile(r"Head SHA\**:\s*`?([0-9a-f]{40})`?\s*$", re.MULTILINE),
    "Scope Digest": re.compile(r"Scope Digest[^:\n]*:\s*`?([0-9a-f]{64})`?\s*$", re.MULTILINE),
    "Independent Reviewer Verdict": re.compile(
        r"Independent Reviewer Verdict\**:\s*`?APPROVED`?\s*$", re.MULTILINE
    ),
}

REQUIRED_SECTIONS = [
    "## Summary",
    "## Decisions Made Without Asking",
    "## Verification Evidence",
    "## Clean-Context Review Handoff",
    "## Risk",
]


def validate_pr_body(body: str) -> list[str]:
    errors: list[str] = []
    lines = [line.rstrip("\r") for line in body.strip().splitlines()]

    if len(lines) < 2:
        return ["PR body must contain at least two lines (Issue link on line 1, Delivery mode on line 2)."]

    line1 = lines[0].strip()
    line2 = lines[1].strip()

    m_delivery = LINE2_DELIVERY_RE.match(line2)
    if not m_delivery:
        errors.append(
            f"Line 2 must be exactly 'Delivery: complete' or 'Delivery: partial' (got: '{line2}')."
        )
    else:
        delivery_mode = m_delivery.group(1)
        if delivery_mode == "complete":
            if not LINE1_COMPLETE_RE.match(line1):
                errors.append(
                    f"Line 1 must match 'Closes #N', 'Fixes #N', or 'Resolves #N' when Delivery is complete (got: '{line1}')."
                )
        elif delivery_mode == "partial":
            if not LINE1_PARTIAL_RE.match(line1):
                errors.append(
                    f"Line 1 must match 'Refs #N' when Delivery is partial (got: '{line1}')."
                )

    for section in REQUIRED_SECTIONS:
        if section not in body:
            errors.append(f"Missing required section heading: '{section}'.")

    if not RISK_LINE_RE.search(body):
        errors.append(
            "Missing valid Risk declaration line ('Risk: none' or 'Risk: item <1-6> (<reason>)')."
        )

    errors.extend(validate_review_handoff(body))
    return errors


def validate_review_handoff(body: str) -> list[str]:
    start = body.find(REVIEW_SECTION)
    if start == -1:
        return []  # missing heading is already reported by REQUIRED_SECTIONS
    rest = body[start + len(REVIEW_SECTION):]
    next_heading = re.search(r"^##\s", rest, re.MULTILINE)
    section = rest[: next_heading.start()] if next_heading else rest
    return [
        f"'{REVIEW_SECTION}' must contain a real {field} "
        + ("(`APPROVED`)." if field.endswith("Verdict") else "(full lowercase hex, no placeholder).")
        for field, pattern in REVIEW_FIELDS.items()
        if not pattern.search(section)
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Software Factory PR metadata contract.")
    parser.add_argument("--body-file", type=Path, help="Path to file containing the PR body markdown.")
    parser.add_argument("--body", type=str, help="Raw PR body markdown string.")
    args = parser.parse_args()

    body = ""
    if args.body_file:
        body = args.body_file.read_text(encoding="utf-8")
    elif args.body is not None:
        body = args.body
    elif os.environ.get("PR_BODY"):
        body = os.environ["PR_BODY"]
    else:
        print("ERROR: Provide --body-file, --body, or set PR_BODY.", file=sys.stderr)
        return 2

    errors = validate_pr_body(body)
    if errors:
        print("PR_METADATA_INVALID:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    print("PR_METADATA_OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
