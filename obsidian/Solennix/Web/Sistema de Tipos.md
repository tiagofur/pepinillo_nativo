# Sistema de Tipos

#web #typescript #infraestructura

> [!abstract] Resumen
> Tipos centralizados en `types/entities.ts` que mapean al backend Go. Patrón Insert/Update con Omit para CRUD operations.

---

## Archivo Principal

```
types/entities.ts
```

## Entidades Core

| Entidad | Campos clave | Uso |
|---------|-------------|-----|
| **User** | id, email, name, business_name, plan, role, brand_color, contract_template | Auth, perfil, settings |
| **Client** | id, name, phone, email, city, photo_url, total_events, total_spent | CRUD clientes |
| **Event** | id, client_id, event_date, status, service_type, num_people, total_amount | CRUD eventos |
| **Product** | id, name, category, base_price, recipe, image_url, is_active | Catálogo |
| **InventoryItem** | id, ingredient_name, current_stock, minimum_stock, unit, type | Stock |
| **Payment** | id, event_id, amount, payment_date, payment_method, status | Pagos |

## Entidades de Relación (Event sub-items)

| Entidad | Relación | Campos clave |
|---------|----------|-------------|
| **EventProduct** | Event ↔ Product | event_id, product_id, quantity, unit_price, total_price |
| **EventExtra** | Event extras | event_id, description, amount |
| **EventEquipment** | Event ↔ Equipment | event_id, equipment_name, quantity, notes |
| **EventSupply** | Event ↔ Supply | event_id, supply_name, quantity, unit |
| **ProductIngredient** | Product ↔ Inventory | type, inventory_id, ingredient_name, quantity, cost |

## Patrón Insert / Update

```typescript
// Tipos para crear (sin campos auto-generados)
type ClientInsert = Omit<Client, 'id' | 'total_events' | 'total_spent'>;

// Tipos para actualizar (parcial, sin campos inmutables)
type ClientUpdate = Partial<Omit<Client, 'id' | 'user_id'>>;
```

## Declaration Files

| Archivo | Propósito |
|---------|-----------|
| `google.d.ts` | Typings para Google Sign-In SDK |
| `apple.d.ts` | Typings para Apple Sign-In SDK |
| `vite-env.d.ts` | Typings para variables de entorno Vite |

## Relaciones

- [[Capa de Servicios]] — Servicios tipados con estas entidades
- [[Arquitectura General]] — Type-first development
