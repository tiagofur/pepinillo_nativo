---
tags:
  - android
  - widgets
  - wearos
aliases:
  - Android Widgets
  - Wear OS
platform: android
type: module
status: active
date: 2026-04-17
updated: 2026-04-21
---

# Android - Widgets & Wear OS

> [!abstract] Resumen
> Superficies rapidas para arrancar/seguir sesiones sin abrir la app.

## Widgets phone

- Home widgets (Glance).
- Lock screen widget (segun version Android).
- Quick Settings tile para accion inmediata.

## Wear OS

- Tiles para foco y tareas.
- Complications en watch face.
- Sync con phone para estado y contexto.

## Monetizacion y entitlement

- Wear OS hereda entitlement desde Android phone.
- `Everywhere/AI+` es la unica oferta paga valida para Android + Wear OS durante el rollout actual.
- `Pepinillo+` no aplica a Wear OS.
- El capability split objetivo debe propagarse desde companion app a tiles, complications y vistas de stats.

## Checklist de calidad

- El timer en notificacion/tiles coincide con sesion real.
- Las acciones pause/resume/stop son confiables.
- Android/Wear mantienen coherencia de estado y entitlement.

## Baseline de paridad

- Referencia funcional cruzada: [[../iOS/Widgets & Live Activity|iOS Widgets & Live Activity]].
- La paridad se mide por capacidad equivalente (estado visible, acciones rapidas, contexto de tarea), no por implementacion visual.

## Roadmap asociado

- Cierre de propagacion de entitlement y hardening companion: [[Roadmap Paridad Funcional con iOS]].

Ver tambien: [[../Cross-Platform/Monetizacion y Entitlements|Monetizacion y Entitlements]]
