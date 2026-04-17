---
tags:
  - view
  - parity
  - gaps
aliases:
  - Parity Gaps
  - Brechas de Paridad
platform: cross-platform
type: view
status: active
date: 2026-04-17
updated: 2026-04-17
---

# 🔀 Parity Gaps — Brechas Cross-Platform

> [!tip] Requiere el plugin **Dataview** para las queries automáticas.

---

## Brechas conocidas (hoy)

> [!warning] Drag-to-reorder en tareas
> - ✅ iOS: implementado
> - 🚧 Android: pendiente

> [!warning] Energy batching UI
> - ✅ Android: implementado
> - ⬜ iOS: no implementado

> [!warning] Session journaling en watches
> - ✅ iOS + Android
> - 🚧 watchOS + Wear OS: UI simplificada pendiente

> [!warning] Gating PRO completo en Android
> - ✅ iOS: analytics 30D/Year + temas + widgets
> - 🚧 Android: analytics y widgets sin gating

> [!warning] Feature gating en watchOS / Wear OS
> - 🚧 Estado de paywall no propagado a watch surfaces

---

## Pendientes por resolver (checklist operativo)

### 🍎 iOS — pendientes
- [ ] Feature gating: ya está pero revisar analytics widgets
- [ ] Xcode setup (no-code): App Group, CloudKit, StoreKit config
- [ ] Price update $3.99 / $24.99 / $49.99 en RevenueCat
- [ ] iPad layouts (NavigationSplitView)
- [ ] macOS target

### 🤖 Android — pendientes
- [ ] Feature gating completo: analytics, widgets, temas
- [ ] Paywall UI completa
- [ ] Firebase Analytics / Crashlytics (`google-services.json`)
- [ ] CI/CD pipeline (GitHub Actions)
- [ ] Play Store listing (screenshots, ASO)
- [ ] Release keystore
- [ ] Drag-to-reorder en TaskList
- [ ] OEM testing (Samsung, Pixel, Xiaomi, OnePlus)

### ⌚ watchOS — pendientes
- [ ] Session journaling UX simplificada
- [ ] Task linking en sesión
- [ ] Energy levels UI

### ⌚ Wear OS — pendientes
- [ ] Session journaling UX simplificada
- [ ] Task linking en sesión
- [ ] Feature gating sincronizado desde companion app

---

## Documentos de módulo en estado parcial

```dataview
TABLE WITHOUT ID
  file.link AS "Documento",
  platform AS "Plataforma",
  status AS "Estado"
FROM "Pepinillo"
WHERE status = "draft" OR status = "wip"
SORT platform ASC
```

---

## Referencias
- [[../Cross-Platform/Parity Matrix|Parity Matrix completa]]
- [[../00_DASHBOARD|Dashboard]]
