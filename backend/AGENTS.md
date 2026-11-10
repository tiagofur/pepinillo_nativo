# backend/AGENTS.md — Backend Go

Mapa rápido para agentes que tocan `backend/**`. Contrato HTTP canónico:
[`../contracts/openapi.yaml`](../contracts/openapi.yaml). Arquitectura:
[`../docs/architecture.md`](../docs/architecture.md) §2 y
[`../docs/architecture/adr/ADR-0001-go-backend-and-db-matrix.md`](../docs/architecture/adr/ADR-0001-go-backend-and-db-matrix.md).

---

## Layout hexagonal

```text
backend/
├── cmd/api/main.go            # Composition root: config, migraciones, Sentry, Fiber, workers, shutdown
├── internal/
│   ├── config/                # config.go fail-closed (JWT_SECRET, REFRESH_TOKEN_HASH_KEY, CORS, APPLE_BUNDLE_ID)
│   ├── domain/                # Entidades puras + reglas (EffectiveTierAt, ResolveSyncTimestamp, FocusMode/Phase)
│   ├── ports/                 # Interfaces: repositories, auth_store, llm_provider, push_provider, websocket, file_storage
│   ├── services/              # Casos de uso: auth, oauth, task, subtask, focus, pomodoro, sync, ai, billing, revenuecat, push, analytics, preference, session_reconciler
│   ├── adapters/
│   │   ├── handlers/          # routes.go (orden crítico de registro) + handlers por dominio + error_handler + health
│   │   ├── middleware/        # jwt, email_verification, subscription, subscription_tier, require_backend_sync
│   │   ├── repositories/postgres/  # GORM + pgx/v5, queries parametrizadas
│   │   ├── stores/            # redis (refresh tokens HMAC) y memory (fallback dev)
│   │   ├── llm/               # gemini y noop (fallback)
│   │   ├── push/              # apns, fcm, mux, noop
│   │   ├── storage/           # minio y noop (avatares)
│   │   ├── notifier/          # sendgrid (email) y log
│   │   ├── websocket/         # hub, client, manager (eventos server→client)
│   │   └── behavior/          # logger de comportamiento
│   └── observability/         # slog JSON, Sentry, métricas, alert rules
├── migrations/                # 000001..000015 (par up/down; golang-migrate al boot)
├── ml_service/                # sidecar FastAPI opcional (perfil ml; :8001)
└── docker-compose.prod.yml    # api + db + redis + caddy (producción VPS)
```

## Reglas de oro

1. **Orden de rutas en Fiber v2**: webhooks sin JWT (`/webhooks/revenuecat`) y
   `/auth` público **antes** de `protected := api.Group("", middleware.JWT(...))`
   — el middleware de grupo con prefijo vacío aplica a rutas subsecuentes.
2. **Toda ruta nueva** se declara primero en `contracts/openapi.yaml` (`C2`) y
   pasa `make contracts-lint`.
3. **Toda migración nueva** añade par numerado `up`/`down` en `migrations/`;
   nunca editar una migración ya mergeada.
4. **Errores**: envolvente `ErrorEnvelope` (`{"error": ...}`); sync gates
   devuelven `402 ERR_TIER_INSUFFICIENT`; no filtrar SQL/stacks al cliente.
5. **`internal/domain`** nunca importa Fiber, GORM drivers ni Redis.
6. Sync LWW: timestamps con clamp (`ResolveSyncTimestamp`), `ended_at`
   monotónico, stats diarias recomputadas en UTC.

## Verificación

```bash
cd backend && go test ./...            # unitarios (CI: -race -count=1 con Postgres+Redis reales)
go vet ./...
python3 -m unittest discover -s tests -p "test_*.py"   # guardrails de factoría (raíz)
```

CI: `.github/workflows/test.yml` (PR), `.github/workflows/deploy.yml`
(test + deploy a VPS al push a `main` tocando `backend/**`).
