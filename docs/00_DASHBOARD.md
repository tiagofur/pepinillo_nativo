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
updated: 2026-04-27
---

# 🎯 Pepinillo — Dashboard Ejecutivo

> [!tip] Punto de entrada diario
> Abri este archivo para ver en 30 segundos el estado de producto, paridad y bloqueantes.

**Ultima actualizacion:** 2026-04-27

## Salud del producto

> [!info] Estado general
> - iOS + watchOS: ver [[iOS/Estado Plataforma|estado operativo iOS/watchOS]]
> - Android + Wear OS: ver [[Android/Estado Plataforma|estado operativo Android/Wear OS]]
> - Backend Go: ver [[Backend/Estado Plataforma|estado operativo backend]]
> - Cross-platform y paridad: ver [[Cross-Platform/Estado Plataforma|estado de paridad]]

> [!success] Enfoque de producto
> Pepinillo se posiciona como plataforma de deep work con 4 modos de foco, tareas integradas y analytics por modo (no solo Pomodoro).

> [!warning] Bloqueantes externos esperables
> - Dashboards de stores/suscripciones (App Store Connect, Play Console, RevenueCat)
> - Deploy/ops segun ventana de release
> - Migracion comercial v3.1 (Pepinillo+ + Everywhere/AI+) — codigo iOS alineado; config externa en RevenueCat + App Store Connect pendiente

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

## Estados canonicos por plataforma

- [[iOS/Estado Plataforma|iOS + watchOS]]
- [[Android/Estado Plataforma|Android + Wear OS]]
- [[Backend/Estado Plataforma|Backend]]
- [[Cross-Platform/Estado Plataforma|Cross-platform + paridad]]

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
- [[Cross-Platform/Cross-Platform MOC|🌐 Cross-Platform MOC]]
- [[Backend/API Contract iOS|🔗 API Contract iOS]]
- [[Cross-Platform/Design System & Soundscapes|🎨 Design System]]
- [[Cross-Platform/Parity Matrix|🔀 Parity Matrix]]

### 🗂️ Templates
- [[_templates/README|Templates disponibles]]

### 📖 Estrategia
- [[PRD/README|PRD Index]]
- [[Cross-Platform/Monetizacion y Entitlements|💸 Monetizacion y Entitlements]]
- [[Cross-Platform/ADR-001 - Monetizacion Apple First|📋 ADR-001 Apple First]]

### 🧭 Runbooks y auditorias
- [[Cross-Platform/Runbooks/RevenueCat Guia Apple Review|RevenueCat + App Store review checklist]]
- [[Cross-Platform/Runbooks/RevenueCat Setup Guide|RevenueCat setup paso a paso]]
- [[Cross-Platform/Audits/Monetization Audit - Apr 21 2026|Monetization audit histórico]]
- [[iOS/Audit App Store iOS|iOS audit histórico]]
- [[Android/Audit Produccion Android|Android audit histórico]]
