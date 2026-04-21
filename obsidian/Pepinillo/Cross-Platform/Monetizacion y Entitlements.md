---
tags:
  - monetization
  - billing
  - entitlements
  - cross-platform
aliases:
  - Monetizacion v2
  - Monetization Strategy
platform: cross-platform
type: module
status: active
date: 2026-04-21
updated: 2026-04-21
---

# 🌐 Cross-Platform — Monetizacion y Entitlements

> [!abstract] Resumen
> Pepinillo separa premium local de Apple, sync por backend y creditos IA para que pricing, costo y enforcement hablen el mismo idioma.

## Snapshot ejecutivo

| Capa | Oferta | Tipo | Cubre | No cubre |
|---|---|---|---|---|
| 1 | Free | Gratis | foco base, tareas base, 7 dias de analytics, 1 widget | subtareas, recurrencia, premium local, backend sync, creditos IA |
| 2 | Apple Unlock | Compra unica | premium local Apple, iCloud, widgets premium, watchOS, analytics largos, IA local | backend sync, creditos IA mensuales |
| 3 | Pepinillo Everywhere | Suscripcion mensual o anual | backend sync, restore multi-dispositivo, creditos IA, y en Apple incluye Apple Unlock | no tiene lifetime |

## Vocabulario canonico

| Termino | Significado | Nota |
|---|---|---|
| `Free` | Core offline usable | Debe formar habito antes de monetizar |
| `Apple Unlock` | Premium local Apple | Compra unica |
| `Everywhere` | Sync + IA recurrente | Suscripcion mensual/anual |
| `Local Intelligence` | IA on-device o por templates | No consume creditos |
| `Pepinillo AI Credits` | Creditos de producto para IA cloud | Se resetean por ciclo |
| `pro` / `premium` | Naming legacy de runtime | Debe migrar a capacidades |

## Matriz de valor

| Feature | Free | Apple Unlock | Everywhere |
|---|---|---|---|
| Pomodoro + Stopwatch | ✅ | ✅ | ✅ |
| Flowtime + Time Block | ⬜ | ✅ | ✅ |
| Subtareas + recurrencia | ⬜ | ✅ | ✅ |
| Analytics 30D / 1Y + reviews | ⬜ | ✅ | ✅ |
| IA local / templates | ⬜ | ✅ | ✅ |
| iCloud / CloudKit | ⬜ | ✅ | ✅ |
| Backend sync | ⬜ | ⬜ | ✅ |
| Creditos IA cloud | ⬜ | ⬜ | ✅ |
| watchOS premium | ⬜ | ✅ | ✅ |
| Wear OS premium | ⬜ | rollout | ✅ |

> [!warning] Promesa comercial
> `Everywhere` significa dispositivos soportados de verdad. No vender Windows, Web ni Linux hasta que existan clientes reales o una fecha comprometible.

## Reglas de producto

1. `Everywhere` es superconjunto de `Apple Unlock` en plataformas Apple.
2. El lifetime legacy se grandfather a `Apple Unlock`, no a sync recurrente ni a creditos IA perpetuos.
3. La IA local no consume creditos; la IA cloud siempre se descuenta server-side.
4. watchOS y Wear OS heredan entitlement desde la companion app.
5. Android mantiene `Everywhere` como unica oferta paga durante el rollout iOS-first.

## Fases de rollout

| Fase | Objetivo | Resultado |
|---|---|---|
| 0 | Alinear docs y naming | PRD + Obsidian + copy del paywall consistentes |
| 1 | iOS/watchOS Apple-first | Apple Unlock + Everywhere en Apple |
| 2 | Backend capability split | `local_premium`, `apple_cloud_sync`, `backend_sync`, `ai_credits_monthly` |
| 3 | Android/Wear migration | salida de SKUs `pro.*` y paso a Everywhere |
| 4 | Expansion comercial | sumar macOS/web/desktop solo cuando existan |

## Implicancias tecnicas

- El backend deja de pensar en un solo `pro` boolean y pasa a capacidades.
- RevenueCat sigue siendo entrada de eventos, pero el backend resuelve enforcement final.
- iCloud en Apple ya no se vende como sync general; se vende como continuidad nativa Apple.
- La IA con creditos requiere ledger, fecha de reset y reglas de decremento server-side.
- Las pantallas de watchOS/Wear OS necesitan propagacion de capability split, no solo un flag legacy.

## Checklist operativo

- [ ] Crear offers `Apple Unlock`, `Everywhere Monthly` y `Everywhere Annual` en RevenueCat / StoreKit.
- [ ] Migrar SKUs legacy `com.pepinillo.app.pro.*`.
- [ ] Diseñar y persistir capability matrix en backend.
- [ ] Agregar ledger de creditos IA y reset mensual.
- [ ] Separar gating local Apple de gating backend sync.
- [ ] Ajustar propagacion de entitlement a watchOS y Wear OS.

## Referencias

- [[../../PRD/04_MONETIZATION|PRD Monetization]]
- [[../Backend/Autenticacion & Suscripciones|Backend - Auth & Billing]]
- [[../iOS/Arquitectura General|iOS Arquitectura]]
- [[Parity Matrix|Parity Matrix]]
