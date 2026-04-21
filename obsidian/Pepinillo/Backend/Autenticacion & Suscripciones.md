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
> Este modulo controla identidad, sesiones y entitlement PRO para garantizar reglas consistentes en todas las plataformas.

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

## Suscripciones — RevenueCat

| Key | Valor |
|---|---|
| SDK iOS (público) | `appl_xnChlVXXtUFhusIfJyNrNDcMGLj` |
| Backend secret | `sk_namFzNibPWRnKGIOqmwHfPVQrbfyZ` (env `REVENUECAT_SECRET_KEY`) |
| Entitlement | `pro` |

### Product IDs (canónicos)

| Producto | ID | Precio |
|---|---|---|
| Mensual | `com.pepinillo.app.pro.monthly` | $3.99 / mes |
| Anual | `com.pepinillo.app.pro.annual` | $24.99 / año |
| Lifetime | `com.pepinillo.app.pro.lifetime` | $49.99 único |

> [!danger] IDs incorrectos en código viejo
> El prefijo viejo era `com.pepinillo.pro.*`. El correcto es `com.pepinillo.app.pro.*`.
> Cualquier referencia al prefijo viejo en el cliente iOS debe corregirse.

### Endpoints de billing

```
POST /api/v1/billing/verify
Body: { receiptData: "<base64>", productId: "com.pepinillo.app.pro.monthly" }
→ 200: { isValid: true, entitlement: "pro", expiresAt: "..." }

POST /api/v1/webhooks/revenuecat   (solo backend, no llamar desde cliente)
```

### Fuentes de verdad

| Fuente | Rol |
|---|---|
| RevenueCat | Estado de entitlement `pro` |
| Backend | Enforcement final por usuario |
| Apps cliente | UX de paywall y gating local |

## Regla de enforcement

1. Cliente consulta estado y adapta UI.
2. Backend valida entitlement para operaciones protegidas.
3. Si hay divergencia, backend prevalece.

## Códigos de error relevantes

| Código HTTP | Error string | Causa |
|---|---|---|
| 400 | `invalid_preference_key` | Key vacía en upsert de preferencias |
| 401 | `invalid_oauth_token` | Token Apple/Google inválido o expirado |
| 409 | `email_already_exists` | Intento de registro con email ya usado |

## Checklist de paridad

- iOS y Android deben mapear el mismo entitlement (`pro`).
- watchOS y Wear OS respetan gating recibido desde companion app.
- Cambios de pricing se actualizan aquí y en StoreKit config de Xcode.
