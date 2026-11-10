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
updated: 2026-04-27
---

# 🔀 Parity Gaps — Brechas Cross-Platform

> [!tip] Requiere el plugin **Dataview** para las queries automáticas.

---

## Brechas conocidas (hoy)

> [!info] Criterio de lectura
> Esta vista separa bloqueos por configuracion externa (stores y billing) de gaps de implementacion. Ambos se trackean, pero no tienen el mismo tipo de riesgo.

### Bloqueos externos (no-codigo)

> [!warning] Monetizacion v3.1 — codigo iOS alineado, config externa pendiente
> - ✅ iOS codigo: `Pepinillo+` / `Everywhere/AI+` — entitlements, paywall, storekit, mocks
> - ⬜ RevenueCat: claves API revocadas, entitlements/offerings legacy pendientes
> - ⬜ App Store Connect: metadata y review info de productos pendientes

### Gaps de implementacion (codigo / arquitectura)

> [!warning] Android / backend siguen con modelo legacy `pro` / `premium`
> - 🚧 Migracion a capability-based gating pendiente en runtime y server enforcement

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

> [!warning] Android shell phone todavia no cierra parity completa con iPhone
> - 🚧 bottom nav y naming migrando a `Focus / Plan / Dashboard / More`
> - ⬜ falta validar back stack, ownership final y consistencia guest/signed-in en device

> [!warning] Android More / account hub sigue parcial
> - 🚧 `More` ya absorbe profile, paywall, settings y auth entry points
> - ⬜ faltan parity completa de Help/Support, About y Export como surfaces Android equivalentes

> [!warning] Profile parity iOS ↔ Android necesita cierre despues del shell reset
> - ✅ iOS: More/Profile ya refleja estado Apple-local y edicion manual local-first
> - 🚧 Android: revisar Profile/Edit Profile contra ese baseline y cerrar diferencias de surface

> [!warning] Wear OS impact por cambios de account ownership
> - ⬜ documentar si profile/billing/gating necesitan propagacion explicita desde el companion Android

> [!warning] Feature gating en watchOS / Wear OS
> - 🚧 Estado de Pepinillo+ / Everywhere/AI+ no propagado a watch surfaces

---

## Pendientes por resolver (checklist operativo)

### 🍎 iOS — pendientes
- [ ] Crear entitlements `pepinillo_plus` + `everywhere_plus` y offerings en RevenueCat
- [ ] Completar metadata de productos en App Store Connect (nombres + precios)
- [ ] Migrar del flag `pro` a capability split en cliente iOS
- [ ] Xcode setup (no-code): App Group, CloudKit, StoreKit config
- [ ] iPad layouts (NavigationSplitView)
- [ ] macOS target

### 🤖 Android — pendientes
- [ ] Validar en device la shell `Focus / Plan / Dashboard / More`
- [ ] Completar `More` como owner canonical de Profile, Subscription, Settings, Help/Support, About y Sign out
- [ ] Resolver `Export` como surface Android equivalente dentro de `More`
- [ ] Revisar `Profile` / `Edit Profile` Android contra el baseline iOS actual
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
- [ ] Propagacion de Pepinillo+ / Everywhere/AI+ desde iPhone
- [ ] Session journaling UX simplificada
- [ ] Task linking en sesión
- [ ] Energy levels UI

### ⌚ Wear OS — pendientes
- [ ] Revisar impacto de shell/account parity Android en ownership de profile y billing del companion
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
- [[../Cross-Platform/Estado Plataforma|Estado Cross-platform + Paridad]]
