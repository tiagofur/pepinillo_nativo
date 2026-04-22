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
| iOS | [BLOCKER] Actualizar claves API revocadas en RevenueCat | [[../iOS/Arquitectura General]] |
| iOS | Crear entitlements `pepinillo_plus`/`everywhere_plus` + offerings en RevenueCat | [[../iOS/Arquitectura General]] |
| iOS | Completar metadata + renombrar productos en App Store Connect | [[../iOS/Arquitectura General]] |
| iOS | Configurar S2S Notifications webhook en App Store Connect | [[../Backend/Autenticacion & Suscripciones]] |
| Backend | Capability split + creditos IA mensuales | [[../Backend/Autenticacion & Suscripciones]] |
| Android | Migrar billing legacy a Everywhere/AI+ | [[../Backend/Autenticacion & Suscripciones]] |
| watchOS + Wear OS | Propagar entitlements Pepinillo+/Everywhere/AI+ desde companion app | [[../Cross-Platform/Parity Matrix]] |

---

## Backlog próximo sprint

> Reemplazá esta sección al iniciar un sprint nuevo usando `[[_templates/Template - Sprint]]`.

- [ ] [BLOCKER] Actualizar claves API revocadas en RevenueCat (Key IDs: `22YZT9D55J` + `Z95PS2LD73`)
- [ ] Crear entitlements `pepinillo_plus` + `everywhere_plus` en RevenueCat y asociar productos
- [ ] Crear offerings "Pepinillo+" y "Everywhere/AI+" en RevenueCat
- [ ] Completar metadata en App Store Connect + configurar S2S Notifications
- [ ] Diseñar capability split backend + ledger IA
- [ ] Migrar Android de `premium` legacy a Everywhere/AI+
- [ ] Propagar entitlements a watchOS y Wear OS

---

## Referencias
- [[Parity Gaps|Brechas de paridad]]
- [[../00_DASHBOARD|Dashboard]]
