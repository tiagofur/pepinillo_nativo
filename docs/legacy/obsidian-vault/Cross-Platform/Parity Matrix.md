---
tags:
  - parity
  - cross-platform
  - pepinillo
aliases:
  - Parity Matrix
  - Matriz de Paridad
platform: cross-platform
type: reference
status: active
date: 2026-04-17
updated: 2026-04-27
---

# Parity Matrix - Pepinillo

> [!abstract] Resumen
> Esta matriz define la paridad funcional obligatoria entre iOS, Android, watchOS y Wear OS.

## Estados canonicos de referencia

- [[Estado Plataforma|Estado Cross-platform + Paridad]]
- [[../iOS/Estado Plataforma|Estado iOS + watchOS]]
- [[../Android/Estado Plataforma|Estado Android + Wear OS]]
- [[../Backend/Estado Plataforma|Estado Backend]]

## Leyenda

- ✅ Implementado
- 🚧 Parcial / en progreso
- 📋 Planificado
- N/A No aplica

## Gobernanza de paridad (obligatoria)

1. Cada feature de producto debe tener un comportamiento canónico, una evidencia y una fecha de ultima verificacion.
2. Si una plataforma no implementa algo por limitaciones del OS, debe documentarse en "Limitacion aceptada" con impacto de UX.
3. Ningun cambio de backend, billing o UX se considera cerrado sin actualizacion en esta matriz y en los estados por plataforma.
4. Los gaps por dependencias externas (App Store Connect, Play Console, RevenueCat) no cuentan como deuda de codigo, pero deben estar rastreados.

## Registro verificable de paridad (P0/P1)

| Feature ID | Comportamiento canonico | iOS | Android | watchOS | Wear OS | Limitacion aceptada | Owner | Ultima verificacion | Evidencia |
|---|---|:-:|:-:|:-:|:-:|---|---|---|---|
| NAV-001 | Shell phone `Focus / Plan / Dashboard / More` consistente por plataforma phone | ✅ | 🚧 | N/A | N/A | Ninguna | mobile | 2026-04-27 | [[../Android/Estado Plataforma]] |
| ACC-001 | Account hub (`More`) es owner de profile/settings/billing/export en phone | ✅ | 🚧 | N/A | N/A | Ninguna | mobile | 2026-04-27 | [[../_views/Parity Gaps]] |
| TASK-REORDER-001 | Reordenar tareas drag-and-drop en phone | ✅ | 🚧 | N/A | N/A | Ninguna | tasks | 2026-04-27 | [[../_views/Parity Gaps]] |
| BILL-001 | Entitlements `pepinillo_plus` y `everywhere_plus` propagados a watches | 🚧 | 🚧 | 🚧 | 🚧 | Depende de configuracion RevenueCat + companion sync | billing | 2026-04-27 | [[Runbooks/RevenueCat Guia Apple Review]] |
| REVIEWS-001 | Weekly/Monthly review disponible en phone y roadmap claro en watches | ✅ | ✅ | 📋 | 📋 | Superficie simplificada en reloj por limitacion de interaccion | analytics | 2026-04-27 | [[../_views/Parity Gaps]] |

## Navegacion y account IA

| Feature | iOS | Android | watchOS | Wear OS | Notas |
|---|:-:|:-:|:-:|:-:|---|
| Shell phone `Focus / Plan / Dashboard / More` | ✅ | 🚧 | N/A | N/A | Android migra desde `Focus / Tasks / Stats / Settings` |
| Naming top-level alineado al baseline iPhone | ✅ | 🚧 | N/A | N/A | `Plan`, `Dashboard` y `More` deben ser los labels canonicales en phone |
| `More` / Account hub como owner de profile + settings + billing | ✅ | 🚧 | N/A | N/A | Android ya abre profile/paywall/settings desde `More`, pero todavia faltan cierres de parity |
| Profile entry point desde account hub | ✅ | 🚧 | N/A | N/A | Android antes lo colgaba de Focus; la fase actual lo reordena |
| Help / About accesibles desde account area | ✅ | 🚧 | N/A | N/A | Android los expone desde `More`, con consolidacion de contenido pendiente |
| Export accesible desde account area | ✅ | 📋 | N/A | N/A | Falta surface Android equivalente |

## Core product

| Feature | iOS | Android | watchOS | Wear OS | Notas |
|---|:-:|:-:|:-:|:-:|---|
| Focus Engine base | ✅ | ✅ | ✅ | ✅ | 4 modos activos |
| Pomodoro | ✅ | ✅ | ✅ | ✅ | |
| Flowtime | ✅ | ✅ | ✅ | ✅ | |
| TimeBlock | ✅ | ✅ | ✅ | ✅ | |
| Stopwatch | ✅ | ✅ | ✅ | ✅ | |
| Session journaling | ✅ | ✅ | 🚧 | 🚧 | UX watch simplificada |
| Task linking en session | ✅ | ✅ | 🚧 | 🚧 | |

## Tasks y planificacion

| Feature | iOS | Android | watchOS | Wear OS | Notas |
|---|:-:|:-:|:-:|:-:|---|
| CRUD tareas | ✅ | ✅ | ✅ | ✅ | |
| Subtareas | ✅ | ✅ | 🚧 | 🚧 | |
| Recurrencia | ✅ | ✅ | 📋 | 📋 | |
| Energia (deep/shallow/admin) | ✅ | ✅ | 📋 | 📋 | |
| Reordenar (drag) | ✅ | 🚧 | N/A | N/A | |

## Ecosystem y surface area

| Feature | iOS | Android | watchOS | Wear OS | Notas |
|---|:-:|:-:|:-:|:-:|---|
| Home widgets / Glance | ✅ | ✅ | ✅ | ✅ | Smart Stack / Tiles |
| Lock screen widget | ✅ | ✅ | N/A | N/A | |
| Live Activity / notif persistente | ✅ | ✅ | N/A | N/A | Mecanismo distinto, resultado igual |
| Voice assistant | ✅ Siri | ✅ Assistant | N/A | N/A | |
| Health integration | ✅ Apple Health | ✅ Health Connect | N/A | N/A | |

## Analytics y monetizacion

| Feature | iOS | Android | watchOS | Wear OS | Notas |
|---|:-:|:-:|:-:|:-:|---|
| Dashboard diario | ✅ | ✅ | 🚧 | 🚧 | |
| Weekly review | ✅ | ✅ | 📋 | 📋 | |
| Monthly review | ✅ | ✅ | 📋 | 📋 | |
| **Pepinillo+** (premium local, compra unica) | 📋 | N/A | 📋 | N/A | rollout Apple-first |
| **Everywhere/AI+** (sync + IA, suscripcion) | 📋 | 📋 | 🚧 | 🚧 | suscripcion recurrente |
| Capability-based gating | 📋 | 📋 | 📋 | 📋 | reemplaza `pro` / `premium` legacy |
| Paywall / entitlement propagation | ✅ legacy | ✅ legacy | 🚧 | 🚧 | companion surfaces todavia parciales |

## Regla de trabajo

> [!warning] No opcional
> Todo bug fix o feature en una plataforma obliga revisar y ajustar su equivalente en las otras plataformas impactadas.

## Referencias

- [[../00_DASHBOARD|Dashboard]]
- [[../iOS/iOS MOC|iOS MOC]]
- [[../Android/Android MOC|Android MOC]]
- [[../Backend/Backend MOC|Backend MOC]]
- [[Estado Plataforma|Estado Cross-platform + Paridad]]
