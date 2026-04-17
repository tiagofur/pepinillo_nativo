---
tags:
  - prd
  - client-experience
  - portal-cliente
  - features
  - solennix
aliases:
  - Client Transparency & Delight
  - Features A–L
  - Portal Cliente Features
date: 2026-04-16
updated: 2026-04-17
status: active
---

# 12 — Client Transparency & Delight Features

> [!info] Estado global
> Feature A (Portal Cliente) **MVP cerrado en los 4 stacks** (Backend + Web + iOS + Android) al 2026-04-16. Features B–L en estado de diseño, alineadas a sprints Q2–Q4 2026 y Q1 2027.

> [!tip] Documentos relacionados
> [[PRD MOC]] · [[02_FEATURES|Feature Matrix]] · [[04_MONETIZATION|Monetización §4.3]] · [[09_ROADMAP|Roadmap]] · [[13_POST_MVP_ROADMAP|Post-MVP Roadmap]] · [[14_CLIENT_EXPERIENCE_IDEAS|Ideas Experiencia Cliente]] · [[15_PORTAL_CLIENTE_TRACKER|Portal Cliente Tracker]]

**Autor:** Sesión 2026-04-16.
**Última actualización:** 2026-04-17 (consolidación del root PRD al vault Obsidian).
**Objetivo:** Features que hacen que tanto el **organizador** (usuario pagante) como su **cliente** sientan la app como insustituible. Foco en transparencia, comunicación y momentos "antojables" que diferencian a Solennix de hojas de cálculo + WhatsApp.

---

## Status tracker de features

| Feature                                                               | Estado               | Plataformas                                                                       |
| --------------------------------------------------------------------- | -------------------- | --------------------------------------------------------------------------------- |
| **A. Portal público del cliente**                                     | ✅ **MVP completo**  | ✅ Backend + ✅ Web + ✅ iOS + ✅ Android · Gratis=básico, Pro=full                |
| B. Pagos del cliente — visualización + registro por transferencia     | 📋 Planeado          | Q3 2026 (Sprint 9) · reemplaza Stripe-checkout                                    |
| C. Notificaciones por etapa (configurable)                            | 📋 Planeado          | Q3 2026 (Sprint 11)                                                               |
| D. Thread de comunicación organizador↔cliente                         | 📋 Planeado          | Q3 2026 (Sprint 12)                                                               |
| E. Bandeja "Requiere tu decisión"                                     | 📋 Planeado          | Q3 2026 (Sprint 13)                                                               |
| F. Subida de contenido del cliente                                    | 📋 Planeado          | Q1 2027                                                                           |
| G. Firma digital de contratos                                         | 📋 Planeado          | Q4 2026 (Sprint 16)                                                               |
| H. RSVP de invitados                                                  | 📋 Planeado          | Q3 2026 (Sprint 14)                                                               |
| I. Reseñas post-evento                                                | 📋 Planeado          | Q2 2026 (Sprint 10) · Gratis=básicas, Pro=responder+portfolio                     |
| J. Branding del organizador (dominio custom + DKIM)                   | 📋 Planeado          | Q4 2026 (Sprint 17)                                                               |
| K. Multi-idioma cliente                                               | 📋 Planeado          | Q1 2027                                                                           |
| L. Resumen de valor post-evento                                       | 📋 Planeado          | Q1 2027                                                                           |

Ver [[09_ROADMAP]] para alineación con sprints.

---

## 1. Contexto

Hoy el organizador usa Solennix puertas adentro: eventos, cotizaciones, contratos, pagos, inventario. El cliente final **no ve nada** — todo es WhatsApp, Excel, PDF por email. Esto tiene dos costos:

1. **Organizador queda expuesto al caos del canal**: cliente pregunta lo mismo 4 veces, pierde pagos, no recuerda decisiones.
2. **Cliente no percibe el trabajo**: "me cobraron X y solo recibí un PDF". La organización invisible es organización desvalorizada.

La propuesta: abrir una **ventana controlada** al cliente — el organizador decide qué mostrar, cuándo, y cómo. Cero WhatsApp obligatorio, cero pérdida de información.

---

## 2. Principios rectores

- **El organizador es soberano.** Toggle todo. Nada se publica sin su permiso.
- **El cliente NO necesita instalar app.** Portal web responsive con link único. Opción mobile si quiere notificaciones.
- **Menos es más.** Cada notificación al cliente debe ganársela. Opt-in por canal, opt-in por milestone.
- **Branding del organizador, no de Solennix.** White-label en tiers Pro/Business. "Powered by Solennix" mínimo y discreto.
- **Paridad cross-platform obligatoria** (iOS · Android · Web · Backend) — ver [[../CLAUDE|CLAUDE.md]].
- **Monetización como palanca, no muro.** Features gratis que generen deseo de upgrade, no funciones esenciales atrapadas tras paywall.

---

## 3. Feature Groups

### A. Portal público del cliente (`/client/:token`) — ✅ MVP COMPLETO

**Estado:** MVP backend + web + iOS + Android **shipped 2026-04-16**. Tracking detallado en [[15_PORTAL_CLIENTE_TRACKER]].

**Qué (vision original):** URL única por evento (token de 256 bits, opcional PIN). No requiere cuenta ni instalación.

**Contenido por tarjetas (vision completa):**

- Header con branding del organizador (logo, colores, nombre).
- Countdown al evento.
- Resumen: fecha, hora, ubicación (mapa), dress code (opcional), invitados.
- Timeline visual de etapas: Contrato ✓ · Señal ✓ · Menú en revisión · Playlist pendiente · Evento.
- Equipo asignado (coordinador, fotógrafo, DJ) con foto y rol — opcional.
- Progress bar agregado: "Tu evento está 72% listo".

**Qué se shipeó en el MVP (2026-04-16):**

> [!success] Backend
> - Migration 041 `event_public_links` table (partial unique index garantiza 1 link activo por evento).
> - Endpoints autenticados: `POST/GET/DELETE /api/events/{id}/public-link`.
> - Endpoint público sin auth: `GET /api/public/events/{token}` con rate limit 10/min IP.
> - Response curada (`PublicEventView`) con: event basics, organizer branding, client name, payment summary (total/paid/remaining).
> - 410 Gone para revoked/expired → el frontend distingue "URL mal copiada" de "organizer deshabilitó".
> - Auto-revoke si el evento fue borrado mientras el link estaba activo.
> - Generación del token con `crypto/rand` (256 bits de entropía).

> [!success] Web
> - Ruta pública `/client/:token` → `ClientPortalPage.tsx` con hero + countdown + details grid + payment progress bar (con `role="progressbar"` aria-accessible).
> - `ClientPortalUnavailable` component con copy diferente para 404 vs 410.
> - Branding del organizer aplicado en vivo (color de marca + logo) con validación regex para evitar CSS injection.
> - `ClientPortalShareCard` en EventSummary tab Resumen: Copy + Compartir por WhatsApp + Rotar + Deshabilitar.
> - `eventPublicLinkService` wrappea los 3 endpoints autenticados.

**Qué queda de la vision original (pendiente):**

- 📋 **Timeline de etapas:** requiere nuevo schema para milestones. Va con feature C.
- 📋 **Equipo asignado:** requiere nuevo schema `event_staff`. Backlog.
- 📋 **Progress bar agregado ("72% listo"):** requiere definir métricas de completitud. Backlog.
- 📋 **PIN opcional:** extra layer de privacy para links sensibles. Backlog.
- 📋 **Field-level `visibleToClient`:** hoy la respuesta del backend es un subset fijo; el organizador aún no puede togglear campo por campo. Backlog.
- 📋 **Mapa integrado:** Google Maps embed en ubicación. Backlog.
- 📋 **Dress code:** requiere nuevo campo en Event. Backlog (baja prioridad).
- 📋 **OpenAPI docs:** los 4 endpoints aún no están en `backend/docs/openapi.yaml`. Follow-up.

**Implementación actual (diferente de la vision):**

- Backend: `GET /api/public/events/{token}` (sin auth, validación por UUID lookup en DB — NO HMAC como decía la vision original; la revocación/rotación vía UUID en DB es más flexible).
- Web: ruta pública en `web/src/pages/ClientPortal/ClientPortalPage.tsx` (no `client/ClientEventView.tsx` como decía la vision, renombrado por coherencia con el directorio `ClientPortal/`).

**Tier (decisión 2026-04-16 — ajustada al final del día para agregar "taste" Gratis):**

| Tier      | Portal                                                                                                                                                                                                                                                                          |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Gratis    | ✓ **básico** en ∞ eventos, sin branding propio, footer "Powered by Solennix" linkeado (drive marketing). Ve: evento + fecha + countdown + ubicación + invitados + status + greeting. **NO ve**: payment summary, cronograma, registrar pago, timeline, chat, decisiones, branding del organizer. |
| Pro       | ✓ + branding propio + payment summary + cronograma + timeline + todos los features B-I                                                                                                                                                                                          |
| Business  | + dominio custom + DKIM + white-label completo                                                                                                                                                                                                                                  |

**Filosofía del split:** el upgrade driver pasa a ser **CALIDAD** (cómo se ve) no **CANTIDAD** (cuántos portales). El Gratis siente el "wow, mi cliente vio una página pro de mi evento" pero inmediatamente nota las limitaciones y sube a Pro para quitarlas. Ver [[04_MONETIZATION|PRD/04 §4.3]] para el detalle de qué se expone en cada tier.

**Enforcement pendiente en Sprint 7.C** — hoy el MVP devuelve el shape completo para todos; la variante "basic shape para Gratis" se implementa cuando activemos gate.

---

#### A.1 Garantía de acceso perpetuo del cliente al evento

**Decisión 2026-04-16:** el cliente debe poder acceder al portal de SU evento **sin importar cuánto tiempo pase desde el evento**. Bodas, quinceañeras, eventos importantes — la gente vuelve años después a revisitar detalles, contratos, fotos, comprobantes. Cortar ese acceso es una regresión emocional que no queremos.

**Reglas:**

1. **Default de expiración: NULL (nunca caduca).** Ya implementado en el MVP — `event_public_links.expires_at` es nullable y los links se crean sin TTL por default. El organizador puede PONER un TTL explícito si quiere (ej. links promocionales temporales), pero la UI no debe mostrar un control de TTL a menos que lo pida explícitamente.
2. **Post-evento NO se revoca automáticamente.** No hay cron job que "limpie" links de eventos pasados. El link que funciona hoy, funciona también en 5 años.
3. **Revocación explícita SIGUE siendo posible pero con fricción.** El organizador puede revocar manualmente desde la share card (botón "Deshabilitar"); cuando el evento es más antiguo que X días (ej. 180), mostrar un confirm reforzado: *"Este evento fue hace 2 años. Si deshabilitás este enlace, tu cliente puede perder acceso a información que aún quiera consultar. ¿Continuar?"*
4. **Si el organizador borra su cuenta** → los events y sus links se borran en cascada (ON DELETE CASCADE). Para preservar acceso del cliente en ese escenario, futura feature:
   - `Business tier:` botón "Exportar portal como PDF permanente" antes de cerrar cuenta. Genera un snapshot estático hosted en URL permanente (`solennix.com/archive/{event-id}`) con los datos al momento de la exportación.
   - Backlog — no es P0 para el MVP.
5. **Cambio de URL del portal del cliente en el futuro** (rename `/client/:token` a otra cosa) → mantener el redirect legacy indefinidamente. NUNCA dejar URLs que el cliente haya guardado caer en 404.

**Implementación actual (MVP):** los 3 primeros puntos están ya garantizados por diseño. El punto 4 (export permanent) y el confirm reforzado del punto 3 van como follow-up.

---

### B. Pagos del cliente — visualización + registro por transferencia

**Qué:** Dos cosas bundleadas en el mismo flujo del portal (`/client/:token`):

1. **Transparencia** — el cliente ve balance, historial y próximos vencimientos en tiempo real (ya está parcialmente en el MVP de A).
2. **Registro de pago por transferencia** — el cliente reporta un pago que ya hizo por su home banking / Pix / MercadoPago / transferencia normal; el organizador aprueba o rechaza.

> [!warning] Decisión 2026-04-16
> Reemplazamos el "botón Pagar ahora con Stripe" del plan original por este flujo de registro + approve/reject. **Zero fees de pasarela**, mejor fit con realidad LATAM (80% paga por transferencia), organizador mantiene el control. Stripe-as-payment-gateway queda fuera de scope de producto por ahora; si se retoma en el futuro va como `B.bis — Pagos con tarjeta via pasarela` y coexistirá con este flujo.

---

#### B.1 Visualización (parcial ya en MVP A)

**Contenido:**

- Total del evento.
- Pagado / Pendiente / Vencido (con semáforo). _(hoy ya tenemos Total / Paid / Remaining en el portal MVP.)_
- Cronograma de cuotas: fecha, monto, estado. _(pendiente de schema + UI.)_
- Historial: cada pago aprobado con fecha, método, monto, link a comprobante (si lo adjuntó el cliente).
- Notificación automática al cliente 3 días antes de cada vencimiento (configurable desde settings).

**Implementación:**

- Backend: ampliar `PublicEventView` con `payment_schedule` + `payment_history` arrays.
- Tabla `payment_schedule` (si no existe): `id, event_id, due_date, amount, status (pending/paid/overdue), paid_at, payment_id`.
- UI: sección "Pagos" en `ClientPortalPage.tsx`.

---

#### B.2 Registro de pago por transferencia (nuevo, reemplaza Stripe)

**Flujo desde el cliente:**

1. En el portal (`/client/:token`), sección "Registrar un pago".
2. Formulario:
   - **Monto** (requerido).
   - **Clave de transferencia** (requerido) — el número que genera el banco al confirmar la transferencia. En AR: "CVU/CBU destino y comprobante". En MX: "referencia SPEI". En BR: "ID da transferência / Pix ID". El campo es un string libre — Solennix no valida contra el banco.
   - **Comprobante (imagen o PDF)** — **opcional** _(decisión provisional 2026-04-16; el organizador puede pedirlo después si no vino)_. Max 5 MB. Tipos: JPG / PNG / PDF.
   - **Nota del cliente** (opcional) — ej. "Pago de la segunda cuota + extras de fotografía".
3. Submit → toast "Tu pago está en revisión. El organizador te va a confirmar en breve."
4. Sección inferior "Mis registros": historial con estado — `En revisión` (amarillo) · `Aprobado ✓` (verde) · `Rechazado ✗` (rojo con nota del organizador).

**Flujo desde el organizador (EventDetail / EventSummary):**

1. Badge/alert cuando hay submissions pending: "3 pagos del cliente esperando revisión".
2. Lista con monto, clave, preview del comprobante (si hay), nota del cliente, fecha.
3. Botones:
   - **Aprobar** — nota opcional ("OK recibido Banco Santander 14:32"). Al aprobar:
     - Crea una row en `payments` (con método `transfer`, amount, fecha, link al comprobante).
     - Marca submission como `approved`, guarda `resulting_payment_id`, `reviewed_at`, `reviewed_by`.
     - Email al cliente: "Tu pago de $5,000 MXN fue confirmado."
   - **Rechazar** — nota **obligatoria** (el cliente necesita saber por qué). Al rechazar:
     - Marca submission como `rejected` + nota.
     - Email al cliente con la nota.
     - NO crea row en `payments`.

**Modelo de datos:**

```sql
CREATE TABLE payment_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  token_used TEXT NOT NULL,                         -- trazabilidad del portal
  amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  payment_method TEXT NOT NULL DEFAULT 'transfer',  -- futuro: 'mercadopago', 'pix', 'other'
  transfer_reference TEXT NOT NULL,                 -- clave del banco
  receipt_image_url TEXT,                           -- opcional
  client_note TEXT,                                 -- opcional
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected')),
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  organizer_note TEXT,
  resulting_payment_id UUID REFERENCES payments(id) ON DELETE SET NULL,
  submitter_ip INET,                                -- audit trail
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payment_submissions_event_pending
  ON payment_submissions(event_id) WHERE status = 'pending';

-- En la tabla payments existente:
ALTER TABLE payments ADD COLUMN submission_id UUID REFERENCES payment_submissions(id);
```

**Endpoints nuevos:**

| Método | Path                                                                        | Auth              | Descripción                                            |
| ------ | --------------------------------------------------------------------------- | ----------------- | ------------------------------------------------------ |
| POST   | `/api/public/events/{token}/payment-submissions`                            | 🔓 rate-limited    | Cliente submite pago                                    |
| GET    | `/api/public/events/{token}/payment-submissions`                            | 🔓 rate-limited    | Cliente ve SUS submissions + estados                    |
| POST   | `/api/public/uploads/receipt`                                               | 🔓 rate-limited    | Subir imagen del comprobante                            |
| GET    | `/api/events/{id}/payment-submissions`                                      | 🔒                 | Organizador lista pending + history                     |
| POST   | `/api/events/{id}/payment-submissions/{submissionId}/approve`               | 🔒                 | Organizador aprueba                                     |
| POST   | `/api/events/{id}/payment-submissions/{submissionId}/reject`                | 🔒                 | Organizador rechaza (nota obligatoria)                  |

**Seguridad:**

- Rate limit del POST público: 5 submissions/hora por token. Evita spam.
- Upload de comprobante: max 5 MB, content-type whitelist (`image/jpeg`, `image/png`, `application/pdf`), nombre hasheado, stored en bucket separado.
- `transfer_reference` es solo string — Solennix NO valida contra el banco. Organizador verifica manualmente contra su home banking.
- Rotar el token NO borra submissions — son históricas por evento. Nuevo token ve las MISMAS submissions.
- Submitter IP grabada para audit.

**Notificaciones:**

- Submission creada → email + push al organizador: "Nuevo pago registrado por {cliente}: ${amount}".
- Approved → email al cliente: "Tu pago de ${amount} fue confirmado. Gracias!"
- Rejected → email al cliente: "No pudimos confirmar tu pago de ${amount}. Razón: {organizer_note}. Contactanos para resolver."

**Tier gating (provisional — revisable post-launch):**

| Tier      | Límite                                                                                              |
| --------- | --------------------------------------------------------------------------------------------------- |
| Gratis    | ∞ submissions, ∞ history, review manual.                                                            |
| Pro       | + email templates customizables + bulk approve.                                                     |
| Business  | + auto-match con CSV de estado de cuenta del banco (feature futura), + API export de payment_submissions. |

**Por qué es "antojable":** el cliente deja de mandar screenshots por WhatsApp. El organizador deja de tener que pedirlos + responder "recibí, gracias". Todos tienen el audit trail limpio. **Cero fees.** Cero dependencia de pasarelas externas.

---

### C. Notificaciones por etapa (configurable on/off)

**Qué:** Cuando el organizador completa una tarea interna, se dispara (opcionalmente) una notificación al cliente.

**Milestones sugeridos (extensibles):**

- Contrato firmado
- Señal/pago recibido (cada pago)
- Menú confirmado / modificado
- Playlist recibida
- Confirmación de proveedor clave (catering, DJ, fotógrafo)
- Lista de invitados cerrada
- 7 días / 48h / 24h / 2h antes del evento
- Post-evento: "Gracias por confiar en nosotros"

**Configuración (por evento y por default):**

- Toggle ON/OFF por milestone.
- Canales: email · SMS · WhatsApp (vía Twilio/CloudAPI) · push (si el cliente instaló la app — futuro).
- Templates editables con tokens: `{cliente_nombre}`, `{evento_fecha}`, `{organizador_nombre}`, `{monto}`, `{link_portal}`.
- Quiet hours: nada entre 21:00–09:00 hora local del cliente.

**Implementación:**

- Backend: `internal/service/milestone_notifications.go`, scheduler (cron + event hooks).
- Tabla `milestone_preferences` por usuario + `milestone_triggers` por evento.
- UI settings: `Settings → Notificaciones al cliente` (iOS/Android/Web).

**Tier (decisión 2026-04-16):** Pro (email + push, 10 milestones) · Business (+ SMS + WhatsApp Business API + milestones ilimitados + templates custom). **Gratis sin acceso** (coherente con la regla "Gratis no tiene comunicación con el cliente").

---

### D. Thread de comunicación organizador↔cliente

**Qué:** Chat thread por evento, persistente, searchable. Reemplaza el WhatsApp caótico.

**Características:**

- Mensajes texto + adjuntos (imágenes, PDFs, links).
- Notas internas (solo el organizador ve) vs mensajes compartidos.
- Typing indicators, read receipts (el organizador activa/desactiva).
- Búsqueda por palabra clave.
- Export a PDF "Histórico de comunicación" — útil ante disputas.

**Implementación:**

- Backend: `internal/service/event_chat.go`, tabla `event_messages` con campos `author_type (organizer|client|system)`, `visibility (internal|shared)`.
- Real-time vía WebSocket o SSE (futuro) — empieza con polling.
- UI: integrado en `EventDetailView` (iOS/Android) y `EventDetailPage` (Web).

**Tier:** Pro en adelante. **Gratis sin acceso** (Gratis no tiene portal cliente — ver [[04_MONETIZATION|PRD/04 §4.2]]).

---

### E. Bandeja "Requiere tu decisión"

**Qué:** El organizador marca ítems que necesitan input del cliente. El cliente entra al portal y los resuelve.

**Ejemplos de decisiones:**

- "Aprobá este menú" → acepta / pide cambios con comentario.
- "Elegí canción principal del vals" → text input o link a Spotify.
- "Subí lista de invitados" → CSV upload o formulario.
- "Confirmá paleta de colores" → seleccionar opción.

**Cada decisión tiene:**

- Deadline sugerido.
- Estado: pendiente · respondida · vencida.
- Notificación automática al cliente si faltan 48h.
- Registro inmutable de la respuesta (audit trail).

**Implementación:**

- Backend: tabla `client_decisions` con `type`, `payload_schema`, `response`, `responded_at`, `deadline`.
- Handler público para responder: `POST /api/public/events/:slug/decisions/:id`.
- UI organizador: componente "Pedir decisión al cliente" con plantillas.
- UI cliente: sección destacada en portal.

**Por qué es "antojable":** todo organizador ha perdido una semana esperando una respuesta por WhatsApp. Esto mata esa fricción.

---

### F. Subida de contenido del cliente

**Qué:** El cliente sube al portal lo que el organizador le pida: referencias visuales, playlist, lista invitados, documentos.

**Implementación:**

- Reutiliza el sistema de uploads del organizador (S3 o disk storage).
- Aparece automáticamente en el event detail del organizador.
- Notification push al organizador cuando el cliente sube algo.

**Tier:** Pro en adelante.

---

### G. Firma digital de contratos (client-side)

**Qué:** El cliente firma el contrato desde el portal, sin imprimir ni scanear.

**Tipos de firma:**

- Nombre tipeado + checkbox "acepto términos".
- Firma dibujada (canvas en touch).
- Validez legal en LATAM varía — chequear por país. Idealmente integración con proveedor (DocuSign, HelloSign, Validasign) en tier Business.

**Metadata capturada:**

- Timestamp UTC + timezone detectado.
- IP del firmante.
- User-agent.
- Hash SHA-256 del documento firmado (inmutabilidad).
- PDF final con página de "Evidencia de firma" adjunta.

**Implementación:**

- Backend: endpoint `POST /api/public/contracts/:id/sign` + `ContractSignature` entity.
- PDF post-firma con metadata.
- Notificación al organizador: email + push.

**Tier:** Pro (firma simple con canvas) · Business (integración legal con proveedor).

---

### H. RSVP de invitados del cliente

**Qué:** El cliente puede activar una sub-página `/client/:eventSlug/rsvp` donde sus invitados confirman asistencia.

**Flow:**

- El cliente carga lista de invitados (CSV o manual) o comparte un link abierto.
- Cada invitado ingresa nombre + confirma asistencia + restricciones alimentarias + +1.
- Conteo en tiempo real visible para cliente y organizador.
- Integración con inventario/catering: "Tenés 95 confirmados, planificaste para 100, todo OK".

**Implementación:**

- Tabla `event_rsvps`.
- Sub-página pública del portal del cliente.

**Tier:** Pro en adelante.

---

### I. Reseñas post-evento

**Qué:** 24–72h después del evento, el cliente recibe un link automático para dejar una reseña (1-5 estrellas + texto opcional).

**Flow inteligente:**

- Si rating ≥4 → prompt "¿Querés compartirla públicamente en Google/Facebook?" con link pre-llenado.
- Si rating ≤3 → solo va al organizador (feedback privado, no quemado público).
- El organizador construye un portfolio público de testimoniales en un URL share-friendly (`/organizer/:slug/reviews`).

**Tier (decisión 2026-04-16 ajustada):**

| Tier      | Reseñas                                                                                                                                             |
| --------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| Gratis    | ✓ **básicas**: email automático al cliente 48h post-evento + organizer ve la review privada en EventDetail. **NO puede responderla**, **NO hay portfolio público**. |
| Pro       | + responder reviews del cliente + portfolio público en `/organizer/:slug/reviews`                                                                   |
| Business  | + integración con Google Reviews + Facebook (OG tags + prompt post-review)                                                                          |

**Filosofía:** Gratis ve el wow emocional ("mi cliente me dejó 5 estrellas, qué lindo") pero no puede capitalizarlo marketing-wise → upgrade driver claro. Feature cruzada con marketing del organizador → retención fuerte.

---

### J. Branding del organizador

**Qué:** Logo, colores, tipografía y dominio custom en todos los touch-points del cliente.

**Alcance:**

- Portal del cliente.
- Emails enviados (desde `eventos@organizador.com` en tier Business — DKIM propio).
- PDF de contratos/cotizaciones/recibos.
- Firma de emails del organizador.

**Implementación:**

- Tabla `organization_branding` con logo_url, primary_color, accent_color, font, email_from, custom_domain.
- CNAME/verificación de dominio para Business.

**Tier:** Pro (logo + colores) · Business (+ custom domain + DKIM).

---

### K. Multi-idioma cliente

**Qué:** El portal del cliente detecta idioma del browser y ofrece: español (default), portugués (Brasil → gran mercado), inglés.

**Implementación:**

- i18n en rutas `/client/:eventSlug` → `i18next` o similar en web.
- Content editorial del organizador (nombres, descripciones): quedan en idioma del organizador. Solo chrome/labels traducidos.

**Tier:** Pro (es + en + pt). **Gratis sin acceso** (feature vive dentro del portal cliente, que es Pro+).

---

### L. Resumen de valor post-evento

**Qué:** Página que se activa cuando el evento termina. "En números: 47 tareas coordinadas · 12 proveedores · 8 pagos · 127 invitados confirmados · 23 mensajes intercambiados".

**Objetivo:** hacer visible el trabajo invisible. Construye lealtad (cliente se acuerda de lo que costó hacer el evento).

**Implementación:** agregación estadística del evento en un template PDF + vista web.

**Tier:** Pro (básico + custom branding) · Business (+ exportable para portfolio). **Gratis sin acceso** (feature se renderiza dentro del portal cliente).

---

## 4. Matriz de priorización

| Feature                   | Impacto organizador | Impacto cliente    | Complejidad     | Dependencias              | Prioridad |
| ------------------------- | ------------------- | ------------------ | --------------- | ------------------------- | --------- |
| A. Portal público         | Alto                | Alto               | Media           | —                         | **P0**    |
| B. Transparencia pagos    | Alto                | Muy alto           | Media           | A, pasarela opcional      | **P0**    |
| C. Notificaciones etapa   | Alto                | Medio              | Media           | A, email ya existe        | **P1**    |
| D. Thread comunicación    | Muy alto            | Alto               | Alta            | A                         | **P1**    |
| E. Bandeja decisiones     | Muy alto            | Medio              | Media           | A, D                      | **P1**    |
| F. Upload del cliente     | Medio               | Bajo               | Baja            | A                         | **P2**    |
| G. Firma digital          | Alto                | Alto               | Alta (legal)    | A                         | **P2**    |
| H. RSVP invitados         | Medio               | Medio              | Media           | A                         | **P2**    |
| I. Reseñas post-evento    | Muy alto (marketing)| Bajo               | Baja            | A                         | **P1**    |
| J. Branding               | Medio               | Medio              | Media           | A                         | **P2**    |
| K. Multi-idioma           | Bajo                | Medio              | Baja            | A                         | **P3**    |
| L. Resumen de valor       | Medio               | Alto emocional     | Baja            | —                         | **P2**    |

**Orden sugerido de implementación:** A → B → I → D → E → C → H → F → G → J → L → K.

---

## 5. Matriz de monetización (tiers)

> [!info] Regla global (decisión 2026-04-16, ajustada al final del día)
> Gratis tiene **versión básica** de 2 features cara-al-cliente (Portal A + Reseñas I) como teaser + drive de conversión. Todo lo demás es Pro+. Ver [[04_MONETIZATION|PRD/04 §4.2-4.3]] para el detalle de qué se expone en cada tier de las features "teaser".

| Feature                                                            | Gratis                                                              | Pro                                                                       | Business                                    |
| ------------------------------------------------------------------ | ------------------------------------------------------------------- | ------------------------------------------------------------------------- | ------------------------------------------- |
| Portal público (A)                                                 | ✓ **básico** en ∞ eventos, sin branding, footer Solennix linkeado    | ∞ + branding propio + payment summary + timeline + features B-I            | + dominio custom + DKIM                     |
| Transparencia pagos + registro por transferencia (B)               | —                                                                   | ✓ + bulk approve + email templates                                         | + auto-match CSV banco                      |
| Notificaciones al cliente (C)                                      | —                                                                   | Email + Push, 10 milestones                                                | + SMS + WhatsApp API + ∞ milestones + templates custom |
| Chat organizador↔cliente (D)                                       | —                                                                   | ✓                                                                          | + export legal                              |
| Decisiones pendientes (E)                                          | —                                                                   | ∞                                                                          | + flujos multi-paso                         |
| Upload cliente (F)                                                 | —                                                                   | 1GB                                                                        | ∞                                           |
| Firma digital (G)                                                  | —                                                                   | ✓ (canvas simple)                                                          | + proveedor legal                           |
| RSVP invitados (H)                                                 | —                                                                   | 500 invitados                                                              | ∞                                           |
| Reseñas post-evento (I)                                            | ✓ **básicas** (email + vista privada del organizer)                  | + responder review + portfolio público                                     | + integración Google/FB                     |
| Branding portal (J)                                                | —                                                                   | Logo + colores                                                             | + dominio custom + DKIM                     |
| Multi-idioma cliente (K)                                           | —                                                                   | es + en + pt                                                               | + idiomas custom                            |
| Resumen valor post-evento (L)                                      | —                                                                   | + custom branding                                                          | + exportable                                |

> [!note] Nota sobre el registro de pago por transferencia (B)
> Este flujo NO usa Stripe ni ninguna pasarela — el cliente reporta un pago que ya hizo por su banco (Pix, SPEI, transferencia, MercadoPago, etc.) y el organizador aprueba o rechaza. Zero fees. Solennix es solo el canal de registro + audit trail, no la pasarela.

---

## 6. Paridad cross-platform

El portal del cliente **NO necesita view nativa** — se consume en browser. Lo que SÍ debe tener paridad iOS/Android/Web:

| Superficie                               | iOS  | Android | Web         | Backend |
| ---------------------------------------- | ---- | ------- | ----------- | ------- |
| Toggle "visibleToClient" por campo       | ✓    | ✓       | ✓           | ✓       |
| Botón "Copiar/compartir link cliente"    | ✓    | ✓       | ✓           | —       |
| Thread de comunicación (D)               | ✓    | ✓       | ✓           | ✓       |
| Settings de notificaciones al cliente (C)| ✓    | ✓       | ✓           | ✓       |
| Bandeja decisiones pendientes (E)        | ✓    | ✓       | ✓           | ✓       |
| Upload review (F)                        | ✓    | ✓       | ✓           | ✓       |
| Dashboard reseñas (I)                    | read | read    | full edit   | ✓       |
| Branding editor (J)                      | read | read    | full edit   | ✓       |

**Nota clave:** el editor de branding y el portfolio de reseñas son **web-only-edit** (desktop primario según CLAUDE.md). Mobile solo lectura para mantener paridad sin sobrecargar.

---

## 7. Consideraciones técnicas transversales

- **Seguridad del portal público:** token firmado HMAC con expiración configurable (30/90/365 días, default 365). Revocable. Opción PIN extra (4 dígitos).
- **Privacy:** el cliente NO ve: notas internas, márgenes del organizador, otros eventos, info de otros clientes, inventario interno.
- **Audit log:** toda acción del cliente queda loggeada (IP, UA, timestamp).
- **Rate limiting:** endpoints públicos con rate limit agresivo (10 req/min por token).
- **Emails transaccionales:** Resend/Postmark/Mailgun. DKIM+SPF configurado.
- **WhatsApp:** Twilio Conversations o Meta Cloud API. Solo Business tier — costo por mensaje transferible.
- **Accesibilidad:** portal cliente WCAG AA. Dynamic type, contraste, VoiceOver/TalkBack.
- **Performance:** portal cliente < 2s first contentful paint en 3G. Static bundle + API edge caching.

---

## 8. Métricas de éxito

- **% eventos con portal activo** (meta 90 días: 40%).
- **% clientes que entran al portal** (meta: 60%).
- **NPS del cliente final** (encuesta opcional al final del flujo de reseña).
- **Reducción de tiempo de cobranza** (días entre emisión de cuota y pago).
- **% conversión Gratis → Pro atribuible a branding/portal** (tier).
- **# reseñas 4-5 estrellas/mes**.

---

## 9. Preguntas abiertas

- ¿Integramos con Google Calendar para que el cliente agregue el evento con un click? (Fácil, alto valor.)
- ¿Notificaciones WhatsApp en tier Pro con costo pasado al organizador, o reservadas para Business? Decide comercial.
- ¿Dejamos el portal 100% anónimo con link-only, o forzamos auth ligera (email + código) para acciones sensibles como firmar? Preferencia legal: auth ligera para firma.
- ¿Gallery post-evento con fotos del fotógrafo? Escopable como feature separada (cruce con "storage cost" → Business).
- ¿Integración con redes sociales para compartir countdown/portal? (Bajo prioridad, pero viral.)

---

## 10. Siguientes pasos

1. ✅ **Feature A MVP shipped en los 4 stacks** — Backend + Web (2026-04-16, commits `8dff4f3` + `06d69ff` + `a3f425a`) + iOS + Android (mismo día). Ver [[15_PORTAL_CLIENTE_TRACKER]].
2. 📋 **Sprint 7.C — Enforcement de límites por tier:** gate del "1 portal activo" Gratis vs "∞" Pro/Business en el backend.
3. 📋 **Sprint 9 — Feature B (Transparencia de pagos):** cronograma de cuotas + registro de pago por transferencia + approve/reject del organizador.
4. 📋 **Sprint 10 — Feature I (Reseñas post-evento):** cron job + UI pública + portfolio público del organizer.
5. 📋 **Sprint 11 — Feature C (Notificaciones por etapa).**
6. Prototipar el diseño del portal completo con timeline + team en Figma — consistencia con la paleta `#C4A265` / `#1B2A4A` y la personalidad "elegante profesional cálida".
7. Investigar regulación de firma digital por país (MX, AR, CO, CL, PE) antes de diseñar feature G (Q4 2026).
8. Validar con usuarios reales (5 organizadores MX) el flujo del Portal Cliente MVP tras el deploy para detectar fricciones de UX antes de Sprint 9.

---

#prd #client-experience #portal-cliente #features #solennix
