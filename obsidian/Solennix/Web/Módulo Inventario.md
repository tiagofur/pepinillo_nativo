# Módulo Inventario

#web #inventario #dominio

> [!abstract] Resumen
> Sistema de tracking de stock con tres tipos: ingredientes (consumibles de recetas), equipamiento (reutilizable), e insumos (consumibles generales). Alertas de stock bajo.

---

## Páginas

| Página | Ruta | Descripción |
|--------|------|-------------|
| **InventoryList** | `/inventory` | Tabla con filtro por tipo, alerta de stock bajo, búsqueda, sort |
| **InventoryForm** | `/inventory/new`, `/inventory/:id/edit` | Crear/editar ítem con tipo, stock, mínimo, unidad, costo |
| **InventoryDetails** | `/inventory/:id` | Vista detallada con historial de uso |

## Entidad

```typescript
interface InventoryItem {
  id: string;
  user_id: string;
  ingredient_name: string;
  current_stock: number;
  minimum_stock: number;     // Alerta cuando current < minimum
  unit: string;              // "kg", "unidades", "litros", etc.
  unit_cost: number;
  last_updated: string;
  type: 'ingredient' | 'equipment' | 'supply';
}
```

## Tipos de Inventario

| Tipo | Español | Ejemplo | Comportamiento |
|------|---------|---------|----------------|
| `ingredient` | Ingrediente | Harina, azúcar, leche | Consumible — se gasta en cada evento |
| `equipment` | Equipamiento | Mesas, sillas, manteles | Reutilizable — se asigna y devuelve |
| `supply` | Insumo | Globos, servilletas, velas | Consumible general |

## Funcionalidades

- **Filtro por tipo** — Chips: Todos, Ingredientes, Equipamiento, Insumos
- **Filtro de stock bajo** — Toggle para ver solo ítems con `current_stock < minimum_stock`
- **Búsqueda** — Por nombre
- **Sort** — Por nombre, stock actual, tipo
- **Export CSV** — Nombre, tipo, stock, mínimo, unidad, costo unitario
- **Alertas en Dashboard** — Ítems con stock bajo aparecen en el dashboard principal

## Relación con Eventos

Cuando se crea un evento:
- **Equipamiento** → Se selecciona del inventario con detección de conflictos por fecha
- **Insumos** → Se seleccionan con cantidades necesarias
- **Ingredientes** → Se calculan automáticamente desde las recetas de los productos

## Relaciones

- [[Módulo Productos]] — Ingredientes de recetas vinculados al inventario
- [[Módulo Eventos]] — Equipamiento e insumos asignados a eventos
- [[Capa de Servicios]] — inventoryService
