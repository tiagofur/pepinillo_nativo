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
2. App nativa → "Usar mi compra en la Web" (es) / "Use my purchase on the
   Web" (en) / "Usar minha compra na Web" (pt) — ETIQUETA CANÓNICA fijada
   en la revisión dual de PR-2 (judge B: agnóstica de tienda, cubre
   Pepinillo+ y Everywhere) → ingresa código →
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
  `odd/tasks/953-rc-web-bridge.md` (este artefacto),
  `backend/migrations/000019_*`, `backend/internal/domain/user.go`,
  `backend/internal/ports/repositories.go`, `backend/internal/ports/auth_store.go`,
  `backend/internal/adapters/repositories/postgres/user_repository.go`,
  `backend/internal/adapters/stores/{redis,memory}/auth_store.go`,
  `backend/internal/services/rc_link_service.go` (+ test),
  `backend/internal/services/errors.go` (sentinelas),
  `backend/internal/services/revenuecat_service.go` (lookup extensión),
  `backend/internal/services/{fakes,mocks}_test.go`,
  `backend/internal/adapters/handlers/rc_link_handler.go` (+ test),
  `backend/internal/adapters/handlers/routes.go`,
  `backend/internal/adapters/handlers/fakes_test.go`,
  `backend/cmd/api/main.go` (wiring),
  `backend/tests/integration/email_verification_flow_test.go` (stub de fake).
- **PR-2 (web)**: `web/src/lib/data/remote/apiClient.ts`, `web/src/lib/features/auth/AccountServer.svelte`,
  `web/src/lib/i18n/messages.ts`.

- **PR-3 (iOS/Mac)**: ajustes (Settings → cuenta) + llamada claim + `Purchases.logIn`.
- **PR-4 (Android)**: equivalente en Compose/Hilt.

## Log
- 2026-11-20: DoR registrado; unidad PR-1 iniciada (contract-first).
- 2026-11-20 (corrección C4.3 tras judgment-day dual ronda 1): limiter
  per-IP Max 10 en ambos endpoints (contrato 429); bind condicional al
  grant con pre-check 409 cross-account e idempotencia same-account
  (contrato 409; el comentario "harmless gift" de la ronda 1 era
  incompleto — un bind sin grant desviaba renovaciones y habilitaba
  downgrade diferido); SETNX + retry en códigos (colisión cross-account);
  bind transaccional que libera al holder previo; verify-antes-de-consume
  (outage RC ya no quema el código; fijado por test); tier de respuesta =
  efectivo post-gate; email enmascarado en la respuesta (contrato; para
  confirmación en pantalla nativa PR-3; platform wired a telemetría;
  sentinelas movidos a rc_link_service.go (precedente
  revenuecat_service.go) y errors.go revertido. Split mecánico de
  revenuecat_service.go diferido → issue #963.
- 2026-11-20 (C4.3 ronda 2, judge A P1): release eliminado de SetRcAppUserID —
  el UPDATE de release permitía a un claim concurrente "desvincular"
  silenciosamente el bind recién commiteado del ganador (sin duplicate-key,
  sin rollback, sin 409 → premium varado). Índice único parcial = race guard
  determinista: el perdedor recibe ports.ErrRcAppUserIDTaken → rollback del
  grant + 409. Además: rollback del grant ante CUALQUIER fallo de bind con
  log rc_link_rollback_failed; fake GetByID devuelve copias (semántica de
  producción; el aliasing enmascaraba el rollback en el test de carrera.
- 2026-11-20 (PR-2): tarjeta del código en /account (apiClient
  createRcLinkCode + account.linkCode.* ×3 locales, es voseo); genera,
  muestra con vencimiento y permite regenerar tras cada canje.
- 2026-11-20 (PR-2 dual APPROVED, jueces A+ B): P2 de judge B
  resuelto — etiqueta canónica del menú nativo fijada a "Usar mi compra
  en la Web" / "Use my purchase on the Web" / "Usar minha compra na Web"
  (PR-3/PR-4 la implementan literal). Follow-ups a issue #953: extracción
  mecánica de AccountServer (557 > 500), role="status" en la región del
  código, atenuar código vencido, pt "insira-o lá" más natural, en
  codeLabel "claim"→"link", clave muerta account.everywhereTeaser.
- 2026-11-20 (PR-3 iOS/Mac): RcLinkFeature + RcLinkView (patrón
  EmailVerification, TCA sheet) conTextField de 6 dígitos; APIClient.rcLink
  público; SubscriptionClient.currentAppUserID (actor manager expone
  Purchases.shared.appUserID); AppFeature.showRcLinkTapped + sheet en
  AppView; botón en guestHeader (iOS) y signedOut (Mac) con la etiqueta
  canónica; delegate claimSucceeded → linkSubscriptionIdentity existente
  (Purchases.logIn → SUBSCRIBER_ALIAS → soft-sync); errores 404/409 como
  casos APIClientError con userMessage; 8 claves xcstrings es/pt voseo;
  tests RcLinkFeatureTests (5, TestStore + Swift Testing).
