.PHONY: help preflight test test-factory test-backend test-android contracts-lint contracts-diff handoff bootstrap labels

help: ## Show available Software Factory commands
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

preflight: ## Run read-only factory preflight check (C1)
	python3 scripts/factory_preflight.py

test: ## Run factory guardrail tests and active surface tests (C3)
	python3 -m unittest discover -s tests -p "test_*.py" -v
	@if [ -d backend ]; then (cd backend && go test ./...); fi

test-factory: ## Run factory guardrail tests only
	python3 -m unittest discover -s tests -p "test_*.py" -v

test-backend: ## Run backend unit tests
	cd backend && go test ./...

test-android: ## Run Android & Wear unit tests
	cd android && ./gradlew :app:testDebugUnitTest :wear:testDebugUnitTest

contracts-lint: ## Lint OpenAPI 3.1 contract with Spectral (C2)
	$(MAKE) -C contracts lint

contracts-diff: ## Check OpenAPI breaking changes against origin/main (C2)
	$(MAKE) -C contracts diff

handoff: ## Generate stateless clean-context review packet (C4)
	python3 scripts/factory_handoff.py \
		--base $${BASE_REF:-main} \
		--head $${HEAD_REF:-HEAD} \
		--issue $${ISSUE:-0} \
		$${VERIFICATION_FILE:+--verification-file "$$VERIFICATION_FILE"} \
		$${VERIFICATION_NOTE:+--verification-note "$$VERIFICATION_NOTE"} \
		$${ACCEPTANCE:+--acceptance "$$ACCEPTANCE"} \
		$${ISSUE_BODY_FILE:+--issue-body-file "$$ISSUE_BODY_FILE"} \
		$${OUT:+--out "$$OUT"}

bootstrap: ## Initialize project topology, DB choice, and active surfaces (Day 0)
	./scripts/init-project.sh

labels: ## Synchronize GitHub Issue/PR factory labels via gh CLI
	./scripts/setup-labels.sh
