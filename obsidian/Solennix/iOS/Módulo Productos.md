#ios #dominio #productos

# Módulo Productos

> [!abstract] Resumen
> Catálogo de productos/servicios con sistema de recetas (ingredientes con costos), gráfico de demanda, estado activo/inactivo, y cálculo automático de costos por ingredientes.

---

## Pantallas

| Pantalla | Archivo | Descripción |
|----------|---------|-------------|
| `ProductListView` | `SolennixFeatures/Products/Views/` | Catálogo con búsqueda |
| `ProductDetailView` | `SolennixFeatures/Products/Views/` | Detalle con receta y demanda |
| `ProductFormView` | `SolennixFeatures/Products/Views/` | Creación/edición con ingredientes |

---

## Campos del Producto

| Campo | Tipo | Requerido |
|-------|------|-----------|
| Nombre | Text | Sí |
| Categoría | Text | Sí |
| Precio base | Decimal | Sí |
| Imagen | Image URL | No |
| Receta / Notas | TextArea | No |
| Activo | Toggle | Sí (default: true) |

---

## Sistema de Recetas

Cada producto puede tener ingredientes vinculados al inventario:

| Campo | Tipo | Descripción |
|-------|------|-------------|
| Ingrediente | Nombre o link a inventario | Ingrediente necesario |
| Cantidad | Decimal | Cantidad por unidad de producto |
| Unidad | Text | kg, L, pz, etc. |
| Costo | Decimal | Costo del ingrediente (del inventario) |

> [!tip] Costo automático
> Si el ingrediente está en inventario, el costo se toma del `unitCost` del `InventoryItem`.

---

## Demanda Predictiva

Gráfico en el detalle que muestra la frecuencia de uso del producto en eventos a lo largo del tiempo.

---

## Relaciones

- [[Módulo Eventos]] — productos se asignan a eventos
- [[Módulo Inventario]] — ingredientes linkeados al inventario
- [[Sistema de Tipos]] — `Product`, `ProductIngredient`
