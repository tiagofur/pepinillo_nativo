---
name: go-backend
description: "Backend Go 1.24 hexagonal con Fiber v2 + GORM sobre PostgreSQL 16 y Redis 7, Contract-First OpenAPI, middleware de tiers y sincronización LWW, con verificación race-tested."
---

# Skill de stack: Backend Go de Pepinillo

Carga este skill al leer, implementar o revisar archivos bajo `backend/**`,
`*.go`, `go.mod`, `backend/migrations/**` o `contracts/openapi.yaml`.

**Referencias**: [`backend/AGENTS.md`](../../../backend/AGENTS.md),
[`ADR-0001`](../../../docs/architecture/adr/ADR-0001-go-backend-and-db-matrix.md),
[`ADR-0003`](../../../docs/architecture/adr/ADR-0003-contract-first-openapi.md),
[`docs/architecture.md`](../../../docs/architecture.md).

---

## 1. Layout hexagonal y dirección de dependencias

```text
backend/
├── cmd/api/main.go               # Composition root: config, migraciones, Sentry, Fiber, workers, shutdown
├── internal/
│   ├── domain/                   # Entidades puras, reglas (EffectiveTierAt, ResolveSyncTimestamp), errores de dominio — cero imports de transporte/storage
│   ├── ports/                    # Interfaces: repositories, auth_store, llm_provider, push_provider, websocket, file_storage
│   ├── services/                 # Orquestación de casos de uso, límites de transacción, créditos IA, reconciliación LWW
│   └── adapters/
│       ├── handlers/             # Implementación HTTP Fiber v2 (routes.go + handlers por dominio + error_handler + health)
│       ├── middleware/           # jwt, email_verification, subscription, subscription_tier, require_backend_sync
│       ├── repositories/postgres/  # GORM + pgx/v5
│       ├── stores/               # redis (refresh tokens HMAC-hashed) y memory (fallback dev)
│       ├── llm/ push/ storage/ notifier/ websocket/ behavior/
├── migrations/                   # Secuenciales 000001..000015 (golang-migrate al boot)
└── ml_service/                   # Sidecar FastAPI opcional (perfil ml)
```

- **Regla dura**: `internal/domain` nunca importa `net/http` (Fiber),
  `gorm.io/*` drivers ni `redis`; los adapters implementan las interfaces de
  `internal/ports`.

## 2. HTTP Contract-First y envolventes de error

1. **Stub de servidor contra el contrato**:
   - Define rutas, payloads y códigos en `contracts/openapi.yaml` primero;
     implementa los handlers en `internal/adapters/handlers/` coincidiendo
     campo por campo con el contrato. Nunca registres rutas ad-hoc no
     documentadas.
   - **Orden de registro Fiber v2**: rutas sin JWT (`/webhooks/revenuecat`,
     `/auth/*` público, `/health*`) **antes** de
     `protected := api.Group("", middleware.JWT(...))`.
2. **Envolventes de error vigentes** (documentadas en el contrato):
   - Global `ErrorHandler`: `{"error": "<codigo_o_mensaje>"}`.
   - `RequireBackendSync`: `402` con
     `{"error":"subscription_required","code":"ERR_TIER_INSUFFICIENT","message":...,"upgrade_url":...}`.
   - Nunca filtrar errores crudos de SQL, stack traces ni nombres de tablas.
   - RFC 9457 `ProblemDetails` es el objetivo para endpoints nuevos
     (`ADR-0003`), nunca un cambio silencioso de rutas ya publicadas.

## 3. Modelo de tiers y sincronización LWW

- Tiers canónicos (`internal/domain/user.go`): `free`, `pepinillo_plus`
  (lifetime sticky), `everywhere_monthly`, `everywhere_annual`
  (`EffectiveTierAt`); strings legacy se normalizan a `free`.
- Compuertas: `RequireEmailVerified` (403 `email_not_verified`),
  `NewRequireBackendSync` (402 `ERR_TIER_INSUFFICIENT` en `/sync/*`,
  `/tasks/sync`, `PUT /preferences`), `NewRequireProFeatureMiddleware` (403
  `feature_not_available` en `/ai/*`, `/analytics/*`).
- LWW: `ResolveSyncTimestamp` (clamp de futuro, zero→now), upserts con
  `WHERE EXCLUDED.updated_at > ...`, `ended_at` monotónico, guard IDOR
  reescribiendo session IDs ajenos, stats diarias recomputadas en UTC, paginado
  cursor `updatedAt|id` (1..500).
- Créditos IA: 100/mes con deduct atómico + refund en fallo de LLM/JSON.

## 4. Concurrencia, observabilidad y calidad

- **Context propagation**: todo método de I/O acepta `ctx context.Context`
  primero y honra cancelación.
- **Logging estructurado**: `log/slog` JSON en producción con `request_id`;
  5xx también a Sentry (middleware Fiber).
- **Envoltura de errores**: `fmt.Errorf("contexto: %w", err)`; centinelas de
  dominio con `errors.Is` / `errors.As`.
- **Presupuesto de archivo**: `.go` bajo ~500 líneas
  (`docs/agent-first-methodology.md`).

---

## 5. Comandos de verificación (`V1` y `V2`)

```bash
# V1: unit tests con race detector + análisis estático
cd backend && go test -race -count=1 ./internal/domain/... ./internal/services/...
cd backend && go vet ./...

# V2: suite completa (integración contra Postgres/Redis reales en CI) + contratos
make contracts-lint
cd backend && go test -race -count=1 ./...
```
