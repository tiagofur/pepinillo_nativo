---
tags:
  - backend
  - auth
  - billing
aliases:
  - Auth & Billing
platform: backend
type: module
status: active
date: 2026-04-17
updated: 2026-04-20
---

# Backend - Autenticacion & Suscripciones

> [!abstract] Resumen
> Este modulo controla identidad, sesiones y las capacidades comerciales que reemplazan el PRO legacy para garantizar reglas consistentes en todas las plataformas.

## Flujo de autenticacion

```
Nuevo usuario:
  POST /api/v1/auth/register → { email, password }
  → 201: { user, accessToken, refreshToken }

Login:
  POST /api/v1/auth/login → { email, password }
  → 200: { accessToken, refreshToken }

Sign in with Apple (iOS):
  POST /api/v1/auth/apple → { idToken, nonce }
  → 200: { accessToken, refreshToken, user }
  → 401: invalid_oauth_token (token inválido o expirado)
  → 409: email ya registrado con otro proveedor

Sign in with Google (Android):
  POST /api/v1/auth/google → { idToken }
  → mismos códigos que Apple

Refresh:
  POST /api/v1/auth/refresh → { refreshToken }
  → 200: { accessToken, refreshToken }
  → 401: token expirado/inválido

Logout:
  POST /api/v1/auth/logout (requiere Bearer token)
  → 204
```

> [!warning] Almacenamiento en iOS
> `accessToken` → Keychain (no UserDefaults).
> `refreshToken` → Keychain. Renovar silenciosamente al recibir 401 en cualquier endpoint.

## Tokens JWT

| Campo | Valor |
|---|---|
| Header | `Authorization: Bearer <accessToken>` |
| Duración access | Corta (configurada en backend env `JWT_EXPIRY`) |
| Duración refresh | Larga (configurable, almacenado en Redis) |
| Invalidación | `POST /api/v1/auth/logout` borra el refresh de Redis |

## Suscripciones — Monetizacion v2

| Key | Valor |
|---|---|
| SDK iOS (público) | `appl_xnChlVXXtUFhusIfJyNrNDcMGLj` |
| Backend secret | `sk_namFzNibPWRnKGIOqmwHfPVQrbfyZ` (env `REVENUECAT_SECRET_KEY`) |
| Runtime legacy | Entitlement `pro` en iOS / `premium` en Android |
| Capabilities target | `local_premium`, `apple_cloud_sync`, `backend_sync`, `ai_credits_monthly` |

### Catalogo comercial canonico

| Oferta | Producto target | Precio | Cobertura |
|---|---|---|---|
| Pepinillo+ | `com.pepinillo.app.pro.lifetime` | $19.99 / $9.99 LATAM | premium local Apple + iCloud + Apple Intelligence |
| Everywhere/AI+ Monthly | `com.pepinillo.app.pro.monthly` | $4.99 / $2.49 LATAM | backend sync + creditos IA |
| Everywhere/AI+ Annual | `com.pepinillo.app.pro.annual` | $34.99 / $17.99 LATAM | backend sync + creditos IA |

> [!warning] Runtime actual
> El runtime todavia usa SKUs legacy `com.pepinillo.app.pro.*` y un unico flag `pro` / `premium`.
> La migracion a los offers canonicos anteriores sigue pendiente.

### Endpoints de billing

```
POST /api/v1/billing/verify
Body: { receiptData: "<base64>", productId: "com.pepinillo.app.pro.monthly" }
→ 200: { isValid: true, entitlement: "pro", expiresAt: "..." }

POST /api/v1/webhooks/revenuecat   (solo backend, no llamar desde cliente)
```

> [!info] Evolucion esperada
> `billing/verify` sigue siendo el endpoint autoritativo, pero backend debe resolver `source product -> capabilities -> saldo IA`.

### Fuentes de verdad

| Fuente | Rol |
|---|---|
| RevenueCat / stores | Estado del producto comprado |
| Backend | Resolucion de capabilities, enforcement y saldo IA |
| Apps cliente | UX de paywall, gating local y surfaces companion |

## Regla de enforcement

1. Cliente consulta capabilities y adapta UI.
2. Backend valida capability requerida para operaciones protegidas.
3. `apple_cloud_sync` habilita iCloud local; `backend_sync` habilita sync por API.
4. Creditos IA se descuentan server-side.
5. Si hay divergencia, backend prevalece.

## Códigos de error relevantes

| Código HTTP | Error string | Causa |
|---|---|---|
| 400 | `invalid_preference_key` | Key vacía en upsert de preferencias |
| 401 | `invalid_oauth_token` | Token Apple/Google inválido o expirado |
| 409 | `email_already_exists` | Intento de registro con email ya usado |

## Checklist de paridad

- iOS y Android deben converger del naming legacy `pro` / `premium` a capabilities compartidas.
- watchOS y Wear OS deben respetar `Pepinillo+` / `Everywhere/AI+` recibido desde companion app.
- Cambios de pricing se actualizan aquí, en PRD y en configuraciones de stores.

Ver tambien: [[../Cross-Platform/Monetizacion y Entitlements|Monetizacion y Entitlements]]
