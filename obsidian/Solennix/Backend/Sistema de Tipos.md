# Sistema de Tipos

#backend #typescript #models #infraestructura

> [!abstract] Resumen
> Todos los modelos centralizados en `internal/models/models.go`. 15+ structs con JSON tags consistentes. Campos sensibles usan `json:"-"`. Campos opcionales usan punteros (`*string`, `*float64`, `*time.Time`).

---

## Entidades Core

| Entidad | Campos clave | Uso |
|---------|-------------|-----|
| **User** | id, email, password_hash(-), name, plan, role, stripe_customer_id, google/apple_user_id | Auth, perfil, admin |
| **Client** | id, user_id, name, phone, email, city, photo_url, total_events, total_spent | CRUD clientes |
| **Event** | id, user_id, client_id, event_date, status, discount, discount_type, tax_rate, total_amount | CRUD eventos |
| **Product** | id, user_id, name, category, base_price, recipe(JSONB), image_url, is_active | Catálogo |
| **InventoryItem** | id, user_id, ingredient_name, current_stock, minimum_stock, unit, type | Stock |
| **Payment** | id, event_id, user_id, amount, payment_date, payment_method | Pagos |
| **Subscription** | id, user_id, provider, plan, status, period_start/end | Suscripciones |
| **UnavailableDate** | id, user_id, start_date, end_date, reason | Calendario |
| **DeviceToken** | id, user_id, token, platform | Push notifications |

## Sub-entidades de Evento

| Entidad | Relación | Campos clave |
|---------|----------|-------------|
| **EventProduct** | Event ↔ Product | event_id, product_id, quantity, unit_price, discount, total_price(generated) |
| **EventExtra** | Event extras | event_id, description, cost, price, exclude_utility, include_in_checklist |
| **EventEquipment** | Event ↔ Inventory | event_id, inventory_id, quantity, notes |
| **EventSupply** | Event ↔ Inventory | event_id, inventory_id, quantity, unit_cost, source, exclude_cost |
| **EventPhoto** | Event photos | event_id, url, thumbnail_url, caption |

## Relación Producto ↔ Inventario

| Entidad | Descripción |
|---------|-------------|
| **ProductIngredient** | Vincula producto con item de inventario: quantity_required, capacity (para equipo), bring_to_event |

## Modelos de Respuesta (Sugerencias)

| Modelo | Uso |
|--------|-----|
| **EquipmentSuggestion** | Sugerencia de equipo con suggested_qty calculado |
| **EquipmentConflict** | Conflicto detectado entre eventos |
| **SupplySuggestion** | Sugerencia de insumos con suggested_qty |

## Patrones de Diseño

### Campos Sensibles
```go
PasswordHash string `json:"-"` // Nunca expuesto en JSON
```

### Campos Opcionales (Punteros)
```go
BusinessName *string    `json:"business_name,omitempty"` // Null en DB = nil
StartTime    *string    `json:"start_time,omitempty"`    // Opcional
PlanExpiresAt *time.Time `json:"plan_expires_at,omitempty"` // Nullable timestamp
```

### Joined Data
```go
Client      *Client  `json:"client,omitempty"`       // Populated by JOIN query
ProductName *string  `json:"product_name,omitempty"` // From JOIN with products table
```

### JSONB como String
```go
Recipe  *string `json:"recipe,omitempty"`  // JSONB stored as string (recipe data)
Photos  *string `json:"photos,omitempty"`  // JSONB stored as string (array of URLs)
```

## Interfaces de Repositorio

Definidas en `handlers/interfaces.go`:

| Interface | Métodos | Usado por |
|-----------|---------|-----------|
| `FullUserRepository` | GetByEmail, Create, Update, UpdatePassword, OAuth methods | AuthHandler |
| `FullEventRepository` | GetAll, GetByDateRange, Create, Delete, Items, Conflicts, Suggestions, Search | CRUDHandler |
| `ClientRepository` | GetAll, GetByID, Create, Update, Delete, Count, Search | CRUDHandler, Search |
| `ProductRepository` | GetAll, GetByID, Create, Update, Delete, Ingredients, Batch, Search | CRUDHandler, Search |
| `InventoryRepository` | GetAll, GetByID, Create, Update, Delete, Count, Search | CRUDHandler, Search |
| `FullPaymentRepository` | GetAll, GetByEventID, GetByDateRange, Create, Update, Delete | CRUDHandler, EventPayment |
| `AdminRepository` | GetPlatformStats, GetAllUsers, GetUserByID, UpdateUserPlan, ExpireGiftedPlans | AdminHandler |
| `StripeService` | NewCheckoutSession, GetCheckoutSession, NewBillingPortalSession, GetSubscription | SubscriptionHandler |

> [!tip] Mocking
> Todas las interfaces permiten mocking fácil para tests. Los mocks están en `handlers/mocks_test.go`.

## Relaciones

- [[Arquitectura General]] — Models en las capas
- [[Módulo Eventos]] — Sub-entidades de evento en detalle
- [[Módulo Productos]] — ProductIngredient y recetas
