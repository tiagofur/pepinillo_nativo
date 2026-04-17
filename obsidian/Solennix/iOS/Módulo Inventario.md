#ios #dominio #inventario

# Módulo Inventario

> [!abstract] Resumen
> Control de artículos clasificados como **equipamiento** (reutilizable) e **insumos/ingredientes** (consumibles). Tracking de stock actual vs. mínimo con alertas en dashboard. Detección de conflictos en asignación.

---

## Pantallas

| Pantalla | Archivo | Descripción |
|----------|---------|-------------|
| `InventoryListView` | `SolennixFeatures/Inventory/Views/` | Lista con filtros por tipo |
| `InventoryDetailView` | `SolennixFeatures/Inventory/Views/` | Detalle de stock |
| `InventoryFormView` | `SolennixFeatures/Inventory/Views/` | Creación/edición |

---

## Tipos

| Tipo | Descripción | Ejemplo |
|------|-------------|---------|
| Equipamiento | Reutilizable, se asigna y devuelve | Mesas, sillas, manteles |
| Insumo | Consumible, se gasta | Globos, servilletas, velas |
| Ingrediente | Para recetas de productos | Harina, azúcar, crema |

---

## Campos

| Campo | Tipo | Requerido |
|-------|------|-----------|
| Nombre | Text | Sí |
| Tipo | Picker | Sí |
| Stock actual | Number | Sí |
| Stock mínimo | Number | Sí |
| Unidad | Text | Sí |
| Costo unitario | Decimal | No |

---

## Conflictos de Equipamiento

Cuando equipamiento se asigna a un evento, se verifica si ya está comprometido en otro evento de la misma fecha. Alerta mostrada con lista de eventos en conflicto.

---

## Relaciones

- [[Módulo Eventos]] — equipo e insumos asignados a eventos
- [[Módulo Productos]] — ingredientes vinculados a recetas
- [[Módulo Dashboard]] — alertas de stock bajo
