---
tags:
  - view
  - pendientes
  - tareas
aliases:
  - Pendientes
  - Open Items
platform: all
type: view
status: active
date: 2026-04-17
updated: 2026-04-21
---

# ✅ Pendientes por Plataforma

> [!tip] Requiere el plugin **Dataview** para las queries automáticas.
> Las tareas Markdown `- [ ]` se agregan automáticamente con el plugin activo.

---

## Tareas abiertas en todos los documentos

```dataview
TASK
FROM "Pepinillo"
WHERE !completed
GROUP BY file.link
SORT file.name ASC
```

---

## Tareas completadas (esta semana)

```dataview
TASK
FROM "Pepinillo"
WHERE completed AND completion >= date(today) - dur(7 days)
GROUP BY file.link
```

---

## P0 — Críticos sin completar (manual)

Actualizar esta lista cada sprint:

| Plataforma | Item | Referencia |
|---|---|---|
| iOS | Crear Apple Unlock + Everywhere en RevenueCat / StoreKit | [[../iOS/Arquitectura General]] |
| Backend | Capability split + creditos IA mensuales | [[../Backend/Autenticacion & Suscripciones]] |
| Android | Migrar billing legacy a Everywhere | [[../Backend/Autenticacion & Suscripciones]] |
| watchOS + Wear OS | Propagar entitlements nuevos desde companion app | [[../Cross-Platform/Parity Matrix]] |

---

## Backlog próximo sprint

> Reemplazá esta sección al iniciar un sprint nuevo usando `[[_templates/Template - Sprint]]`.

- [ ] Crear offers Apple Unlock + Everywhere en Apple
- [ ] Diseñar capability split backend + ledger IA
- [ ] Migrar Android de `premium` legacy a Everywhere
- [ ] Propagar entitlements a watchOS y Wear OS

---

## Referencias
- [[Parity Gaps|Brechas de paridad]]
- [[../00_DASHBOARD|Dashboard]]
