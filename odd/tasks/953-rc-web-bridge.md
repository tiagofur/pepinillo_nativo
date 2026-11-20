# odd/tasks/953-rc-web-bridge.md — Puente de licencia RC nativa → cuenta web

> Delegated Direct (multi-superficie, entre sesiones). Un solo escritor por
> unidad; PRs apilados en cadena sobre `main`.

## Decisión de producto (DoR, 2026-11-20)

- **Modelo híbrido**: la web sigue vendiendo por Stripe (canal desktop vivo,
  margen ~3% vs 15-30% de tiendas) y los compradores nativos heredan su plan
  vía puente RC (modelo Spotify, cumplidor con Apple). Default elegido por el
  agente (pregunta a Tiago sin respuesta en el diálogo); reversible hasta
  que aterricen las unidades nativas.
- **UX de vinculación**: código de 6 dígitos (15 min TTL, single-use). Web
  genera, app nativa lo ingresa. Sin emails.
- **Reuso RC (respuesta a Tiago: "crear solo lo necesario")**: cero productos
  o entitlements nuevos. Reusa `REVENUECAT_API_KEY` (sk), el webhook
  `/webhooks/revenuecat` (configurado por Tiago el 20-nov), `VerifyViaRevenueCat`
  (REST `/subscribers/{id}` acepta IDs anónimos), handler `SUBSCRIBER_ALIAS`
  (U-C) y `generateResetCode` (6 dígitos, sin sesgo de módulo).
- Entitlements RC reales (confirmados en código): `pepinillo_plus` (lifetime)
  y `everywhere_plus` (suscripción → monthly/annual por product ID).

## Arquitectura del puente

1. Web (con sesión) → `POST /api/v1/account/link-code` → código efímero.
2. App nativa → "Usar mi Pepinillo+ en la Web" → ingresa código →
   `POST /api/v1/rc/link {code, app_user_id}`.
3. Backend: consume código (GETDEL atómico) → `VerifyViaRevenueCat(rcAppUserID)`
   server-side → si tier ≠ free: `UpdateSubscription` (paridad exacta con el
   webhook, B3/B6) + `SetRcAppUserID` → responde `{user_id, tier, expires_at}`.
4. App: `Purchases.logIn(user_id)` → RC dispara `SUBSCRIBER_ALIAS` → el
   handler U-C existente transfiere la compra; webhooks futuros llegan con
   `app_user_id` = UUID del backend y matchean directo.
5. Belt-and-suspenders: `ProcessWebhookEvent` ahora también resuelve IDs no
   UUID vía `GetByRcAppUserID` (renovaciones pre-logIn).

## Allowed edit surfaces (por unidad)

- **PR-1 (backend+contracts, esta unidad)**: `contracts/openapi.yaml`,
  `backend/migrations/000019_*`, `backend/internal/domain/user.go`,
  `backend/internal/ports/user_repository.go`, `backend/internal/ports/auth_store.go`,
  `backend/internal/adapters/repositories/postgres/user_repository.go`,
  `backend/internal/adapters/stores/{redis,memory}/auth_store.go`,
  `backend/internal/services/rc_link_service.go` (+ tests),
  `backend/internal/services/revenuecat_service.go` (lookup extensión),
  `backend/internal/adapters/handlers/rc_link_handler.go` (+ tests),
  `backend/internal/adapters/handlers/routes.go`, `backend/internal/adapters/handlers/fakes_test.go`.
- **PR-2 (web)**: `web/src/lib/data/remote/apiClient.ts`, `web/src/lib/features/auth/AccountServer.svelte`,
  `web/src/lib/i18n/messages.ts`.
- **PR-3 (iOS/Mac)**: ajustes (Settings → cuenta) + llamada claim + `Purchases.logIn`.
- **PR-4 (Android)**: equivalente en Compose/Hilt.

## Log
- 2026-11-20: DoR registrado; unidad PR-1 iniciada (contract-first).
