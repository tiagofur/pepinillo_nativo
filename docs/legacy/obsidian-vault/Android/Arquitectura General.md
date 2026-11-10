---
tags:
  - android
  - arquitectura
  - compose
aliases:
  - Android Arquitectura
platform: android
type: architecture
status: active
date: 2026-04-17
updated: 2026-04-21
---

# Android - Arquitectura General

> [!abstract] Resumen
> Android usa Kotlin + Compose con capas limpias para foco, tareas, sync y billing, incluyendo extension nativa a Wear OS.

## Stack

| Capa | Tecnologia |
|---|---|
| UI | Jetpack Compose |
| Estado | ViewModel + StateFlow |
| Persistencia local | Room + DataStore |
| Networking | Ktor client |
| Ejecucion en background | Foreground Service + WorkManager |
| Integraciones | Health Connect, App Actions, Data Layer (Wear) |

## Modulos funcionales

- [[Modulo Focus Engine]]
- [[Modulo Tasks]]
- [[Widgets & Wear OS]]

## Monetizacion y sync

| Capability / oferta | Regla |
|---|---|
| Oferta paga Android (go-to-market actual) | `Everywhere/AI+ Monthly` o `Everywhere/AI+ Annual` durante el rollout Apple-first |
| Premium local Android (runtime) | habilitado para usuarios pagos reconocidos por capabilities/entitlements |
| Backend sync | solo con `Everywhere/AI+` |
| Wear OS | hereda estado desde Android companion |
| Pepinillo+ (comercial) | no se comercializa en Android / Wear OS |
| Runtime actual | conviven paths legacy (`premium`/`pro`) y canonicos (`pepinillo_plus`/`everywhere_plus`) en proceso de convergencia |

- Baseline de paridad funcional: iOS/watchOS define comportamiento de negocio; Android/Wear igualan capacidades, no UI.
- Referencia canonica: [[../iOS/Estado Plataforma|Estado iOS + watchOS]].

## Shell phone y stream de paridad

| Surface | Estado de la fase 2026-04-21 |
|---|---|
| Bottom nav phone | `Focus` · `Plan` · `Dashboard` · `More` implementado; pendiente cierre de ownership y validacion final en device |
| Focus | sigue siendo el hub de sesion; account shortcuts deben apuntar a `More`, no a `Profile` como owner principal |
| Plan | reutiliza el engine de tareas existente, pero adopta naming y rol equivalentes a iOS |
| Dashboard | mantiene analytics, calendar, reviews y AI report como flows secundarios |
| More | nuevo owner funcional de profile, subscription/paywall, settings, app setup, help/about y estado signed-in/guest |

- `Settings` deja de ser destino top-level y pasa a ser una surface secundaria abierta desde `More`.
- `Profile` sigue existiendo como pantalla dedicada, pero su entry point canonical en phone debe salir de `More`.
- `Help & Support` y `About` entran primero como accesos desde `More`; las surfaces dedicadas pueden seguir en una etapa posterior si el contenido actual de `Settings` no alcanza.
- `Export` sigue siendo una brecha abierta de parity y debe quedar rastreado en la matriz y en `Parity Gaps`.

## Impacto Wear OS

- No se busca bottom nav parity en reloj; el impacto de esta fase en Wear OS es de ownership companion, gating y documentacion.
- Todo cambio de account/profile/billing en phone Android debe revisar si necesita propagacion explicita al companion Wear.
- El companion debe reflejar entitlement/capabilities de phone en vistas, tiles y complications para mantener paridad funcional.

## Principios

- Motor de foco unificado por estrategia (4 modos).
- Foreground service para sesiones resilientes.
- Paridad funcional obligatoria con iOS para features P0.

## Relacion con backend

- Auth y sync sobre API Go.
- Batch sync y reconciliacion por timestamps.
- Enforcement de `Everywhere` en app y server, con backend como autoridad final para sync e IA.

Ver tambien: [[../Backend/Arquitectura General|Backend Arquitectura]] · [[../Cross-Platform/Monetizacion y Entitlements|Monetizacion y Entitlements]]

## Hoja de ruta de paridad

- Plan detallado por fases: [[Roadmap Paridad Funcional con iOS]].
