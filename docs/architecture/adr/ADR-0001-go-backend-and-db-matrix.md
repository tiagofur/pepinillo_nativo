# ADR-0001: Go Backend Standard and Workload-Driven Database Selection Matrix

- **Status**: Accepted
- **Date**: 2026-10-29
- **Deciders**: Software Factory Architecture Core

---

## 1. Context

A multi-product Agentic Software Factory requires a backend language and persistence architecture that optimize simultaneously for:
1. **LLM Generation Accuracy**: Explicit control flow, minimal hidden magic, fast compiler diagnostics, and deterministic static typing.
2. **Operational Simplicity**: Single static binary deployment, low memory footprint, predictable concurrency, and fast test execution.
3. **Domain Flexibility**: While the backend language should remain constant across products to maximize skill reuse, different products have radically different persistence profiles (multi-tenant SaaS vs. local-first desktop companion vs. edge CLI vs. high-ingest telemetry).

---

## 2. Decision

### 2.1 Backend Language & Architecture: Go (Golang)
All backend services, APIs, and background workers in the Software Factory standardize on **Go** (1.23+):
- **Architecture**: Screaming Hexagonal / Clean Architecture (`domain -> application -> adapters`). Domain packages contain zero database or HTTP transport imports.
- **HTTP Transport**: Standard library `net/http` (Go 1.22+ enhanced routing) or lightweight `go-chi/chi/v5` middleware composition, bound to OpenAPI 3.1 generated types (`contracts/openapi.yaml`).
- **Database Access**: **SQL-first via `sqlc`** (compile-time type-safe Go generated from raw SQL) or explicit repository interfaces. Heavy reflection ORMs (`GORM`, `ent`) are prohibited by default because they obscure query plans and produce subtle runtime bugs in agent-generated code.
- **Error Contract**: All HTTP error responses serialize as **RFC 9457 Problem Details (`application/problem+json`)**.
- **Observability**: Structured JSON logging via standard library `log/slog` and OpenTelemetry (`otel`) tracing hooks.

### 2.2 Workload-Driven Database Selection Matrix
Unlike the backend language, the database engine is **not** one-size-fits-all. At project initialization (`./scripts/init-project.sh --db <choice>`), the primary store is chosen from the matrix below and recorded in `factory.manifest.json`. Because persistence is isolated behind domain repository ports, business logic remains identical regardless of the selected adapter.

| Workload Archetype | Primary Database | Driver / Tooling | Mandatory Operational Profile |
| :--- | :--- | :--- | :--- |
| **Multi-User SaaS, Transactional Core, Multi-Tenant APIs, Financial/Inventory Ledgers** | **PostgreSQL 16+** (`--db postgres`) | `pgx/v5` + `sqlc` + `golang-migrate` + `testcontainers-go` | ACID transactions, strict foreign keys, `JSONB` for bounded semi-structured attributes, Transactional Outbox pattern for async events, `pgvector` when semantic search is needed. |
| **Local-First App, Single-Node Micro-SaaS, Embedded CLI/Desktop Sidecar, Low-Ops Edge** | **SQLite 3** (`--db sqlite`) | `modernc.org/sqlite` (CGO-free) + `sqlc` | Mandatory pragmas on connection init: `PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL; PRAGMA foreign_keys=ON; PRAGMA busy_timeout=5000;`. Separate writer connection (`SetMaxOpenConns(1)`) from concurrent reader pool; pair with Litestream for continuous S3 replica backup when hosted. |
| **High-Ingest Telemetry, Audit Streams, Time-Series Analytics** | **ClickHouse** or **TimescaleDB** (`--db custom`) | Official native client behind append-only port | Requires an explicit project ADR addendum justifying ingest volume (>10k events/sec) over standard PostgreSQL partitioning. |
| **Ephemeral Cache, Rate Limiting, Distributed Locks, Pub/Sub** | **Redis / Valkey** or **NATS JetStream** (Auxiliary) | `redis/go-redis/v9` or `nats.go` | Auxiliary only—never the sole system of record without a durable primary database. |

---

## 3. Consequences

### Positive
- Go's explicit `if err != nil` handling, small grammar, and sub-second incremental compilation give coding agents immediate, unambiguous feedback (`V1` RED/GREEN cycles run in milliseconds).
- Repository ports allow starting an MVP on zero-ops SQLite (`--db sqlite`) or full PostgreSQL (`--db postgres`) without changing domain or application services.
- `sqlc` guarantees that every SQL query is syntax-checked against the migration schema before any code is reviewed.

### Negative / Tradeoffs
- Switching between PostgreSQL and SQLite requires maintaining dialect-specific SQL query files (`queries/postgres/*.sql` vs. `queries/sqlite/*.sql`) if a project actively supports both simultaneously; in practice, each project selects one primary engine in `factory.manifest.json`.
