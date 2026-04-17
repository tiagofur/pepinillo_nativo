---
tags:
  - prd
  - exploration
  - client-experience
  - portal-cliente
  - solennix
aliases:
  - Client Experience Ideas
  - Ideas Experiencia Cliente
date: 2026-04-16
updated: 2026-04-17
status: exploration
---

# 14 — Ideas de Experiencia del Cliente (Exploración)

> [!warning] Este documento es EXPLORACIÓN, no compromiso
> Las ideas aquí listadas NO están en el roadmap. Son propuestas abiertas para debate. Cuando una idea sea aprobada se mueve a [[13_POST_MVP_ROADMAP|Roadmap Post-MVP]] con estimación firme, tier y fecha.

> [!tip] Documentos relacionados
>
> - [[02_FEATURES|Catálogo de Features]] — Fila "Pilar 5" refiere a este doc
> - [[13_POST_MVP_ROADMAP|Roadmap Post-MVP (Etapa 2)]] — Pilar 3 ya cubre lo comprometido
> - [[11_CURRENT_STATUS|Estado Actual]] — Portal Cliente MVP entregado (Abr 2026)
> - [[04_MONETIZATION|Monetización]] — Tiers Gratis / Pro / Business

---

## 1. Contexto

### 1.1 Lo que ya existe (MVP — 2026-04-16)

> [!success] Portal Cliente MVP shipped
> Commits: `8dff4f3` (backend) · `06d69ff` (web) · `a3f425a` (polish). Ver también [[11_CURRENT_STATUS]].

- **Migration 041** `event_public_links` table con partial unique index (1 link activo por evento) + token `crypto/rand` 256 bits.
- **Endpoints autenticados:** `POST/GET/DELETE /api/events/{id}/public-link`.
- **Endpoint público sin auth:** `GET /api/public/events/{token}` con rate limit 10/min IP.
- **Response curada `PublicEventView`:** event basics, organizer branding, client name, payment summary (total/paid/remaining). Sin márgenes, sin notas internas.
- **410 Gone** para revoked/expired — el frontend distingue "URL mal copiada" (404) de "organizer deshabilitó" (410).
- **Auto-revoke** si el evento es borrado mientras el link está activo.
- **Web `/client/:token`** (`ClientPortalPage.tsx`): hero + countdown + details grid + payment progress bar `role="progressbar"` aria-accessible.
- **`ClientPortalUnavailable`** con copy diferente 404 vs 410.
- **Branding del organizer** aplicado en vivo (color + logo) con regex anti-CSS-injection.
- **`ClientPortalShareCard`** en EventSummary: Copy + WhatsApp (`wa.me/?text=...`) + Rotar + Deshabilitar.
- **`eventPublicLinkService`** wrappea los 3 endpoints autenticados.

> [!warning] Gaps conocidos del MVP
>
> - iOS/Android share card nativas — **pendiente Sprint 8** (organizador comparte desde desktop por ahora).
> - `OpenAPI docs` — los 4 endpoints aún no están en `backend/docs/openapi.yaml`.
> - Enforcement del límite "1 portal Gratis vs ∞ Pro/Business" — **pendiente Sprint 7.C**.
> - Field-level `visibleToClient` — hoy la respuesta es subset fijo; toggles pendientes (cluster B.1).
> - Timeline de milestones, equipo asignado, progress bar "72% listo", PIN opcional, mapa integrado — todos en backlog.

### 1.1.bis Garantía de acceso perpetuo del cliente (decisión 2026-04-16)

> [!important] El cliente debe poder volver años después
> Bodas, quinces, eventos importantes — la gente vuelve a revisitar detalles, contratos, fotos. Cortar ese acceso es una regresión emocional que no queremos.

Reglas ya implementadas por diseño en el MVP:

1. **Default de expiración: `NULL` (nunca caduca).** `event_public_links.expires_at` es nullable; los links se crean sin TTL por default.
2. **Post-evento NO se revoca automáticamente.** No hay cron job que "limpie" links viejos.
3. **Revocación explícita** sigue disponible pero con fricción — el botón "Deshabilitar" debe mostrar confirm reforzado cuando el evento es >180 días (pendiente de polish).
4. **ON DELETE CASCADE** si el organizador borra su cuenta. Feature futura Business: "Exportar portal como PDF permanente" (snapshot estático en `solennix.com/archive/{event-id}`).
5. **Cambio de URL del portal en el futuro** → mantener redirect legacy indefinidamente. NUNCA 404 a URLs guardadas por el cliente.

---

### 1.2 Lo que ya está planeado (Pilar 3 — [[13_POST_MVP_ROADMAP]])

- Notificaciones automáticas al cliente en momentos clave (cotización lista, contrato listo, pago recibido, checklist completo, en camino, llegamos, completado, recordatorio de pago).
- Endpoints de acciones del evento (`departed`, `arrived`, `setup-done`, `completed`) que registran timeline y disparan notificaciones.
- Firma digital del contrato desde el portal.
- Calificación post-evento (1–5 estrellas + comentario).
- WhatsApp deep-links para envío de cotización/contrato.

### 1.3 La brecha que este documento intenta cubrir

Todo lo anterior es **organizador → cliente (broadcast)**. No hay ninguna feature planeada para:

- Comunicación **bidireccional** (cliente responde, pregunta, aprueba).
- Decisiones estructuradas del cliente (más allá de firma del contrato).
- Transparencia **granular opt-in** (hoy el agregado está forzado).
- Momentos del evento **en vivo** (foto/video durante la ejecución).
- Co-planificación (RSVP, moodboard, reuniones).
- Pagos **desde el portal**.
- Telemetría **inversa** (qué vio el cliente y cuándo).
- **Multi-destinatario** (bodas = 2 novios + madre de la novia + wedding planner con distinto nivel de acceso).

---

## 2. Principios de diseño del cliente-lado

1. **Transparencia opt-in, nunca forzada.** El organizador decide qué comparte. Default conservador (agregado, sin montos).
2. **Un canal oficial, no reemplazo forzado de WhatsApp.** El portal es un lugar de verdad; WhatsApp sigue siendo el canal coloquial. Los puntos de decisión viven en el portal.
3. **Simetría de telemetría.** Si el cliente ve algo, el organizador ve que lo vio. Sin sombras.
4. **Mínima fricción para el cliente.** El cliente no es usuario registrado de Solennix. Todo funciona con link + token. La PWA instalable es un plus, no un requisito.
5. **Desktop y mobile del cliente con el mismo valor.** El cliente no va a descargar una app. El portal vive en web responsive.

---

## 3. Clusters de ideas

### Cluster A — Bidireccionalidad y aprobaciones

#### A.1 Inbox cliente ↔ organizador in-portal

- **Problema:** hoy toda comunicación transaccional vive en WhatsApp. Se pierden contextos, hilos y trazabilidad.
- **User story (organizador):** "Quiero ver todos los mensajes de un evento en un solo lugar sin perderme entre chats de 15 bodas distintas."
- **User story (cliente):** "Quiero hacerle una pregunta sobre el menú sin tener que buscar el número del organizador."
- **Requisitos:**
  - Hilo de mensajes por evento; texto plano + archivo adjunto opcional.
  - Notificación push/email bidireccional.
  - Indicadores de leído.
- **Riesgos:** expectativa de respuesta en tiempo real; debe quedar claro que no es chat sincrónico.
- **Tier sugerido:** Pro.
- **Dependencias:** ninguna — se puede hacer standalone.

#### A.2 Aprobaciones estructuradas

- **Problema:** cambios clave del evento (menú, precio, agenda) se aprueban por audio de WhatsApp. No hay audit log.
- **User story (organizador):** "Propongo cambio de menú; el cliente aprueba con un botón; queda registrado con timestamp."
- **Requisitos:**
  - Tipos: `price_change`, `menu_change`, `option_choice` (A/B/C), `date_change`, `generic`.
  - Payload JSON flexible.
  - Estados: `pending`, `approved`, `rejected`, `expired`.
  - Audit log inmutable.
- **Riesgos:** valor legal — no sustituye firma digital (ver Pilar 3). Es registro de acuerdo operativo.
- **Tier sugerido:** Pro.
- **Dependencias:** inbox (A.1) opcional — la decisión puede disparar mensaje automático.

#### A.3 Comentarios por sección

- **Problema:** cliente quiere preguntar "¿por qué este costo en el line 3 de la cotización?" y hoy tiene que escribir prosa en WhatsApp.
- **Requisitos:**
  - Comentario anclado a un line item: `quote_item`, `contract_clause`, `timeline_step`, `checklist_item`.
  - Visible para ambos lados.
  - Marcar como resuelto.
- **Riesgos:** overhead de UI si hay 200 line items; usar disclosure progresiva.
- **Tier sugerido:** Pro.
- **Dependencias:** ninguna.

#### A.4 Polls rápidas

- **Problema:** "elegí entre estos 3 centros de mesa" termina en un chat de imágenes sin tracking.
- **Requisitos:**
  - Organizador crea encuesta con 2–6 opciones + imágenes.
  - Cliente vota 1 vez; resultado fija el line item del evento.
- **Tier sugerido:** Pro.
- **Dependencias:** A.2 (es una variante de approval).

---

### Cluster B — Transparencia granular opt-in

#### B.1 Toggle de visibilidad por sección

- **Problema:** algunos organizadores quieren mostrar desglose completo (transparencia), otros no (protegen margen).
- **Requisitos:**
  - Por sección (`payments`, `products`, `extras`, `equipment`, `supplies`), el organizador elige: `hidden`, `aggregate`, `itemized`.
  - Default: `aggregate` (igual al MVP).
  - El endpoint público filtra antes de serializar.
- **Riesgos:** fugas accidentales. El filtro es lo último antes de responder y tests deben cubrir cada modo.
- **Tier sugerido:** Gratis (mantener MVP simple) / Pro (itemizado).
- **Dependencias:** ninguna.

#### B.2 Stepper de milestones

- **Problema:** el badge único ("Confirmado") no transmite avance real del evento.
- **Requisitos:**
  - Milestones: `Cotización enviada → Contrato firmado → Seña recibida → Detalles confirmados → Día del evento → Completado`.
  - Progreso derivado de estado + flags existentes (no tabla nueva).
  - Visual consistente en las 4 plataformas (web organizador, portal cliente, iOS, Android).
- **Tier sugerido:** Gratis.
- **Dependencias:** ninguna.

#### B.3 Lista de tareas cliente-lado

- **Problema:** el cliente no sabe qué se espera de él y cuándo.
- **Requisitos:**
  - Flag `client_decision_required: bool` + `client_deadline` en `checklist_items` existentes.
  - Portal muestra sólo los items con el flag, sección "Tu turno".
  - Notificación T-3 días si hay tareas sin resolver.
- **Tier sugerido:** Pro.
- **Dependencias:** B.1 (toggle de visibilidad del checklist).

---

### Cluster C — Momentos en vivo (Event Day)

#### C.1 Stream de fotos/video del evento

- **Problema:** el cliente no está en la cocina viendo el montaje. Hoy se entera cuando llega.
- **User story:** "Mientras monto, subo 3 fotos y un video corto. El cliente los ve en el portal y sabe que todo marcha."
- **Requisitos:**
  - Media asociada al evento con caption, timestamp, tipo (`photo` / `video`).
  - Storage: decisión abierta — S3 / R2 / propio.
  - Upload desde app en background.
  - Visible en portal como timeline inverso.
- **Riesgos:** ancho de banda; calidad vs. tamaño; moderación (raro pero posible: foto accidental con contenido sensible).
- **Tier sugerido:** Pro.
- **Dependencias:** Event Day Mode (Pilar 4 del roadmap existente).

#### C.2 Ubicación en vivo

- **Problema:** "¿cuánto te falta?" en WhatsApp cada 5 min.
- **Requisitos:**
  - Opt-in del organizador por evento.
  - TTL estricto (ej: 4h post-salida o hasta `arrived`).
  - Tabla con expiry job.
- **Riesgos:** privacidad del organizador; debe ser explícito "compartiendo ahora".
- **Tier sugerido:** Pro.
- **Dependencias:** acción `departed` (ya en Pilar 3).

#### C.3 Check-ins cualitativos

- **Problema:** los estados `en camino` / `llegamos` son binarios. Falta "cocina lista, montaje 70%".
- **Requisitos:**
  - Entrada de texto libre + emoji opcional asociada al timeline.
  - Visibles en el feed del portal.
- **Tier sugerido:** Gratis.
- **Dependencias:** timeline del evento (Pilar 4).

---

### Cluster D — Co-planificación

#### D.1 RSVP / lista de invitados

- **Problema:** en bodas y quinces, la lista de invitados vive en Excel compartido. El organizador necesita headcount para cocina.
- **Requisitos:**
  - Cliente gestiona lista (nombre, email, teléfono, plus-one, dieta, notas).
  - Opcional: link público de confirmación por invitado.
  - Organizador ve headcount agregado + desgloses (veganos, alergias, niños).
- **Tier sugerido:** Pro (limitado a eventos tipo boda/quince).
- **Dependencias:** ninguna.

#### D.2 Moodboard / referencias

- **Problema:** cliente manda Pinterest, Instagram, screenshots por WhatsApp. Se pierde.
- **Requisitos:**
  - Cliente sube imágenes y links al portal.
  - Organizador los ve anclados al evento.
  - Comentarios mínimos tipo A.3 sobre cada referencia.
- **Tier sugerido:** Pro.
- **Dependencias:** storage (compartido con C.1).

#### D.3 Agenda de reuniones (Calendly-lite)

- **Problema:** agendar una reunión de revisión toma 8 mensajes.
- **Requisitos:**
  - Organizador abre N slots desde su calendario.
  - Cliente reserva 1 in-portal.
  - Sincroniza con Apple/Google Calendar del organizador (Pilar 4 calendar sync).
- **Tier sugerido:** Business.
- **Dependencias:** Calendar sync (Pilar 4 del roadmap).

---

### Cluster E — Pagos e integraciones financieras (FUERA DE ALCANCE)

> [!danger] Decisión del producto — 2026-04-16
> Solennix **NO** procesa pagos entre el organizador y sus clientes a través de la app. No hay botón "Pagar" en el portal, no se integra Stripe/MercadoPago para este flujo, no se facilitan fondos de terceros. Motivo: evitar exposición legal/operativa de actuar como intermediario de pagos entre terceros.
>
> **Aclaración:** los pagos de suscripción del organizador hacia Solennix (Stripe) siguen vigentes — eso NO cambia. Lo que queda fuera es la facilitación cliente↔organizador.
>
> **Qué SÍ se puede hacer sin entrar en este terreno:**
> - Recordatorios al cliente sobre fechas de pago (ya planeado en [[13_POST_MVP_ROADMAP|Pilar 3]] como trigger `Recordatorio de pago`).
> - UI que muestra saldo pendiente (ya existe en el MVP como agregado).
> - Instrucciones de pago en texto libre que el organizador sube (sin procesar dinero).
>
> **Revisitar:** el usuario dejó la puerta abierta ("puede que más tarde sí, pero ahora no"). Solo reabrir cuando se solicite explícitamente.

---

### Cluster F — Telemetría inversa y confianza

#### F.1 Read-receipts

- **Problema:** el organizador no sabe si el cliente abrió la cotización.
- **Requisitos:**
  - Registro por vista: sección, timestamp, fingerprint anónimo.
  - Dashboard de "actividad del cliente" en EventDetail del organizador.
- **Riesgos:** privacidad — no tracking cross-device-identity; sólo "este token vio X".
- **Tier sugerido:** Gratis.
- **Dependencias:** ninguna.

#### F.2 Eventos del cliente al organizador

- **Problema:** hoy sólo `contract_signed` dispara push al organizador. Todo lo demás requiere que el organizador chequee manualmente.
- **Requisitos:**
  - Push cuando: cliente aprueba (A.2), comenta (A.3), vota (A.4), completa decisión de checklist (B.3), sube al moodboard (D.2), reserva reunión (D.3).
- **Tier sugerido:** Gratis (incluido con cada feature que lo necesita).
- **Dependencias:** cada feature respectiva.

---

### Cluster G — Multi-destinatario y relación continua

#### G.1 Sub-invitados al portal

- **Problema:** 1 token por evento = incómodo para bodas. Si comparto con 3 personas, todas ven todo.
- **Requisitos:**
  - Extender `event_public_links` existente con `scope [full | view | timeline_only]`, `recipient_label`, `recipient_email`.
  - N links activos simultáneos.
  - El endpoint público respeta el scope.
- **Tier sugerido:** Pro (3 links) / Business (ilimitado).
- **Dependencias:** ninguna (extensión de tabla existente).

#### G.2 Hub de relación histórica

- **Problema:** cliente que vuelve (2º boda, cumpleaños 1 año después) no ve su historial.
- **Requisitos:**
  - Portal muestra otros eventos del mismo `client_id` si el organizador lo habilitó.
  - Sin login — mismo token o token de cliente (ya no por evento).
- **Riesgos:** replantea el modelo de tokens — hoy es `event_public_links`, acá necesitaríamos `client_public_links`.
- **Tier sugerido:** Business.
- **Dependencias:** nueva tabla + refactor significativo.

#### G.3 Deep-links de WhatsApp segmentados

- **Problema:** hoy el link manda a la portada del portal. "Firmá el contrato" abre la home y el cliente tiene que buscar.
- **Requisitos:**
  - Parámetro `?section=contract&action=sign` en la URL del portal.
  - El portal hace scroll/highlight de la sección al cargar.
- **Tier sugerido:** Gratis.
- **Dependencias:** ninguna.

---

## 4. Tier Gating sugerido (síntesis)

| Cluster / Idea                    | Gratis | Pro   | Business |
| --------------------------------- | :----: | :---: | :------: |
| A.1 Inbox                         |        |   ✅  |    ✅    |
| A.2 Aprobaciones                  |        |   ✅  |    ✅    |
| A.3 Comentarios por sección       |        |   ✅  |    ✅    |
| A.4 Polls                         |        |   ✅  |    ✅    |
| B.1 Toggle de visibilidad         |  ✅    |   ✅  |    ✅    |
| B.2 Stepper de milestones         |  ✅    |   ✅  |    ✅    |
| B.3 Tareas cliente-lado           |        |   ✅  |    ✅    |
| C.1 Stream de media               |        |   ✅  |    ✅    |
| C.2 Ubicación en vivo             |        |   ✅  |    ✅    |
| C.3 Check-ins cualitativos        |  ✅    |   ✅  |    ✅    |
| D.1 RSVP / invitados              |        |   ✅  |    ✅    |
| D.2 Moodboard                     |        |   ✅  |    ✅    |
| D.3 Agenda Calendly-lite          |        |       |    ✅    |
| F.1 Read-receipts                 |  ✅    |   ✅  |    ✅    |
| F.2 Eventos al organizador        |  ✅    |   ✅  |    ✅    |
| G.1 Sub-invitados (3 / ilimitado) |        |   ✅  |    ✅    |
| G.2 Hub histórico                 |        |       |    ✅    |
| G.3 Deep-links segmentados        |  ✅    |   ✅  |    ✅    |

---

## 5. Tabla de paridad cross-platform (placeholder)

Formato idéntico al de [[02_FEATURES]]. `📋` = idea, aún no planeada.

| Feature                        | iOS | Android | Web-organizador | Web-portal-cliente | Backend |
| ------------------------------ | :-: | :-----: | :-------------: | :----------------: | :-----: |
| A.1 Inbox                      | 📋  |   📋    |       📋        |         📋         |   📋    |
| A.2 Aprobaciones               | 📋  |   📋    |       📋        |         📋         |   📋    |
| A.3 Comentarios por sección    | 📋  |   📋    |       📋        |         📋         |   📋    |
| A.4 Polls                      | 📋  |   📋    |       📋        |         📋         |   📋    |
| B.1 Toggle de visibilidad      | 📋  |   📋    |       📋        |         ➖         |   📋    |
| B.2 Stepper de milestones      | 📋  |   📋    |       📋        |         📋         |   📋    |
| B.3 Tareas cliente-lado        | 📋  |   📋    |       📋        |         📋         |   📋    |
| C.1 Stream de media            | 📋  |   📋    |       📋        |         📋         |   📋    |
| C.2 Ubicación en vivo          | 📋  |   📋    |       ➖        |         📋         |   📋    |
| C.3 Check-ins cualitativos     | 📋  |   📋    |       📋        |         📋         |   📋    |
| D.1 RSVP / invitados           | 📋  |   📋    |       📋        |         📋         |   📋    |
| D.2 Moodboard                  | 📋  |   📋    |       📋        |         📋         |   📋    |
| D.3 Agenda Calendly-lite       | 📋  |   📋    |       📋        |         📋         |   📋    |
| F.1 Read-receipts              | 📋  |   📋    |       📋        |         ➖         |   📋    |
| F.2 Eventos al organizador     | 📋  |   📋    |       📋        |         ➖         |   📋    |
| G.1 Sub-invitados              | 📋  |   📋    |       📋        |         📋         |   📋    |
| G.2 Hub histórico              | ➖  |   ➖    |       ➖        |         📋         |   📋    |
| G.3 Deep-links segmentados     | ➖  |   ➖    |       ➖        |         📋         |   ➖    |

---

## 6. Estimación gruesa por cluster (rangos, no compromisos)

| Cluster                           | Rango estimado | Nota                                        |
| --------------------------------- | :------------: | ------------------------------------------- |
| A — Bidireccionalidad             |    120–180h    | Inbox + approvals + comentarios + polls     |
| B — Transparencia granular        |     40–60h     | Mayormente backend + web; mobile ligero     |
| C — Momentos en vivo              |    100–140h    | Storage + upload + UI; decisión de proveedor|
| D — Co-planificación              |    100–140h    | RSVP es el mayor; moodboard y agenda medianos|
| E — Pagos                         |     ➖         | Fuera de alcance por decisión del producto   |
| F — Telemetría inversa            |     30–50h     | Tabla + middleware + UI de dashboard        |
| G — Multi-destinatario            |     40–80h     | G.1 y G.3 son ligeros; G.2 requiere refactor|
| **Total orientativo**             |  **430–650h**  | Spread en 2–3 trimestres realistas          |

---

## 7. Decisiones abiertas (requieren input del usuario)

1. **Inbox storage** — ¿tabla propia `event_messages` o integración con email (IMAP/Gmail API) como backing store?
2. **Media storage** — ¿S3, Cloudflare R2, Backblaze B2? ¿O reutilizamos el File Storage abstraction actual ([[07_TECHNICAL_ARCHITECTURE_BACKEND]] sección File Storage)?
3. **Modelo de tokens (G.2)** — ¿evolucionamos `event_public_links` a un sistema más general `public_links(kind, scope, subject_id)` o mantenemos tablas separadas?
4. **Moderación de media (C.1)** — ¿subida libre del organizador o hay algún filtro/reporte? Caso borde: cliente ve algo que no debía.
5. **Legal de aprobaciones (A.2)** — ¿las aprobaciones tipo `price_change` tienen valor contractual o son sólo registro operativo? Impacta el UX del disclaimer.
6. **PWA / app del cliente** — ¿el portal es una PWA instalable con push? Costo moderado, ganancia grande en retención de visitas.

---

## 8. Plan de implementación cross-platform

> [!note] Esqueletos, no specs
> Las secciones de abajo son **cómo se haría** a nivel de archivos y contratos, para que cuando priorices un cluster tengas el punto de partida. No son specs definitivas — un SDD change se abrirá por cluster aprobado.

### 8.1 Cluster A — Bidireccionalidad y aprobaciones

#### Backend (`backend/internal/`)

- Tablas nuevas:
  - `event_messages` (`id, event_id, author_type ['organizer'|'client'], author_ref, body, created_at, read_at_organizer, read_at_client`).
  - `event_approvals` (`id, event_id, proposed_by, kind, payload_json, status ['pending'|'approved'|'rejected'|'expired'], decided_at, decided_by`).
  - `section_comments` (`id, target_type ['quote_item'|'contract_clause'|'timeline_step'|'checklist_item'], target_id, author_type, body, resolved_at`).
  - `event_polls` + `event_poll_options` + `event_poll_votes`.
- Migraciones: `042_event_messages.sql`, `043_event_approvals.sql`, `044_section_comments.sql`, `045_event_polls.sql`.
- Handlers: `handler/messages.go`, `handler/approvals.go`, `handler/comments.go`, `handler/polls.go`.
- Endpoints:
  - Autenticado: `GET/POST /api/events/{id}/messages`, `POST /api/events/{id}/approvals`, `POST /api/approvals/{id}/decision`, etc.
  - Público (token portal): `GET/POST /api/public/events/{token}/messages`, `POST /api/public/events/{token}/approvals/{id}/decision`, etc.
- Push al organizador (reutilizar FCM; APNs pendiente de finalizar — tarea 2.6 de [[11_CURRENT_STATUS]]).
- Email fallback vía transactional mailer existente.

#### Web organizador (`web/src/`)

- `stores/messagesStore.ts`, `stores/approvalsStore.ts`.
- `services/messages.ts`, `services/approvals.ts`, etc.
- Drawer de mensajes en `EventDetailPage` (badge de unread en tab).
- Modal "Proponer al cliente" con dropdown de tipos.
- Vista embebida de comentarios sobre `QuoteItems`, `ContractClauses`, `TimelineSteps`, `ChecklistItems`.

#### Web portal cliente (`web/src/pages/ClientPortalPage.tsx`)

- Sección "Mensajes" siempre visible al final del portal.
- Card "Requiere tu decisión" al inicio cuando hay approvals/polls pendientes.
- Toolbar de comentario sobre line items (mismos componentes que el organizador en modo read-client).

#### iOS (`ios/Packages/SolennixFeatures/.../EventDetail/`)

- `MessagesView` + `MessagesViewModel` (`@Observable`).
- `ApprovalsInboxView` en bottom sheet del `EventDetailView`.
- `Route.eventMessages(id)` en `Solennix/Navigation/Route.swift`.
- Push notification tap → deep-link por `UIApplication.shared.open(url)` + URL scheme.

#### Android (`android/feature/events/`)

- `MessagesScreen` + `MessagesViewModel` + Hilt module.
- Nueva ruta type-safe de Compose Navigation: `EventMessagesRoute`.
- FCM `data` payload → `PendingIntent` con deep link.

---

### 8.2 Cluster B — Transparencia granular opt-in

#### Backend

- Tabla `event_visibility_prefs` (`event_id, section ['payments'|'products'|'extras'|'equipment'|'supplies'|'timeline'|'checklist'], mode ['hidden'|'aggregate'|'itemized']`).
- Extender handler público para aplicar prefs ANTES de serializar (test por modo).
- Columna `client_decision_required: bool` + `client_deadline: timestamptz` en `checklist_items`.
- Stepper de milestones: query derivada, no tabla. Campo computado.

#### Web organizador

- Panel "Qué ve tu cliente" en `EventDetailPage` con toggles + preview lado a lado.
- Componente `MilestoneStepper.tsx` reutilizable.

#### Web portal cliente

- Respeta prefs (data viene filtrada del backend).
- `MilestoneStepper` reutilizado arriba del hero.
- Sección "Te necesitamos" con tasks marcadas.

#### iOS

- `VisibilityPrefsView` tipo Settings (lista de toggles).
- `MilestoneStepperView` SwiftUI reutilizable.

#### Android

- `VisibilityPrefsScreen` con `SwitchPreference` Compose.
- `MilestoneStepper` composable reutilizable.

---

### 8.3 Cluster C — Momentos en vivo

#### Backend

- Tabla `event_media` (`id, event_id, kind ['photo'|'video'], url, thumb_url, caption, taken_at, uploaded_by`).
- Tabla `event_live_location` (`id, event_id, lat, lng, heading, speed, expires_at`) con job `cleanup_expired_locations`.
- Decisión #2 (storage) condiciona: presigned upload URL o upload directo.
- Endpoints: `POST /api/events/{id}/media` (upload iniciado), `GET /api/public/events/{token}/media`, `POST /api/events/{id}/location`.

#### iOS (Event Day Mode)

- `MediaCaptureView` con `PhotosPicker` + caption.
- Upload en background via `URLSession` `background` configuration.
- `CLLocationManager` con permiso `whenInUse`; envío de ubicación cada 30s mientras `departed && !arrived`.

#### Android (Event Day Mode)

- `MediaCaptureScreen` con `ActivityResultLauncher` de cámara.
- Upload en background con `WorkManager` (retry con backoff).
- `FusedLocationProviderClient` para ubicación; `ForegroundService` obligatorio en API 26+.

#### Web organizador

- Timeline view con media; permite borrar (sólo organizador).

#### Web portal cliente

- Feed estilo stories/timeline con lazy-load y `IntersectionObserver`.
- Ubicación en vivo: iframe de Google Maps embed con coordenadas actualizadas por polling (o WebSocket si se monta uno).

---

### 8.4 Cluster D — Co-planificación

#### Backend

- Tabla `event_guests` (`id, event_id, name, email, phone, rsvp_status ['pending'|'yes'|'no'|'maybe'], plus_one, dietary_notes, custom_fields_json`).
- Tabla `event_mood_items` (`id, event_id, kind ['image'|'link'|'note'], url, caption`).
- Tabla `event_meeting_slots` (`id, event_id, start_at, duration_min, status`) y `event_meeting_bookings` (`slot_id, booked_by, booked_at`).
- Endpoints autenticados y públicos.

#### Web portal cliente

- `GuestsPage` con importer CSV + generación de link de RSVP por invitado.
- `MoodboardPage` con drag&drop y upload reutilizando infra de C.1.
- `MeetingsPage` con listado de slots.

#### Web organizador / iOS / Android

- Lectura y edición de invitados, moodboard, reuniones.
- Reuniones en iOS/Android: deep link al Calendar nativo para confirmar (depende de Pilar 4 calendar sync).

---

### 8.5 Cluster E — Pagos

> [!danger] Fuera de alcance
> Ver nota en §3 Cluster E. No se documenta plan de implementación. Si el usuario reabre el alcance, esta sección se completa con Stripe/MercadoPago + webhook de reconciliación + UI de portal.

---

### 8.6 Cluster F — Telemetría inversa

#### Backend

- Tabla `portal_view_events` (`id, public_link_id, section, viewed_at, viewer_fingerprint_hash, ip_country`).
- Middleware en handler público que registra view por sección (rate-limit para evitar spam).
- Endpoint autenticado: `GET /api/events/{id}/portal-activity?from=...&to=...`.

#### Web organizador

- Tab "Actividad del cliente" en `EventDetailPage` con timeline de views.
- Heurísticas: "cliente vio el contrato 3 veces sin firmar — recordar".

#### iOS / Android

- Sección en EventDetail con lista de views.

#### Portal cliente

- No aplica — el cliente no ve su propia telemetría (evitar extrañeza).

---

### 8.7 Cluster G — Multi-destinatario

#### Backend

- Refactor ligero de `event_public_links`: agregar columnas `scope ['full'|'view'|'timeline_only']`, `recipient_label`, `recipient_email`.
- Permitir N links activos por evento (quitar `UNIQUE(event_id)` si existe).
- Endpoints: `POST /api/events/{id}/public-links` (crear adicional), `DELETE /api/public-links/{id}`, `GET /api/events/{id}/public-links`.

#### Web organizador / iOS / Android

- Share card amplía: lista de links con labels ("Mariana — full", "Madre de la novia — solo timeline"); CRUD inline.

#### Web portal cliente

- Endpoint público respeta scope; UI oculta secciones no autorizadas. Mensaje claro "estás viendo una versión limitada".

---

## 9. Archivos críticos ya existentes a tener en cuenta

| Ruta                                                       | Por qué                                                                   |
| ---------------------------------------------------------- | ------------------------------------------------------------------------- |
| `backend/internal/handler/`                                | Patrón handler existente — respetar estilo auth-gated vs token-public     |
| `backend/internal/repository/`                             | Repositorio por tabla, patrón actual                                      |
| `backend/migrations/`                                      | Numeración incremental, próxima `042_*.sql`                               |
| `backend/internal/repository/event_public_links.go`        | Base para G.1 (extensión mínima)                                          |
| `backend/internal/handler/public_event.go`                 | Base para B.1 (filtro antes de serializar)                                |
| `web/src/pages/ClientPortalPage.tsx`                       | Extender con secciones nuevas — no duplicar                               |
| `web/src/services/`                                        | Un service por cluster (`messagesService.ts`, etc.)                       |
| `web/src/stores/`                                          | Un store por cluster cuando haya estado compartido                        |
| `ios/Packages/SolennixNetwork/.../`                        | Endpoints tipados cross-cluster                                           |
| `ios/Packages/SolennixFeatures/.../EventDetail/`           | Extender ViewModel/Views                                                  |
| `android/core/network/`                                    | Services Ktor por cluster                                                 |
| `android/feature/events/`                                  | Screens Compose por cluster                                               |

---

## 10. Siguientes pasos

1. Usuario prioriza qué clusters van a [[13_POST_MVP_ROADMAP]] como Pilar 5 o extensión de Pilar 3.
2. Por cada cluster aprobado, abrir un change SDD (`/sdd-new cluster-X-nombre`) con specs, design, tasks.
3. Actualizar [[02_FEATURES]] reemplazando `📋` por `⬜` en las filas que pasen a roadmap firme.
4. Marcar este documento como `status: partially-implemented` cuando el primer cluster aterrice.

---

#prd #exploration #client-experience #portal-cliente #solennix
