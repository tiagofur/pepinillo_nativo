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
updated: 2026-04-17
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
| Android | Feature gating completo (analytics, widgets) | [[../Android/Arquitectura General]] |
| Android | Paywall UI completa | [[../Backend/Autenticacion & Suscripciones]] |
| iOS | Price update RevenueCat $3.99 / $24.99 | [[../iOS/Arquitectura General]] |
| iOS + Android | Stores listing (screenshots, ASO, descripciones) | — |

---

## Backlog próximo sprint

> Reemplazá esta sección al iniciar un sprint nuevo usando `[[_templates/Template - Sprint]]`.

- [ ] Cerrar gating PRO Android
- [ ] Completar paywall UI Android  
- [ ] Price update RevenueCat (iOS + Android)
- [ ] CI/CD básico Android (GitHub Actions lint + tests)

---

## Referencias
- [[Parity Gaps|Brechas de paridad]]
- [[../00_DASHBOARD|Dashboard]]
