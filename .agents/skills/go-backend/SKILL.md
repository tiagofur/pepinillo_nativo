---
name: go-backend
description: "Go 1.23+ hexagonal/clean backend architecture, OpenAPI server stubs, PostgreSQL (pgx/v5 + sqlc + testcontainers-go) and SQLite (WAL) adapters, RFC 9457 Problem Details, and race-tested verification."
---

# Stack Context Skill: Go Backend & Database Adapter

Load this skill whenever reading, implementing, or reviewing files under `backend/**`, `cmd/**`, `internal/**`, `*.go`, `sqlc.yaml`, `migrations/**`, or `contracts/openapi.yaml`.

**Reference Docs**: [`docs/stack/go-backend.md`](../../../docs/stack/go-backend.md), [`ADR-0001`](../../../docs/architecture/adr/ADR-0001-go-backend-and-db-matrix.md), [`ADR-0003`](../../../docs/architecture/adr/ADR-0003-contract-first-openapi.md).

---

## 1. Hexagonal / Clean Architecture Layout

Enforce strict inward-pointing dependency arrows (`adapter` → `app` → `domain`):

```text
backend/
├── cmd/
│   └── api/main.go               # Composition root, config, graceful shutdown
├── internal/
│   ├── domain/                   # Pure business entities, value objects, domain errors, repository ports (zero external imports)
│   ├── app/                      # Use-case orchestration, transaction boundaries, input validation
│   └── adapter/
│       ├── http/                 # Generated OpenAPI server interface implementation, middleware, RFC 9457 mapper
│       ├── storage/
│       │   ├── postgres/         # pgx/v5 + sqlc generated queries (when factory.manifest.json database == "postgres")
│       │   └── sqlite/           # modernc.org/sqlite or mattn/go-sqlite3 with WAL mode (when database == "sqlite")
│       └── observability/        # log/slog structured JSON logger, OpenTelemetry trace/metric hooks
└── migrations/                   # Sequential SQL migrations (0001_init.up.sql / .down.sql)
```

- **Hard Rule**: `internal/domain` must never import `net/http`, `database/sql`, `github.com/jackc/pgx/v5`, or any transport/storage driver.

---

## 2. Contract-First HTTP & RFC 9457 Problem Details

1. **OpenAPI Server Stubs**:
   - Define routes, request bodies, and response schemas in `contracts/openapi.yaml` first.
   - Implement the generated strict server interface (`oapi-codegen` or `ogen`) inside `internal/adapter/http/`. Never register undocumented ad-hoc routes.
2. **RFC 9457 Error Contract (`application/problem+json`)**:
   - Map all domain errors to standardized Problem Details responses (`type`, `title`, `status`, `detail`, `instance`, `code`, and optional `errors[]` field-level validation array).
   - Never leak raw SQL driver errors, stack traces, or internal table names in HTTP responses.

---

## 3. Database Adapter Selection (`ADR-0001`)

Inspect `factory.manifest.json` (`database` field) and follow the active adapter contract:

| Engine | Driver & Codegen | Required Runtime & Testing Invariants |
| :--- | :--- | :--- |
| **PostgreSQL** (`postgres`) | `jackc/pgx/v5` + `sqlc` | Parameterized SQL only; explicit `context.Context` timeouts; integration tests run against real ephemeral Postgres via `testcontainers-go`. |
| **SQLite** (`sqlite`) | `modernc.org/sqlite` (CGO-free default) or `mattn/go-sqlite3` + `sqlc` | Enable `PRAGMA journal_mode=WAL;`, `PRAGMA busy_timeout=5000;`, and `PRAGMA foreign_keys=ON;` on connection init; separate writer pool (`MaxOpenConns(1)`) from reader pool. |
| **Custom** (`custom`) | Declared in project ADR | Must implement repository interfaces defined in `internal/domain/` with deterministic integration tests. |

---

## 4. Concurrency, Observability & Code Quality

- **Context Propagation**: Every I/O method accepts `ctx context.Context` as its first parameter and honors cancellation.
- **Structured Logging**: Use standard library `log/slog` with JSON output in production and correlation `request_id` attributes on every log entry.
- **Error Wrapping**: Wrap errors with `fmt.Errorf("context: %w", err)` and inspect domain sentinel/typed errors with `errors.Is` / `errors.As`.
- **Cognitive File Budget**: Keep `.go` files below ~500 lines (`docs/agent-first-methodology.md`).

---

## 5. Verification Commands (`V1` & `V2`)

```bash
# V1: Unit tests with race detector + static analysis
cd backend && go test -race -count=1 ./internal/domain/... ./internal/app/...
cd backend && go vet ./...

# V2: Full suite including storage adapters (testcontainers-go / SQLite) + contract check
make -C contracts lint diff
cd backend && go test -race -count=1 ./...
```
