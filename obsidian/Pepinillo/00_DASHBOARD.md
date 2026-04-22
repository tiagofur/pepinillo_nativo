---
tags:
  - dashboard
  - pepinillo
  - daily-progress
aliases:
  - Dashboard
  - Hub
  - Inicio
platform: all
type: dashboard
status: active
date: 2026-04-17
updated: 2026-04-21
---

# 🎯 Pepinillo — Dashboard Ejecutivo

> [!tip] Punto de entrada diario
> Abri este archivo para ver en 30 segundos el estado de producto, paridad y bloqueantes.

**Ultima actualizacion:** 2026-04-21

## Salud del producto

> [!info] Estado general
> - iOS + watchOS: en desarrollo activo con build local OK
> - Android + Wear OS: en desarrollo activo con build local OK
> - Backend Go: ✅ Funcional y testeado — hardening listo — listo para deploy a VPS

> [!success] Enfoque de producto
> Pepinillo se posiciona como plataforma de deep work con 4 modos de foco, tareas integradas y analytics por modo (no solo Pomodoro).

> [!warning] Bloqueantes externos esperables
> - Dashboards de stores/suscripciones (App Store Connect, Play Console, RevenueCat)
> - Deploy/ops segun ventana de release
> - Migracion comercial v2 (Apple Unlock + Everywhere) todavia pendiente en runtime

## Progreso por streams

| Stream | Objetivo | Progreso | Estado |
|---|---|---|---|
| Focus Engine | 4 modos con paridad funcional | `███████████████░░░░░` 75% | 🚧 |
| Tasks | CRUD + subtareas + recurrencia | `████████████████░░░░` 80% | 🚧 |
| Analytics | Semanal/mensual + inteligencia | `█████████████░░░░░░░` 65% | 🚧 |
| Ecosystem | Widgets + watches + asistentes | `██████████████░░░░░░` 70% | 🚧 |
| Billing | Monetizacion v2 + capability split | `██████████████░░░░░░` 70% | 🚧 |

## Matriz de paridad rapida

| Area | iOS | Android | watchOS | Wear OS |
|---|:-:|:-:|:-:|:-:|
| Focus modes (4) | ✅ | ✅ | ✅ | ✅ |
| Tasks core | ✅ | ✅ | ✅ | ✅ |
| Widgets / Tiles | ✅ | ✅ | ✅ | ✅ |
| Voice assistant | ✅ | ✅ | N/A | N/A |
| Weekly/Monthly review | ✅ | ✅ | 📋 | 📋 |

Detalle vivo: [[Cross-Platform/Parity Matrix]]

## Siguientes 3 focos

1. Cerrar shell parity Android phone con `Focus / Plan / Dashboard / More` y ownership canonical de `More`.
2. Revisar `Profile` / `Edit Profile` Android contra el baseline actual de iOS More/Profile.
3. Diseñar capability split backend + creditos IA mensuales.

## Accesos rápidos

### 📌 Vistas operativas
- [[_views/Estado General|📊 Estado General]] — todos los docs por plataforma y tipo
- [[_views/Parity Gaps|⚠️ Parity Gaps]] — brechas conocidas y pendientes P0
- [[_views/Pendientes por Plataforma|✅ Pendientes]] — tareas abiertas por plataforma

### 🗺️ Mapas de contenido
- [[iOS/iOS MOC|🍎 iOS MOC]]
- [[Android/Android MOC|🤖 Android MOC]]
- [[Backend/Backend MOC|⚙️ Backend MOC]]
- [[Backend/API Contract iOS|🔗 API Contract iOS]]
- [[Cross-Platform/Design System & Soundscapes|🎨 Design System]]
- [[Cross-Platform/Parity Matrix|🔀 Parity Matrix]]

### 🗂️ Templates
- [[_templates/README|Templates disponibles]]

### 📖 Estrategia
- [[PRD/README|PRD Index]]
- [[Cross-Platform/Monetizacion y Entitlements|💸 Monetizacion y Entitlements]]
- [[Cross-Platform/ADR-001 - Monetizacion Apple First|📋 ADR-001 Apple First]]
