---
tags:
  - monetization
  - billing
  - entitlements
  - cross-platform
aliases:
  - Monetizacion v3
  - Monetization Strategy
platform: cross-platform
type: module
status: active
date: 2026-04-21
updated: 2026-04-22
---

# 🌐 Cross-Platform — Monetizacion y Entitlements

> [!abstract] Resumen
> Pepinillo separa premium local de Apple, sync por backend y creditos IA para que pricing, costo y enforcement hablen el mismo idioma.
>
> **Naming v3.1 (2026-04-22):** `Apple Unlock` → **`Pepinillo+`** · `Pepinillo Everywhere` → **`Everywhere/AI+`** · entitlements `pepinillo_plus` / `everywhere_plus`

## Snapshot ejecutivo

| Capa | Oferta | Tipo | Precio (global) | Cubre | No cubre |
|---|---|---|---|---|---|
| 1 | Free | Gratis | — | foco base, tareas base, 7 dias de analytics, 1 widget | subtareas, recurrencia, premium local, backend sync, creditos IA |
| 2 | **Pepinillo+** | Compra unica | **$19.99** | premium local Apple, iCloud, widgets premium, watchOS, analytics largos, Apple Intelligence | backend sync, creditos IA mensuales |
| 3 | **Everywhere/AI+** | Suscripcion mensual o anual | **$4.99/mes · $34.99/año** | backend sync, restore multi-dispositivo, creditos IA, y en Apple incluye Pepinillo+ | no tiene lifetime |

## Vocabulario canonico

| Termino | Significado | Nota |
|---|---|---|
| `Free` | Core offline usable | Debe formar habito antes de monetizar |
| `Pepinillo+` | Premium local Apple — compra unica | **No es una suscripcion.** Entitlement: `pepinillo_plus` |
| `Everywhere/AI+` | Sync + IA recurrente | Suscripcion mensual/anual. Entitlement: `everywhere_plus` |
| `Apple Intelligence` | IA on-device via Apple Foundation Models + template fallback | Incluida en Pepinillo+. No consume creditos |
| `AI+` (cloud) | IA cloud: Coach, Scheduling, Subtask Gen, Advanced Insights | Solo en Everywhere/AI+. Consume creditos mensuals |
| `Pepinillo AI Credits` | Creditos de producto para IA cloud (100/mes) | Se resetean por ciclo de facturacion |
| `pro` / `premium` | Naming legacy de runtime | Grandfathered: lifetime → `pepinillo_plus`, suscripcion → `everywhere_plus` |

## Matriz de valor

| Feature | Free | Pepinillo+ | Everywhere/AI+ |
|---|---|---|---|
| Pomodoro + Stopwatch | ✅ | ✅ | ✅ |
| Flowtime + Time Block | ⬜ | ✅ | ✅ |
| Subtareas + recurrencia | ⬜ | ✅ | ✅ |
| Analytics 30D / 1Y + reviews | ⬜ | ✅ | ✅ |
| Apple Intelligence (on-device AI) | ⬜ | ✅ | ✅ |
| iCloud / CloudKit | ⬜ | ✅ | ✅ |
| Backend sync | ⬜ | ⬜ | ✅ (Proximamente) |
| Creditos IA cloud (100/mes) | ⬜ | ⬜ | ✅ (Proximamente) |
| watchOS premium | ⬜ | ✅ | ✅ |
| Wear OS premium | ⬜ | rollout | ✅ |

> [!warning] Promesa comercial
> `Everywhere/AI+` significa dispositivos soportados de verdad. No vender Windows, Web ni Linux hasta que existan clientes reales. Las features marcadas "Proximamente" solo se muestran en el paywall con badge — no se promueven en otro lugar de la app.

## Reglas de producto

1. `Everywhere/AI+` es superconjunto de `Pepinillo+` en plataformas Apple.
2. El lifetime legacy se grandfather a `Pepinillo+`, no a sync recurrente ni a creditos IA perpetuos.
3. La IA local (Apple Intelligence) no consume creditos; la IA cloud siempre se descuenta server-side.
4. watchOS y Wear OS heredan entitlement desde la companion app.
5. Android mantiene `Everywhere/AI+` como unica oferta paga durante el rollout iOS-first.

## Entitlement IDs (RevenueCat)

| Entitlement | Productos asociados | Capacidades |
|---|---|---|
| `pepinillo_plus` | `com.pepinillo.app.pro.lifetime` | `localPremium`, `appleCloudSync`, `localAI`, `exportAccess` |
| `everywhere_plus` | `com.pepinillo.app.pro.monthly`, `com.pepinillo.app.pro.annual` | Todo `pepinillo_plus` + `backendSync`, `aiCreditsMonthly: 100`, `crossDeviceRestore` |
| `premium` (legacy) | — | Grandfathered → `pepinillo_plus` si lifetime, `everywhere_plus` si suscripcion |
| `pro` (legacy) | — | Mismo mapeo que `premium` |

## Fases de rollout

| Fase | Objetivo | Estado |
|---|---|---|
| 0 | Alinear docs y naming | ✅ Completado (v3.1 naming canonico) |
| 1 | iOS/watchOS Apple-first — Pepinillo+ como oferta primaria | 🔄 En progreso |
| 2 | Backend capability split (`local_premium`, `apple_cloud_sync`, `backend_sync`, `ai_credits_monthly`) | ⬜ Pendiente |
| 3 | Android/Wear migration — salida de SKUs `pro.*` y paso a Everywhere/AI+ | ⬜ Pendiente |
| 4 | Expansion comercial — macOS/web/desktop solo cuando existan | ⬜ Futuro |

## Checklist operativo (externo — RevenueCat + App Store)

- [ ] **[BLOCKER]** Actualizar claves API revocadas en RevenueCat (App Store Connect API: `22YZT9D55J` · In-App Purchase: `Z95PS2LD73`)
- [ ] Completar metadata en App Store Connect para los 3 productos + renombrar a "Pepinillo+" / "Everywhere/AI+ Monthly" / "Everywhere/AI+ Annual"
- [ ] Crear entitlements `pepinillo_plus` + `everywhere_plus` en RevenueCat y asociar productos
- [ ] Crear offerings nuevos en RevenueCat con naming canonico
- [ ] Configurar S2S Notifications webhook en App Store Connect
- [ ] Enviar nueva version iOS cuando la app este lista
- [ ] (Opcional) Limpiar producto Android huerfano `pepinillo_premium:pepinillo-month`

## Checklist operativo (codigo — implementado)

- [x] `SubscriptionClient.swift` usa entitlements `pepinillo_plus` / `everywhere_plus`
- [x] `UserCapabilities.swift` modelo granular de capacidades
- [x] Legacy fallback para `premium` / `pro`
- [x] `PaywallView.swift` diseno de dos capas + badge "NOT a subscription" + Apple Intelligence como hero
- [x] `Pepinillo.storekit` renombrado + precios $19.99 / $4.99 / $34.99 para simulador
- [x] `AppConfig.aiInsightsEnabled = true`

## Implicancias tecnicas

- El backend deja de pensar en un solo `pro` boolean y pasa a capacidades.
- RevenueCat sigue siendo entrada de eventos, pero el backend resuelve enforcement final.
- iCloud en Apple ya no se vende como sync general; se vende como continuidad nativa Apple.
- La IA con creditos requiere ledger, fecha de reset y reglas de decremento server-side.
- Las pantallas de watchOS/Wear OS necesitan propagacion de capability split, no solo un flag legacy.

## Referencias

- [[../../PRD/04_MONETIZATION|PRD Monetization]]
- [[../Backend/Autenticacion & Suscripciones|Backend - Auth & Billing]]
- [[../iOS/Arquitectura General|iOS Arquitectura]]
- [[Parity Matrix|Parity Matrix]]
