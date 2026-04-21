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
updated: 2026-04-21
---

# 🔀 Parity Gaps — Brechas Cross-Platform

> [!tip] Requiere el plugin **Dataview** para las queries automáticas.

---

## Brechas conocidas (hoy)

> [!warning] Monetizacion v2 todavia no llego al runtime
> - ✅ PRD + vault: alineados a Apple Unlock + Everywhere
> - 🚧 iOS / Android / backend: siguen con modelo legacy `pro` / `premium`

> [!warning] Backend sin capability split ni creditos IA
> - ⬜ `local_premium`, `apple_cloud_sync`, `backend_sync`, `ai_credits_monthly`
> - ⬜ ledger y reset mensual de creditos IA

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
> - 🚧 Estado de Apple Unlock / Everywhere no propagado a watch surfaces

---

## Pendientes por resolver (checklist operativo)

### 🍎 iOS — pendientes
- [ ] Crear productos Apple Unlock + Everywhere en RevenueCat / StoreKit
- [ ] Migrar del flag `pro` a capability split en cliente iOS
- [ ] Xcode setup (no-code): App Group, CloudKit, StoreKit config
- [ ] iPad layouts (NavigationSplitView)
- [ ] macOS target

### 🤖 Android — pendientes
- [ ] Migrar SKUs legacy `pro.*` a Everywhere
- [ ] Renombrar `premium` legacy a capabilities compartidas
- [ ] Feature gating completo: analytics, widgets, temas
- [ ] Paywall UI completa
- [ ] Firebase Analytics / Crashlytics (`google-services.json`)
- [ ] CI/CD pipeline (GitHub Actions)
- [ ] Play Store listing (screenshots, ASO)
- [ ] Release keystore
- [ ] Drag-to-reorder en TaskList
- [ ] OEM testing (Samsung, Pixel, Xiaomi, OnePlus)

### ⌚ watchOS — pendientes
- [ ] Propagacion de Apple Unlock / Everywhere desde iPhone
- [ ] Session journaling UX simplificada
- [ ] Task linking en sesión
- [ ] Energy levels UI

### ⌚ Wear OS — pendientes
- [ ] Propagacion de Everywhere desde Android companion
- [ ] Session journaling UX simplificada
- [ ] Task linking en sesión
- [ ] Feature gating sincronizado desde companion app

### ⚙️ Backend — pendientes
- [ ] Capability split comercial (`local_premium`, `apple_cloud_sync`, `backend_sync`, `ai_credits_monthly`)
- [ ] Ledger de creditos IA con reset mensual
- [ ] Migracion de source product legacy a catalogo v2

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
