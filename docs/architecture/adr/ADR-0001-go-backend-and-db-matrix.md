# ADR-0001: Backend Go (Fiber v2 + GORM) y Matriz de Persistencia

- **Estado**: Accepted (reconciliado con la arquitectura en producción)
- **Fecha**: 2026-11-10 (original de plantilla: 2026-10-29)
- **Decisores**: Pepinillo Architecture Core

---

## 1. Contexto

El backend de Pepinillo da soporte a sincronización LWW multi-dispositivo (`Everywhere/AI+`), autenticación email/OAuth (Google y Sign in with Apple), verificación de recibos y webhooks de RevenueCat, notificaciones push (APNs/FCM), WebSockets en tiempo real y endpoints de analítica/IA. Necesitamos un ADR que refleje fielmente el stack que ya opera en producción y evite que los agentes inventen capas o frameworks inexistentes.

---

## 2. Decisión

### 2.1 Lenguaje y Arquitectura Hexagonal en `backend/`
- **Lenguaje**: **Go 1.24** (`backend/go.mod`), binario único `cmd/api/main.go`.
- **Capas hexagonales**:
  - `internal/domain/`: entidades puras y reglas de negocio (`User`, `EffectiveTierAt`, `Task`, `FocusMode`/`FocusPhase`, `ResolveSyncTimestamp`, `UserPreference`).
  - `internal/ports/`: interfaces hacia persistencia, almacenamiento de tokens, LLM, push, WebSocket y almacenamiento de archivos.
  - `internal/services/`: orquestación de casos de uso, rotación/detección de robo de refresh tokens, reconciliación LWW y lógica de créditos IA.
  - `internal/adapters/`: implementaciones concretas (`handlers/` HTTP Fiber v2, `middleware/`, `repositories/postgres/` con GORM, `stores/redis` y `stores/memory`, `llm/gemini` y `noop`, `push/{apns,fcm,mux,noop}`, `storage/{minio,noop}`, `notifier/sendgrid`, `websocket/`).
- **Transporte HTTP**: **Fiber v2** (`github.com/gofiber/fiber/v2`) montado bajo `/api/v1` con `recover`, `sentryfiber`, `helmet`, `compress`, `cors` estricto en producción y rate limiters globales + por identidad/IP en `/auth`.

### 2.2 Persistencia e Infraestructura
| Rol | Tecnología real | Detalles operativos |
| :--- | :--- | :--- |
| **Base principal** | **PostgreSQL 16** (`gorm.io/driver/postgres` + `pgx/v5`) | Migraciones secuenciales `000001`..`000015` ejecutadas al arranque con `golang-migrate/v4`. Todas las consultas parametrizadas vía GORM/SQL parametrizado. |
| **Estado efímero y refresh tokens** | **Redis 7** (`go-redis/v9`) con fallback `memory` en dev | Almacena hashes HMAC-SHA-256 (`REFRESH_TOKEN_HASH_KEY`) de refresh tokens y códigos temporales; en `APP_ENV=production` exige clave ≥ 32 bytes. |
| **Almacenamiento de objetos** | **MinIO** (`minio-go/v7`) con fallback `noop` | Avatares de perfil (`POST /api/v1/users/me/image`, máx. 5 MiB; JPEG/PNG/WebP). |
| **Sidecar ML opcional** | **Python FastAPI** (`backend/ml_service/main.py`, perfil `ml`) | Microservicio ligero en `:8001` (`Dockerfile.ml`); producción en VPS (`docker-compose.prod.yml`) despliega `api`, `db`, `redis` y `caddy` con fallback determinista si Gemini/ML no están activos. |
| **Observabilidad** | **`log/slog` JSON + Sentry + endpoints `/health*`** | `/health/metrics`, `/health/metrics/prometheus`, `/health/alerts`, `/health/slo`. |

### 2.3 Regla de orden de rutas en Fiber v2
En `backend/internal/adapters/handlers/routes.go`, los webhooks sin JWT (`POST /api/v1/webhooks/revenuecat`) y rutas públicas `/auth/*` **deben registrarse antes** de `protected := api.Group("", middleware.JWT(...))`, porque Fiber v2 aplica middleware de grupos con prefijo vacío `""` a las rutas subsecuentes del mismo `Router`.

---

## 3. Consecuencias

### Positivas
- Arquitectura probada en producción (`api.ppn.creapolis.dev`) con tests unitarios y de integración en CI contra PostgreSQL 16 y Redis 7 reales.
- Separación clara por puertos (`ports/`) que permite probar servicios en memoria (`fakes_test.go`) y sustituir proveedores externos (`Gemini`, `APNs`, `FCM`, `MinIO`, `SendGrid`).

### Restricciones / Deuda conocida
- No introducir nuevos endpoints ni tablas sin actualizar `contracts/openapi.yaml` y añadir migración numerada (`up` y `down`) en `backend/migrations/`.
- El perfil de producción (`APP_ENV=production`) es fail-closed si faltan `JWT_SECRET`, `REFRESH_TOKEN_HASH_KEY` (≥32 bytes), `CORS_ALLOWED_ORIGINS` sin `*` o `APPLE_BUNDLE_ID`.
