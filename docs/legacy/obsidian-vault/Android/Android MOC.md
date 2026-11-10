---
tags:
  - android
  - moc
  - navegacion
aliases:
  - Android MOC
  - Android Hub
platform: android
type: moc
status: active
date: 2026-04-17
updated: 2026-07-24
---

# 🤖 Android — Mapa de Contenido

> [!info] Plataforma
> **Stack**: Kotlin, Jetpack Compose, Hilt, Room, WorkManager
> **Targets**: Android phone + Wear OS
> **Estado**: Desarrollo activo con paridad funcional en curso contra baseline iOS

---

## Infraestructura

| Area | Documento |
|------|-----------|
| Capas y decisiones arquitectonicas | [[Arquitectura General]] |
| Estado operativo Android/Wear OS | [[Estado Plataforma]] |
| Roadmap de paridad funcional | [[Roadmap Paridad Funcional con iOS]] |
| Shell phone + stream More parity | [[Arquitectura General#Shell phone y stream de paridad|Arquitectura General]] |
| Integracion con backend y sync | [[../Backend/Arquitectura General|Backend Arquitectura]] |
| Monetizacion y entitlements | [[../Cross-Platform/Monetizacion y Entitlements|Monetizacion y Entitlements]] |
| Contrato de paridad | [[../Cross-Platform/Parity Matrix|Parity Matrix]] |
| Baseline iOS de referencia | [[../iOS/Estado Plataforma|Estado iOS + watchOS]] |

## Modulos clave

| Modulo | Documento |
|--------|-----------|
| Motor de foco (Pomodoro/Flowtime/TimeBlock/Stopwatch) | [[Modulo Focus Engine]] |
| Sistema de tareas integrado | [[Modulo Tasks]] |
| Widgets, notificacion persistente y Wear | [[Widgets & Wear OS]] |

## Diseño & UX

| Area | Documento |
|------|-----------|
| Material 3 Expressive — plan de migración (8 sprints) | [[Diseño UI-UX Material3 Expressive]] |
| Judgment Day UI/UX + funcionalidad (2026-07-24) + next steps | [[Judgment Day Android UI-UX 2026-07-24]] |

## Calidad

| Area | Documento |
|------|-----------|
| Estado global de producto | [[../00_DASHBOARD|Dashboard]] |
| Fuente de alcance funcional | [[../PRD/README|PRD Index]] |
| Decision de rollout Apple-first | [[../Cross-Platform/ADR-001 - Monetizacion Apple First|ADR-001]] |
| Audit produccion Android | [[Audit Produccion Android]] |
| JD findings → issues #501–#527 | [[Judgment Day Android UI-UX 2026-07-24#7. Issue map (creados 2026-07-24)|Issue map JD]] |
