---
tags:
  - backend
  - ios
  - api
  - contrato
aliases:
  - API Contract
  - Contrato iOS
platform: ios
type: reference
status: active
date: 2026-04-20
updated: 2026-04-20
---

# Backend — Contrato API para iOS

> [!abstract] Resumen
> Referencia completa de todos los endpoints que el cliente iOS debe llamar, con payloads exactos, respuestas y códigos de error.

## URL base

| Entorno | URL |
|---|---|
| Producción | `https://api.ppn.creapolis.dev` |
| Local dev | `http://localhost:8080` |

## Autenticación (header)

Todos los endpoints marcados con 🔐 requieren:
```
Authorization: Bearer <accessToken>
```

---

## Auth

### Register
```
POST /api/v1/auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "securepassword"
}
```
**Respuesta 201:**
```json
{
  "user": { "id": "uuid", "email": "...", "name": "..." },
  "accessToken": "eyJ...",
  "refreshToken": "eyJ..."
}
```
**Errores:**
- `409` — `email_already_exists`
- `422` — `invalid_input`

---

### Login
```
POST /api/v1/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "securepassword"
}
```
**Respuesta 200:** igual que register
**Errores:**
- `401` — `invalid_credentials`

---

### Sign in with Apple 🍎
```
POST /api/v1/auth/apple
Content-Type: application/json

{
  "idToken": "<JWT de Apple>",
  "nonce": "<nonce generado en iOS>",
  "fullName": "Juan Pérez"    // opcional, solo en primer login
}
```
**Respuesta 200:** igual que login
**Errores:**
- `401` — `invalid_oauth_token` (token inválido/expirado)
- `409` — email ya registrado con otro proveedor

---

### Sign in with Google
```
POST /api/v1/auth/google
Content-Type: application/json

{
  "idToken": "<JWT de Google>"
}
```
**Respuesta 200:** igual que login
**Errores:** iguales a Apple

---

### Refresh Token
```
POST /api/v1/auth/refresh
Content-Type: application/json

{
  "refreshToken": "eyJ..."
}
```
**Respuesta 200:**
```json
{
  "accessToken": "eyJ...",
  "refreshToken": "eyJ..."
}
```
**Errores:**
- `401` — token expirado o inválido

> [!tip] Estrategia de renovación iOS
> Interceptar `401` en cualquier endpoint → renovar silenciosamente → reintentar la request original → si falla de nuevo, forzar logout.

---

### Logout 🔐
```
POST /api/v1/auth/logout
Authorization: Bearer <accessToken>
```
**Respuesta:** `204 No Content`

---

## Usuario

### Obtener perfil 🔐
```
GET /api/v1/users/me
```
**Respuesta 200:**
```json
{
  "id": "uuid",
  "email": "...",
  "name": "...",
  "isPro": true,
  "createdAt": "2026-04-01T00:00:00Z"
}
```

> [!info] Compatibilidad legacy
> `isPro` sigue siendo el flag expuesto hoy por compatibilidad. El target del rollout nuevo es devolver capabilities o account type mas expresivos.

### Actualizar perfil 🔐
```
PUT /api/v1/users/me
Content-Type: application/json

{
  "name": "Nuevo nombre"
}
```
**Respuesta 200:** usuario actualizado

---

## Tareas

### Listar tareas 🔐
```
GET /api/v1/tasks
```
**Respuesta 200:**
```json
{
  "tasks": [
    {
      "id": "uuid",
      "title": "Mi tarea",
      "description": "...",
      "completed": false,
      "energy": "high",
      "recurrence": null,
      "subtasks": [
        { "id": "uuid", "title": "subtarea", "completed": false }
      ],
      "createdAt": "...",
      "updatedAt": "..."
    }
  ]
}
```

### Crear tarea 🔐
```
POST /api/v1/tasks
Content-Type: application/json

{
  "title": "Mi tarea",
  "description": "Descripción opcional",
  "energy": "high",           // "high" | "medium" | "low"
  "recurrence": null          // o patrón de recurrencia
}
```
**Respuesta 201:** tarea creada

### Actualizar tarea 🔐
```
PUT /api/v1/tasks/:id
Content-Type: application/json

{
  "title": "Nuevo título",
  "completed": true
}
```
**Respuesta 200:** tarea actualizada

### Eliminar tarea 🔐
```
DELETE /api/v1/tasks/:id
```
**Respuesta 204:** sin contenido

---

## Sync

> [!info] Estrategia de sync
> - **Dispositivo nuevo / primera vez**: usar `POST /sync/initial-upload`
> - **Sync incremental**: usar `GET /sync/full` con cursor
> - **Solo sesiones de foco**: usar `GET /sync/sessions` con cursor

### Sync completo incremental 🔐
```
GET /api/v1/sync/full?cursor=<timestamp_iso8601>
```
Omitir `cursor` para obtener todo.

**Respuesta 200:**
```json
{
  "tasks": [...],
  "sessions": [...],
  "settings": [...],
  "nextCursor": "2026-04-20T12:00:00Z",
  "hasMore": false
}
```

### Sync de sesiones 🔐
```
GET /api/v1/sync/sessions?cursor=<timestamp_iso8601>
```
**Respuesta 200:**
```json
{
  "sessions": [
    {
      "id": "uuid",
      "mode": "pomodoro",
      "durationSeconds": 1500,
      "taskId": "uuid o null",
      "completedAt": "..."
    }
  ],
  "nextCursor": "...",
  "hasMore": false
}
```

### Upload inicial (nuevo dispositivo) 🔐
```
POST /api/v1/sync/initial-upload
Content-Type: application/json

{
  "tasks": [...],
  "sessions": [...],
  "settings": [
    { "key": "theme", "value": "dark" },
    { "key": "defaultMode", "value": "pomodoro" }
  ]
}
```

> [!danger] Campo `key` en settings
> El campo es `key`, NO `preferenceKey`. El backend rechaza con `400 invalid_preference_key` si `key` está vacío o ausente.

**Respuesta 200:** `{ "status": "ok" }`

---

## Preferencias / Settings

### Upsert de preferencias 🔐
```
POST /api/v1/preferences/upsert
Content-Type: application/json

{
  "preferences": [
    { "key": "theme", "value": "dark" },
    { "key": "defaultMode", "value": "flowtime" }
  ]
}
```
> [!danger] Misma regla
> Campo es `key`, no `preferenceKey`. Nunca enviar con key vacío.

**Respuesta 200:** `{ "updated": 2 }`
**Errores:**
- `400` — `invalid_preference_key`

---

## Billing

### Verificar compra 🔐
```
POST /api/v1/billing/verify
Content-Type: application/json

{
  "receiptData": "<base64 receipt>",
  "productId": "com.pepinillo.app.apple.unlock"
}
```
**Respuesta 200:**
```json
{
  "isValid": true,
  "entitlement": "pro",
  "expiresAt": "2027-04-20T00:00:00Z"
}
```

> [!info] Compatibilidad
> La respuesta sigue exponiendo `entitlement: "pro"` mientras el backend migra a capabilities. Durante la transicion tambien debe aceptar SKUs legacy `com.pepinillo.app.pro.*`.

### Product IDs válidos

| ID | Precio |
|---|---|
| `com.pepinillo.app.apple.unlock` | $19.99 único |
| `com.pepinillo.app.everywhere.monthly` | $4.99 / mes |
| `com.pepinillo.app.everywhere.annual` | $34.99 / año |

> [!warning] Migracion legacy
> Hasta completar la migracion comercial, backend sigue recibiendo `com.pepinillo.app.pro.monthly`, `com.pepinillo.app.pro.annual` y `com.pepinillo.app.pro.lifetime`.

---

## Dispositivos (Push Notifications)

### Registrar device token 🔐
```
POST /api/v1/devices/register
Content-Type: application/json

{
  "token": "<APNs device token>",
  "platform": "ios"
}
```
**Respuesta 201:** `{ "registered": true }`

---

## WebSocket

```
GET /ws
Authorization: Bearer <accessToken>  (como query param o header)
```
> [!info] Solo notificaciones
> El WebSocket es **unidireccional desde el servidor** — solo recibe push de invalidación de cache o alertas. No sirve para sync de datos.

**Mensaje entrante típico:**
```json
{
  "type": "sync_required",
  "resource": "tasks",
  "timestamp": "2026-04-20T12:00:00Z"
}
```
Al recibir `sync_required`, el cliente iOS debe disparar el sync incremental correspondiente.

---

## Tabla de errores

| HTTP | Error string | Causa | Acción cliente |
|---|---|---|---|
| 400 | `invalid_input` | Payload malformado | Validar antes de enviar |
| 400 | `invalid_preference_key` | Key de preferencia vacía | Verificar que `key` no sea nil/empty |
| 401 | `unauthorized` | Token ausente o inválido | Renovar token, forzar login si falla |
| 401 | `invalid_oauth_token` | Token Apple/Google inválido | Pedir re-autenticación |
| 401 | `invalid_credentials` | Email/password incorrectos | Mostrar error al usuario |
| 404 | `not_found` | Recurso inexistente | Manejar gracefully |
| 409 | `email_already_exists` | Email duplicado en registro | Sugerir login |
| 429 | — | Rate limit excedido | Backoff exponencial |
| 500 | `internal_error` | Error interno del servidor | Reportar y reintentar |

Ver también: [[Autenticacion & Suscripciones]] · [[Arquitectura General]]
