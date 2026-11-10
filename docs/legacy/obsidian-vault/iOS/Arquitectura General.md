---
tags:
  - ios
  - arquitectura
  - tca
aliases:
  - iOS Arquitectura
platform: ios
type: architecture
status: active
date: 2026-04-17
updated: 2026-04-27
---

# iOS - Arquitectura General

> [!abstract] Resumen
> iOS usa SwiftUI + TCA con clientes de dependencia para aislar foco, tareas, sync y billing con alta testabilidad.

## Stack

| Capa | Tecnologia |
|---|---|
| UI | SwiftUI |
| Estado | TCA 1.17+ |
| Persistencia local | SwiftData local en App Group (`PepinilloLocal.sqlite`) |
| Networking | URLSession + API client |
| Billing | RevenueCat SDK v5+ |
| Tiempo activo | ActivityKit / Live Activity |
| Integraciones | Siri App Intents, Apple Health, WatchConnectivity |
| Auth | Sign in with Apple, Google OAuth |

## Targets (5)

| Target | Bundle ID |
|---|---|
| App principal | `com.pepinillo.app` |
| WatchApp | `com.pepinillo.app.watch` |
| Widget | `com.pepinillo.app.widget` |
| Live Activity | `com.pepinillo.app.liveactivity` |
| Intents | `com.pepinillo.app.intents` |

**App Group:** `group.com.pepinillo.app`  
**CloudKit:** diferido para 1.1; no participa del launch path de 1.0

## Monetizacion y sync

| Capability | Regla |
|---|---|
| Premium local Apple | `Pepinillo+` o `Everywhere/AI+` habilitan features premium locales |
| iCloud / CloudKit | diferido hasta validar sync no bloqueante post-launch |
| Backend sync | solo con `Everywhere/AI+` |
| watchOS | hereda estado desde iPhone companion |
| Runtime actual | todavia usa un unico flag `pro`, pendiente capability split |

## Modulos funcionales

- [[Modulo Focus Engine]]
- [[Modulo Tasks]]
- [[Widgets & Live Activity]]

## Shell y ownership de account

| Surface | Estado actual iPhone |
|---|---|
| Bottom nav | `Focus` · `Plan` · `Dashboard` · `More` |
| Focus | sesion de foco, task linking, soundscapes, journal |
| Plan | lista y detalle de tareas, filtros, quick add, schedule |
| Dashboard | analytics, weekly/monthly review, calendar, AI report |
| More | auth, profile, subscription, settings, export, help/support, about |

- En iPhone, `More` es el owner funcional de account/admin; `Settings` no vive como tab propio.
- `Calendar`, `Weekly Review`, `Monthly Review` y `AI Report` son flows secundarios; no son tabs primarios.
- En regular width se usa split navigation; la shell de 4 tabs aplica al baseline phone.

## Perfil y auth Apple-local

- `More` y `Profile` leen estado de auth/profile desde el root app state, no desde flows aislados.
- Sign in with Apple solo puede aportar nombre y email cuando Apple decide compartirlos; no existe scope para fecha de nacimiento o foto.
- El runtime actual mergea identidad restaurada de Apple con el perfil cacheado para no perder nombre/email por datos locales incompletos.
- Edit Profile ya permite completar manualmente `name`, `email`, `birthDate` y `photo` en un flujo local-first compatible con la fase local-only de 1.0.
- El perfil visible desde `More` debe ser honesto sobre estas limitaciones y seguir siendo util sin requerir backend.

## Principios

- Un unico contrato de negocio para los 4 modos de foco.
- Efectos asincronos encapsulados en dependency clients.
- Paridad funcional obligatoria con Android para features P0.
- Swift 6 strict concurrency — todos los actores bien definidos.

## Integracion con backend

| Funcion | Endpoint | Notas |
|---|---|---|
| Auth JWT | `POST /api/v1/auth/login` | Tokens en Keychain |
| Sign in with Apple | `POST /api/v1/auth/apple` | Pasar `idToken` + `nonce` |
| Refresh token | `POST /api/v1/auth/refresh` | Interceptar 401, renovar silenciosamente |
| Sync inicial (dispositivo nuevo) | `POST /api/v1/sync/initial-upload` | Campo es `key`, NO `preferenceKey` |
| Sync incremental | `GET /api/v1/sync/full?cursor=` | Cursor = timestamp ISO8601 |
| Sync sesiones | `GET /api/v1/sync/sessions?cursor=` | Solo sesiones de foco |
| Preferencias | `POST /api/v1/preferences/upsert` | Campo `key`, nunca vacío |
| Billing verify | `POST /api/v1/billing/verify` | Después de compra App Store |
| Push tokens | `POST /api/v1/devices/register` | APNs token |
| WebSocket | `GET /ws` | Solo notificaciones (sync_required) |

> [!tip] Contrato completo
> Ver [[../Backend/API Contract iOS]] para payloads exactos, respuestas y tabla de errores.

> [!warning] URL base producción
> `https://api.ppn.creapolis.dev` — no hardcodear; usar config por environment.

Ver tambien: [[../Backend/Arquitectura General|Backend Arquitectura]] · [[../Backend/Autenticacion & Suscripciones|Auth & Billing]] · [[../Cross-Platform/Monetizacion y Entitlements|Monetizacion y Entitlements]]
