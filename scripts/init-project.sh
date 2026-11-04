#!/usr/bin/env bash
# Day-0 Modular Project Topology Bootstrapper for Agentic Software Factory Base.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_NAME=""
DB_ENGINE="postgres"
SURFACES_RAW="backend,web"

usage() {
  cat <<EOF
Usage: ./scripts/init-project.sh [options]

Options:
  --root <dir>         Target repository root (default: repo root)
  --name <slug>        Project slug (e.g., acme-platform)
  --db <engine>        Primary database: postgres | sqlite | none | custom (default: postgres)
  --surfaces <list>    Comma-separated surfaces to activate:
                       backend,web,desktop-tauri,mobile-tauri,ios-native,android-native
  -h, --help           Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT_DIR="$2"
      shift 2
      ;;
    --name)
      PROJECT_NAME="$2"
      shift 2
      ;;
    --db)
      DB_ENGINE="$2"
      shift 2
      ;;
    --surfaces)
      SURFACES_RAW="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument '$1'" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$PROJECT_NAME" ]]; then
  if [[ -t 0 ]]; then
    read -r -p "Project slug (e.g., my-product): " PROJECT_NAME
    read -r -p "Database engine [postgres/sqlite/none/custom] (default: postgres): " input_db
    DB_ENGINE="${input_db:-postgres}"
    read -r -p "Active surfaces [backend,web,desktop-tauri,mobile-tauri,ios-native,android-native] (default: backend,web): " input_surfaces
    SURFACES_RAW="${input_surfaces:-backend,web}"
  else
    echo "ERROR: --name is required in non-interactive mode." >&2
    exit 1
  fi
fi

case "$DB_ENGINE" in
  postgres|sqlite|none|custom) ;;
  *)
    echo "ERROR: Invalid --db '$DB_ENGINE'. Allowed: postgres | sqlite | none | custom" >&2
    exit 1
    ;;
esac

IFS=',' read -r -a SURFACES <<< "$SURFACES_RAW"
VALID_SURFACES=()
for s in "${SURFACES[@]}"; do
  trimmed="$(echo "$s" | xargs)"
  [[ -z "$trimmed" ]] && continue
  case "$trimmed" in
    backend|web|desktop-tauri|mobile-tauri|ios-native|android-native)
      VALID_SURFACES+=("$trimmed")
      ;;
    *)
      echo "ERROR: Unknown surface '$trimmed'. Allowed: backend,web,desktop-tauri,mobile-tauri,ios-native,android-native" >&2
      exit 1
      ;;
  esac
done

if [[ ${#VALID_SURFACES[@]} -eq 0 ]]; then
  echo "ERROR: At least one surface must be enabled." >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/docs/architecture/adr"

# Write factory.manifest.json via Python for clean formatting
python3 - "$ROOT_DIR" "$PROJECT_NAME" "$DB_ENGINE" "${VALID_SURFACES[@]}" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
name = sys.argv[2]
db = sys.argv[3]
surfaces = sys.argv[4:]

manifest = {
    "schema_version": 1,
    "project_name": name,
    "database": db,
    "surfaces": surfaces,
    "bootstrapped_at": datetime.now(timezone.utc).isoformat(),
}
(root / "factory.manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
PY

# Write ADR-0000-project-topology.md
cat > "$ROOT_DIR/docs/architecture/adr/ADR-0000-project-topology.md" <<EOF
# ADR-0000: Project Topology & Surface Selection — ${PROJECT_NAME}

- **Status**: Accepted
- **Date**: $(date -u +"%Y-%m-%d")

## Context

This project was initialized from \`software-factory-base\`. To keep agent context lean and CI fast from Day 0, only explicitly selected architectural surfaces and database adapters are enabled.

## Decision

- **Project Slug**: \`${PROJECT_NAME}\`
- **Primary Database Engine**: \`${DB_ENGINE}\` (governed by ADR-0001)
- **Active Surfaces**: \`${VALID_SURFACES[*]}\` (governed by ADR-0002 & ADR-0003)

## Consequences

- Agents and CI workflows only build, lint, and verify the active surfaces listed in \`factory.manifest.json\`.
- Adding a new surface or changing the database engine requires updating \`factory.manifest.json\` and recording a superseding ADR.
EOF

scaffold_backend() {
  mkdir -p "$ROOT_DIR/backend/cmd/api" "$ROOT_DIR/backend/internal/domain" "$ROOT_DIR/backend/internal/app" "$ROOT_DIR/backend/internal/adapter"
  if [[ ! -f "$ROOT_DIR/backend/Makefile" ]]; then
    cat > "$ROOT_DIR/backend/Makefile" <<'EOF'
.PHONY: test lint build run

test:
	@if [ -f go.mod ]; then go test -race ./...; else echo "backend: go.mod not initialized yet"; fi

lint:
	@if [ -f go.mod ] && command -v golangci-lint >/dev/null 2>&1; then golangci-lint run; else echo "backend: lint skipped"; fi

build:
	@if [ -f go.mod ]; then go build ./cmd/...; else echo "backend: build skipped"; fi
EOF
  fi
}

scaffold_web() {
  mkdir -p "$ROOT_DIR/apps/web/src"
  if [[ ! -f "$ROOT_DIR/apps/web/Makefile" ]]; then
    cat > "$ROOT_DIR/apps/web/Makefile" <<'EOF'
.PHONY: test lint build

test:
	@if [ -f package.json ]; then npm test --if-present; else echo "apps/web: package.json not initialized yet"; fi

lint:
	@if [ -f package.json ]; then npm run lint --if-present; else echo "apps/web: lint skipped"; fi

build:
	@if [ -f package.json ]; then npm run build --if-present; else echo "apps/web: build skipped"; fi
EOF
  fi
}

scaffold_desktop_tauri() {
  mkdir -p "$ROOT_DIR/apps/desktop/src-tauri/capabilities"
  if [[ ! -f "$ROOT_DIR/apps/desktop/Makefile" ]]; then
    cat > "$ROOT_DIR/apps/desktop/Makefile" <<'EOF'
.PHONY: test lint build

test:
	@if [ -f src-tauri/Cargo.toml ]; then cargo test --manifest-path src-tauri/Cargo.toml; else echo "apps/desktop: Cargo.toml not initialized yet"; fi

lint:
	@if [ -f src-tauri/Cargo.toml ]; then cargo clippy --manifest-path src-tauri/Cargo.toml -- -D warnings; else echo "apps/desktop: clippy skipped"; fi
EOF
  fi
}

scaffold_mobile_tauri() {
  mkdir -p "$ROOT_DIR/apps/mobile-tauri/src-tauri/capabilities"
  if [[ ! -f "$ROOT_DIR/apps/mobile-tauri/Makefile" ]]; then
    cat > "$ROOT_DIR/apps/mobile-tauri/Makefile" <<'EOF'
.PHONY: test lint

test:
	@echo "apps/mobile-tauri: MVP Tauri mobile shell ready"
EOF
  fi
}

scaffold_ios_native() {
  mkdir -p "$ROOT_DIR/apps/ios"
  if [[ ! -f "$ROOT_DIR/apps/ios/Makefile" ]]; then
    cat > "$ROOT_DIR/apps/ios/Makefile" <<'EOF'
.PHONY: test lint

test:
	@echo "apps/ios: configure xcodebuild scheme in apps/ios/Makefile"
EOF
  fi
}

scaffold_android_native() {
  mkdir -p "$ROOT_DIR/apps/android"
  if [[ ! -f "$ROOT_DIR/apps/android/Makefile" ]]; then
    cat > "$ROOT_DIR/apps/android/Makefile" <<'EOF'
.PHONY: test lint

test:
	@if [ -f gradlew ]; then ./gradlew testDebugUnitTest; else echo "apps/android: gradlew not initialized yet"; fi
EOF
  fi
}

for surface in "${VALID_SURFACES[@]}"; do
  case "$surface" in
    backend)        scaffold_backend ;;
    web)            scaffold_web ;;
    desktop-tauri)  scaffold_desktop_tauri ;;
    mobile-tauri)   scaffold_mobile_tauri ;;
    ios-native)     scaffold_ios_native ;;
    android-native) scaffold_android_native ;;
  esac
done

echo "BOOTSTRAPPED project=${PROJECT_NAME} db=${DB_ENGINE} surfaces=${VALID_SURFACES[*]}"
