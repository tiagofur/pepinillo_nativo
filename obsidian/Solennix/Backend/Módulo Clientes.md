---
tags:
  - backend
  - clientes
  - módulo
created: 2025-04-05
updated: 2025-04-05
---

# Módulo Clientes

> [!abstract] Resumen
> CRUD completo para gestión de clientes con métricas computadas (`total_events`, `total_spent`). Parte de la arquitectura basada en `CRUDHandler`. Todos los endpoints filtran por `user_id` para garantizar aislamiento multi-tenant.

## Relaciones

- **Padre**: [[Backend MOC]]
- **Relacionados**: [[Módulo Eventos]], [[Módulo Uploads]], [[Sistema de Tipos]]

---

## Struct Client

```go
type Client struct {
    ID           string   `json:"id"`
    UserID       string   `json:"user_id"`
    Name         string   `json:"name"`
    Phone        string   `json:"phone"`
    Email        *string  `json:"email"`        // opcional
    Address      *string  `json:"address"`       // opcional
    City         *string  `json:"city"`          // opcional
    Notes        *string  `json:"notes"`         // opcional
    PhotoURL     *string  `json:"photo_url"`     // opcional
    TotalEvents  int      `json:"total_events"`  // computado
    TotalSpent   float64  `json:"total_spent"`   // computado
}
```

> [!tip] Campos computados
> `total_events` y `total_spent` **no se persisten directamente** — se recalculan vía `UpdateClientStats` cuando un evento cambia y afecta los totales del cliente. Esto garantiza consistencia sin depender de triggers de BD.

---

## Endpoints

### Listar clientes

```
GET /api/clients
```

| Parámetro  | Tipo   | Descripción                        |
|------------|--------|------------------------------------|
| `user_id`  | string | Filtrado automático via JWT claims |

Respuesta: `200 OK` — Array de [[#Struct Client\|Client]]

### Crear cliente

```
POST /api/clients
```

> [!warning] Plan limits
> El plan **basic** tiene un máximo de clientes. Se verifica con `CountByUserID` **antes** de la inserción. Si se excede el límite, retorna `403 Forbidden`.

### Obtener cliente

```
GET /api/clients/{id}
```

Valida que el `user_id` del recurso coincida con el del token. Si no coincide: `404 Not Found` (no `403`, para no filtrar existencia).

### Actualizar cliente

```
PUT /api/clients/{id}
```

Mismas validaciones de ownership que GET individual.

### Eliminar cliente

```
DELETE /api/clients/{id}
```

Elimina el cliente. Los eventos asociados se manejan según la lógica definida en [[Módulo Eventos]].

---

## Handlers Involucrados

| Handler           | Responsabilidad                                    |
|-------------------|----------------------------------------------------|
| `CRUDHandler`     | Operaciones CRUD estándar (GET, POST, PUT, DELETE) |
| `SearchHandler`   | Búsqueda full-text por nombre, email, teléfono     |
| `UploadHandler`   | Upload de `photo_url` para el cliente              |

> [!tip] Reutilización
> Al usar `CRUDHandler` genérico, el módulo de clientes hereda toda la lógica común de validación, serialización y manejo de errores sin código duplicado. Ver [[Sistema de Tipos]] para los tipos base.

---

## Funciones Clave

### `CountByUserID(userID string) (int, error)`

Retorna la cantidad total de clientes del usuario. Se usa para verificar límites del plan:

```go
count, err := store.CountByUserID(ctx, userID)
if err != nil { ... }
if count >= planLimits.MaxClients {
    return ErrPlanLimitExceeded
}
```

### `UpdateClientStats(clientID string) error`

Recalcula `total_events` y `total_spent` agregando desde la tabla de eventos:

```sql
SELECT COUNT(*), COALESCE(SUM(total), 0)
FROM events
WHERE client_id = $1
```

> [!warning] Cuándo llamar UpdateClientStats
> Se invoca desde [[Módulo Eventos]] cuando:
> - Se crea un evento asociado a un cliente
> - Se actualiza el `total` o `client_id` de un evento
> - Se elimina un evento

---

## Multi-tenancy

> [!warning] Seguridad
> **TODAS** las queries filtran por `user_id`. Esto no es opcional — es la base del aislamiento multi-tenant en Solennix. Un cliente de un usuario NUNCA es visible para otro usuario.

Patrón en todas las queries:

```sql
WHERE id = $1 AND user_id = $2
```

El `user_id` se extrae del contexto de autenticación (JWT), nunca del body del request.

---

## Flujo de Upload de Foto

1. Cliente envía `multipart/form-data` a `UploadHandler`
2. Se valida tipo y tamaño del archivo
3. Se sube a storage (ver [[Módulo Uploads]])
4. Se retorna la URL pública
5. El frontend envía un `PUT /api/clients/{id}` con el `photo_url`

---

## Plan Limits

| Plan     | Máx. Clientes |
|----------|---------------|
| Basic    | Limitado      |
| Pro      | Sin límite    |
| Premium  | Sin límite    |

La verificación se hace en el handler `POST /api/clients` antes de delegar al store:

```
Request → Auth → CheckPlanLimits → CountByUserID → Create → Response
```

---

## Ver también

- [[Backend MOC]] — Índice general del backend
- [[Módulo Eventos]] — Dispara `UpdateClientStats`
- [[Módulo Uploads]] — Manejo de fotos de clientes
- [[Sistema de Tipos]] — Definición de `Client` y tipos base
