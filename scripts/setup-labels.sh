#!/usr/bin/env bash
# Idempotent GitHub labels setup for the Agentic Software Factory.
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: GitHub CLI (gh) is required to configure labels." >&2
  exit 1
fi

create_label() {
  local name="$1"
  local color="$2"
  local desc="$3"
  gh label create "$name" --color "$color" --description "$desc" --force
}

echo "Configuring Software Factory labels..."

# Lifecycle status
create_label "status:new"         "FBCA04" "Newly created issue awaiting Explorer triage (DoR)"
create_label "status:ready"       "0E8A16" "Verified DoR and approved for Implementer pickup"
create_label "status:approved"    "0E8A16" "Explicitly approved for ODD implementation"
create_label "status:in-progress" "1D76DB" "Actively claimed by a bounded Implementer"
create_label "status:blocked"     "D93F0B" "Blocked on external constraint or human decision"

# Work classification
create_label "type:feat"          "A2EEEF" "New product capability or user-facing feature"
create_label "type:fix"           "D73A4A" "Bug fix or regression remediation"
create_label "type:chore"         "FEF2C0" "Tooling, CI, or structural maintenance"
create_label "type:docs"          "0075CA" "Documentation or ADR update"
create_label "type:refactor"      "C2E0C6" "Internal refactoring with invariant behavior"

# Priority & Sizing
create_label "priority:p0"        "B60205" "Critical blocker / production urgency"
create_label "priority:p1"        "D93F0B" "High priority for current milestone"
create_label "priority:p2"        "FBCA04" "Standard backlog priority"

create_label "size:xs"            "C2E0C6" "< 50 changed lines (Inline Direct)"
create_label "size:s"             "BFDADC" "50-150 changed lines (Inline Direct)"
create_label "size:m"             "F9D0C4" "150-400 changed lines (Delegated Direct)"
create_label "size:l"             "E99695" "> 400 lines — requires chained-pr slicing"

# Governance & Escalation triggers
create_label "ux:shape"           "5319E7" "Requires UX flow brief and visual verification evidence"
create_label "contract-break"     "B60205" "Human-authorized breaking OpenAPI change"
create_label "needs-human"        "D93F0B" "Requires human decision (credentials, cost, legal, ADR)"
create_label "judgment-day"       "000000" "Requires blind dual review by two independent judges"

echo "Labels synchronized."
