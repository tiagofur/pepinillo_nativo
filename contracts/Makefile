# Contracts (OpenAPI 3.1) gate (Checkpoint C2, ADR-0003).
#
# FAIL-CLOSED: if a required tool cannot run, the target fails. A gate that
# silently skips is not a gate. Tools are pinned and installed on demand:
# Spectral via npx, oasdiff via `go install`.

SPEC := openapi.yaml
BASE ?= origin/main

SPECTRAL_VERSION := 6.17.0
OASDIFF_VERSION := v1.35.0

NPX ?= npx
GO ?= go
BIN := $(or $(shell $(GO) env GOBIN 2>/dev/null),$(shell $(GO) env GOPATH 2>/dev/null)/bin)
OASDIFF := $(BIN)/oasdiff

.PHONY: lint diff check generate

lint: ## Spectral lint with the repo ruleset (pinned version)
	$(NPX) --yes @stoplight/spectral-cli@$(SPECTRAL_VERSION) lint -r .spectral.yaml $(SPEC)

diff: $(OASDIFF) ## Breaking-change check of the spec against BASE (default origin/main)
	@if git cat-file -e "$(BASE):contracts/$(SPEC)" 2>/dev/null; then \
		base=$$(mktemp -t openapi-base-XXXXXX.yaml); \
		trap 'rm -f "$$base"' EXIT; \
		git show "$(BASE):contracts/$(SPEC)" > "$$base"; \
		$(OASDIFF) breaking --fail-on ERR "$$base" "$(SPEC)"; \
	else \
		echo "contracts: no base spec at $(BASE) - skipping breaking-change check (first contracts PR)."; \
	fi

check: lint diff ## lint + breaking-change check

$(OASDIFF):
	$(GO) install github.com/oasdiff/oasdiff@$(OASDIFF_VERSION)

generate: ## Typed DTOs/clients for active surfaces (hook placeholders; see ADR-0003)
	@echo "Contract code generation hook (ADR-0003):"
	@echo "  - Go backend:      oapi-codegen -> backend/internal/platform/contract/"
	@echo "  - Web / Tauri:     openapi-typescript -> apps/web/src/shared/api/schema.d.ts"
	@echo "  - iOS Native:      swift-openapi-generator -> apps/ios/Sources/Contract/"
	@echo "  - Android Native:  openapi-generator -> apps/android/app/src/main/kotlin/contract/"
