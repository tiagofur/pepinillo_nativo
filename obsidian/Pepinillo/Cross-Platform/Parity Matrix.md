---
tags:
  - parity
  - cross-platform
  - pepinillo
status: active
date: 2026-04-17
updated: 2026-04-17
---

# Parity Matrix - Pepinillo

> [!abstract] Resumen
> Esta matriz define la paridad funcional obligatoria entre iOS, Android, watchOS y Wear OS.

## Leyenda

- ✅ Implementado
- 🚧 Parcial / en progreso
- 📋 Planificado
- N/A No aplica

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
| Paywall / entitlement PRO | ✅ | ✅ | 🚧 | 🚧 | enforcement via backend |

## Regla de trabajo

> [!warning] No opcional
> Todo bug fix o feature en una plataforma obliga revisar y ajustar su equivalente en las otras plataformas impactadas.

## Referencias

- [[../00_DASHBOARD|Dashboard]]
- [[../iOS/iOS MOC|iOS MOC]]
- [[../Android/Android MOC|Android MOC]]
- [[../Backend/Backend MOC|Backend MOC]]
