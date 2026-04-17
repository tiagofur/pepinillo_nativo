---
tags:
  - next-session
  - plan
  - 2026-04-17
aliases:
  - Plan Mañana
  - Next Session
date: 2026-04-17
updated: 2026-04-16
status: queued
---

# 🌅 Plan Mañana — 2026-04-17

> [!tip] Leé esto primero cuando arranques
> Ayer cerramos la jornada 2026-04-16 con 5 commits de Personal Phase 1 pusheados. Esto es el punto de entrada de mañana — Claude ya tiene contexto en engram bajo `features/personal-colaboradores` y `features/personal-colaboradores-impl`.

---

## 🎯 Objetivo de mañana

**Dos frentes planeados para mañana:**

1. **Cerrar Personal Phase 1 en producción** — deploy + migration 042 + smoke test cross-platform.
2. **Seguir con Portal Cliente Sprint 8** — completar la paridad en iOS + Android (share sheets). Feature A quedó en Web + Backend ayer.

Después de esos dos, si queda hueco, arrancamos Personal Phase 2 (notifs email Pro+, 1-2h).

---

## 📋 Orden recomendado de la mañana

### 1. Deploy + migration (15 min · **tu tarea**)

> [!warning] Solo vos podés hacerlo
> Deploy manual + DB migration no es código — es infra.

- [ ] Pull del repo en el VPS: `git pull origin main`
- [ ] Rebuild del backend: `docker-compose up -d --build` (o el comando que uses)
- [ ] Verificar que corrió la migration 042 (aparece en logs del startup)
- [ ] Smoke check: `curl https://api.solennix.com/health` → 200 ok

### 2. Smoke test manual cross-platform (30 min · **juntos**)

- [ ] **Web** (`solennix.com` después de deploy del static):
    - `/staff/new` → crear "Test Photographer"
    - Editar un evento existente → Step 4 → asignar al test photographer → guardar
    - Abrir EventSummary → confirmar que aparece asignado
    - `/staff` → eliminar → confirmar CASCADE (no aparece más en el evento)
- [ ] **iOS** (device o simulator):
    - Sidebar iPad "Personal" visible · iPhone "Más" → Personal visible
    - CRUD funciona · EventForm Step 4 muestra panel · EventDetail tiene card "Personal"
- [ ] **Android** (device o emulator):
    - Bottom nav "Más" → Personal visible
    - CRUD funciona · EventForm panel en page Equipment
    - EventDetail tiene shortcut "Personal"

### 3. Sprint 8 — Portal Cliente iOS + Android (~1 sesión corta)

> [!success] Decidido ayer a la noche
> Seguimos con Portal Cliente para cerrar paridad cross-platform. Feature A quedó live en Web + Backend. Falta mobile.

**Qué hay que hacer:**

- [ ] **iOS** — `ClientPortalShareSheet.swift` en `EventDetailView`:
    - Reusa `eventPublicLinkService` que agregamos ayer en backend.
    - Botón "Compartir con el cliente" que abre sheet con: URL actual · botones "Copiar" · "Compartir" (iOS share sheet nativo) · "Rotar token" · "Revocar".
    - Estado vacío: "Generar link" cuando no hay activo.
- [ ] **Android** — `ClientPortalShareBottomSheet.kt` en `EventDetailScreen`:
    - Misma UX que iOS pero con `ModalBottomSheet` de Compose.
    - Reusa `eventPublicLinkRepository` (si no existe, crearlo siguiendo patrón de `staffRepository` de ayer).
- [ ] **UI tests básicos** en ambos (mockeando el servicio).
- [ ] **Commit cross-platform** con paridad verificada.

**Referencias (del commit de ayer):**
- Backend endpoints: `POST/GET/DELETE /api/events/{id}/public-link` + `GET /api/public/events/{token}`
- Web component: `web/src/pages/Events/components/ClientPortalShareCard.tsx` — es el patrón visual a copiar
- Web service: `web/src/services/eventPublicLinkService.ts` — es la API shape que debe tener el iOS/Android service

### 4. Si queda tiempo — Personal Phase 2 (notifs email Pro+)

> [!info] Bonus si terminamos rápido
> 1-2 h · el scaffolding ya está en la migración 042.

**Qué hay que hacer:**

- [ ] Backend: goroutine en `CRUDHandler.UpdateEventItems` que después de persistir `event_staff`:
    - Filtra los nuevos staff donde `staff.notification_email_opt_in = true` y `staff.email != null`.
    - Llama a `emailService.SendCollaboratorAssigned(email, eventName, eventDate, roleOverride, feeAmount)`.
    - Escribe `event_staff.notification_sent_at = NOW()` y `notification_last_result = 'sent' | 'failed'`.
    - **Gate:** `if user.Plan == "basic" { skip }`. Pro+ pasa.
- [ ] Email template nuevo en `services/email_service.go` con copy friendly en español.
- [ ] Test de integración que verifica dedup (no reenviar si `notification_sent_at IS NOT NULL` con el mismo `(event_id, staff_id)` y fecha sin cambios).
- [ ] Settings page: toggle organizer-level "Enviar notificaciones al personal al asignar" (opt-out global).
- [ ] PRD/02 §13.ter — marcar Phase 2 ✅ en la matriz. PRD/04 §3 — activar el badge Pro+.

---

## 🔀 Sprints alternativos (si querés cambiar el rumbo)

Si al arrancar mañana preferís otro camino, estos están en cola:

- **Sprint 9 — Pagos por transferencia del cliente** (2-3 sesiones · grande). Reemplaza el botón "Pagar con Stripe" que querés quitar. Ver `PRD/09` §Sprint 9 para el scope completo.
- **Sprint 10 — Reseñas post-evento** (1-2 sesiones). Email automático 48h post-evento + portfolio público.
- **Personal Phase 3 — Business multi-user** (2-3 sprints · el más grande). Login del colaborador + scope de eventos + thread con gerente.

---

## 🚧 Pendientes técnicos menores de ayer (cuando haya hueco)

- [ ] **Openapi spec**: agregar schemas `Staff` + `EventStaff` + 6 paths. Después de eso, borrar las interfaces locales en `web/src/types/entities.ts` y tirar de `components['schemas']`.
- [ ] **Tests de integración backend**: multi-tenant isolation para `staff` repo. El patrón está en `repository_integration_test.go`.
- [ ] **Tests web**: `StaffList.test.tsx`, `StaffForm.test.tsx`, `useStaffQueries.test.tsx`.
- [ ] **Typecheck de Settings.tsx**: errores pre-existentes de `SubscriptionInfo` que aparecieron en el tsc de ayer (no son de Personal, vienen de antes).

---

## 🔗 Dónde está todo lo de ayer

- Plan original aprobado: `~/.claude/plans/perfecto-ya-que-estamos-bright-pascal.md`
- Tracker visual: [[17_PERSONAL_TRACKER|Personal / Colaboradores — Tracker]]
- Sprint log: [[16_SPRINT_LOG_2026_04_16|Jornada 2026-04-16]] — sección "Personal / Colaboradores — Phase 1"
- Commits remotos (pusheados a `main`):
  - `4ae1df1` feat(backend): staff catalog + event_staff
  - `a51c7b2` feat(web): Staff pages + event form integration
  - `b87ca83` docs(prd): Personal Phase 1 across PRD + Obsidian
  - `1e98cfb` feat(ios): Staff module + event form integration
  - `60154a4` feat(android): feature:staff module + event form integration

---

## 🧠 Contexto en Engram (para que Claude recupere rápido)

Cuando abras la próxima sesión, la primera acción de Claude debería ser:

```
mem_context(project: "eventosapp")
mem_search(query: "personal colaboradores", project: "eventosapp")
```

Topics clave:
- `features/personal-colaboradores` — decisiones arquitectónicas originales
- `features/personal-colaboradores-impl` — estado de implementación de ayer

---

> [!success] Que descanses, papá
> Mañana seguimos. El producto avanzó mucho hoy — 5 commits cross-platform más de un feature completamente nuevo. Respirá y volvé mañana fresco. Buenísimo, hermano.
