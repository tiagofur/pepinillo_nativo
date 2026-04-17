---
tags:
  - backend
  - pagos
  - módulo
created: 2025-04-05
updated: 2025-04-05
---

# Módulo Pagos

> [!abstract] Resumen
> Sistema de registro manual de pagos vía `CRUDHandler`. Permite trackear el balance de cada evento (total vs. pagado). La app no intermediar pagos entre organizadores y sus clientes — los pagos son registros de lo cobrado fuera de la app. Todos los endpoints filtran por `user_id` para aislamiento multi-tenant.

## Relaciones

- **Padre**: [[Backend MOC]]
- **Relacionados**: [[Módulo Eventos]], [[Integraciones]], [[Sistema de Tipos]]

---

## Struct Payment

```go
type Payment struct {
    ID            string   `json:"id"`
    EventID       string   `json:"event_id"`
    UserID        string   `json:"user_id"`
    Amount        float64  `json:"amount"`
    PaymentDate   string   `json:"payment_date"`    // DATE "YYYY-MM-DD"
    PaymentMethod string   `json:"payment_method"`
    Notes         *string  `json:"notes"`            // opcional
    CreatedAt     time.Time `json:"created_at"`
}
```

> [!tip] Formato de fecha
> `payment_date` se formatea en la query SQL con `to_char(payment_date, 'YYYY-MM-DD')` para devolver siempre un string consistente, sin timezone issues.

---

## Arquitectura

El módulo usa `CRUDHandler` para el CRUD manual de pagos (abonos, efectivo, transferencia):

| Handler                  | Responsabilidad                                        | Archivo                          |
|--------------------------|--------------------------------------------------------|----------------------------------|
| `CRUDHandler`            | CRUD manual de pagos (abonos, efectivo, transferencia) | `crud_handler.go`                |

> [!info] Solo registro manual
> Los pagos son registros manuales que el organizador lleva para trackear lo cobrado fuera de la app (efectivo, transferencia directa, etc.). Solennix no procesa ni intermediar pagos entre organizadores y sus clientes. Stripe se usa exclusivamente para las suscripciones Pro de los usuarios.

---

## Endpoints — Pagos Manuales

### Listar pagos

```
GET /api/payments
```

| Parámetro   | Tipo   | Descripción                                          |
|-------------|--------|------------------------------------------------------|
| `event_id`  | string | Filtrar por evento específico                        |
| `start`     | string | Fecha inicio (rango)                                 |
| `end`       | string | Fecha fin (rango)                                    |
| `event_ids` | string | CSV de UUIDs — usado por dashboard para cálculos     |

Respuesta: `200 OK` — Array de [[#Struct Payment\|Payment]]

> [!tip] Query flexible
> `ListPayments` evalúa los query params en orden: `event_id` → `start+end` → `event_ids` → `GetAll`. Solo aplica el primer match.

### Crear pago manual

```
POST /api/payments
```

Validaciones (`ValidatePayment`):
- `amount` debe ser > 0
- `payment_method` es requerido

```json
{
    "event_id": "uuid",
    "amount": 1500.00,
    "payment_date": "2025-04-05",
    "payment_method": "cash",
    "notes": "Primer abono"
}
```

Respuesta: `201 Created` — Payment creado (con `id` y `created_at` generados)

### Actualizar pago

```
PUT /api/payments/{id}
```

Mismas validaciones que create. El `user_id` se toma del JWT, no del body.

### Eliminar pago

```
DELETE /api/payments/{id}
```

Respuesta: `204 No Content`. Retorna `404` si el pago no existe o no pertenece al usuario.

---

## FullPaymentRepository

Interfaz completa del repositorio de pagos (`interfaces.go:96`):

```go
type FullPaymentRepository interface {
    PaymentRepository                              // Create (heredado)
    GetAll(ctx, userID) ([]Payment, error)
    GetByEventID(ctx, userID, eventID) ([]Payment, error)
    GetByDateRange(ctx, userID, start, end) ([]Payment, error)
    GetByEventIDs(ctx, userID, eventIDs) ([]Payment, error)
    Update(ctx, userID, payment) error
    Delete(ctx, id, userID) error
}
```

### Implementación SQL

Definida en `payment_repo.go`. Campos seleccionados:

```sql
id, event_id, user_id, amount,
to_char(payment_date, 'YYYY-MM-DD') as payment_date,
payment_method, notes, created_at
```

| Método             | Query clave                                                                 |
|--------------------|-----------------------------------------------------------------------------|
| `GetAll`           | `WHERE user_id = $1 ORDER BY payment_date DESC`                            |
| `GetByEventID`     | `WHERE user_id = $1 AND event_id = $2`                                     |
| `GetByDateRange`   | `WHERE user_id = $1 AND payment_date >= $2::date AND payment_date <= $3`   |
| `GetByEventIDs`    | `WHERE user_id = $1 AND event_id = ANY($2)`                                |
| `Create`           | `INSERT ... RETURNING id, created_at`                                       |
| `Update`           | `UPDATE ... WHERE id=$1 AND user_id=$6 RETURNING event_id, user_id`        |
| `Delete`           | `DELETE WHERE id=$1 AND user_id=$2` + check `RowsAffected()`              |

> [!tip] GetByEventIDs
> Acepta un slice de UUIDs usando `ANY($2)`. Retorna vacío si el slice está vacío (sin query). Usado por el dashboard para calcular métricas financieras de múltiples eventos en una sola query.

---

## Balance por Evento

El balance de cada evento se calcula en el frontend:

```
balance = event.TotalAmount - SUM(payments.amount WHERE event_id = event.id)
```

- `TotalAmount` viene de [[Módulo Eventos]] (incluye productos, extras, impuestos, descuentos)
- `SUM(payments)` se obtiene con `GET /api/payments?event_id={id}`
- Si `balance > 0` → saldo pendiente
- Si `balance <= 0` → evento pagado

---

## StripeService (Abstracción)

```go
type StripeService interface {
    NewCheckoutSession(params) (*CheckoutSession, error)
    GetCheckoutSession(id, params) (*CheckoutSession, error)
    NewBillingPortalSession(params) (*BillingPortalSession, error)
    GetSubscription(id, params) (*Subscription, error)
}
```

`DefaultStripeService` (`stripe_service.go`) delega directamente al SDK de Stripe. La interfaz permite mocking para tests — ver [[Integraciones]].

---

## Rutas en el Router

```
/api/payments
├── GET    /              → CRUDHandler.ListPayments
├── POST   /              → CRUDHandler.CreatePayment
├── PUT    /{id}          → CRUDHandler.UpdatePayment
└── DELETE /{id}          → CRUDHandler.DeletePayment
```

Todas las rutas requieren autenticación (`mw.Auth`).

---

## Multi-tenancy

> [!warning] Seguridad
> **TODAS** las queries filtran por `user_id`. El Stripe checkout también valida que `metadata.user_id` coincida con el token JWT. Un pago de un usuario NUNCA es visible para otro.

Patrón en queries:

```sql
WHERE id = $1 AND user_id = $2
```

En Stripe: `sess.Metadata["user_id"] != userID.String()` → `403 Forbidden`.

---

## Base de Datos

Tabla `payments` (migración `007_create_payments_subscriptions.up.sql`):

```sql
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    amount NUMERIC NOT NULL CHECK (amount > 0),
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    payment_method VARCHAR NOT NULL DEFAULT 'cash',
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

Índices: `idx_payments_event_id`, `idx_payments_user_id`, `idx_payments_date`.

> [!info] CASCADE
> `ON DELETE CASCADE` en `event_id` significa que al eliminar un evento, se eliminan automáticamente todos sus pagos asociados.

---

## Ver también

- [[Backend MOC]] — Índice general del backend
- [[Módulo Eventos]] — `TotalAmount` y contexto del evento para Stripe
- [[Integraciones]] — Detalle de la integración con Stripe SDK
- [[Sistema de Tipos]] — Definición de `Payment` y tipos base
