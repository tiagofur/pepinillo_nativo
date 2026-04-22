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
updated: 2026-04-21
---

# Parity Matrix - Pepinillo

> [!abstract] Resumen
> Esta matriz define la paridad funcional obligatoria entre iOS, Android, watchOS y Wear OS.

## Leyenda

- ✅ Implementado
- 🚧 Parcial / en progreso
- 📋 Planificado
- N/A No aplica

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
| Apple Unlock (premium local) | 📋 | N/A | 📋 | N/A | rollout Apple-first |
| Everywhere (sync + IA) | 📋 | 📋 | 🚧 | 🚧 | suscripcion recurrente |
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
