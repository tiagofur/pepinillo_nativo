# Módulo Productos

#web #productos #dominio

> [!abstract] Resumen
> Catálogo de productos/servicios que el organizador ofrece. Cada producto tiene precio base, categoría, imagen, y una receta (lista de ingredientes/materiales vinculados al inventario).

---

## Páginas

| Página | Ruta | Descripción |
|--------|------|-------------|
| **ProductList** | `/products` | Tabla con imagen, nombre, precio, categoría (pill badge), filtro por categoría |
| **ProductForm** | `/products/new`, `/products/:id/edit` | Formulario con imagen, categoría, precio, ingredientes |
| **ProductDetails** | `/products/:id` | Vista con stats de costo, ingredientes/receta detallados |

## Entidad

```typescript
interface Product {
  id: string;
  user_id: string;
  name: string;
  category: string;        // Ej: "Pastelería", "Decoración", "Show"
  base_price: number;      // Precio base en MXN
  recipe?: string;         // JSON con ingredientes
  image_url?: string;
  is_active: boolean;      // Puede marcarse como inactivo
}
```

## Receta / Ingredientes

Cada producto puede tener una lista de ingredientes vinculados al inventario:

```typescript
interface ProductIngredient {
  type: 'ingredient' | 'equipment' | 'supply';
  inventory_id?: string;
  ingredient_name: string;
  quantity: number;
  unit: string;
  cost: number;
}
```

Esto permite:
- **Cálculo de costo** — Suma de ingredientes vs precio de venta = margen
- **Vinculación con inventario** — Cada ingrediente puede referenciar un `InventoryItem`
- **Lista de compras** — Generar PDF con todos los insumos necesarios para un evento

## Funcionalidades

- **Filtro por categoría** — Chips de categoría dinámica (extraídas de los productos existentes)
- **Búsqueda** — Por nombre o categoría
- **Badge "Inactivo"** — Productos desactivados visibles pero marcados
- **Export CSV** — Nombre, categoría, precio base, activo
- **Sort** — Por nombre, precio, categoría

## Relaciones

- [[Módulo Eventos]] — Productos se agregan a eventos como line items
- [[Módulo Inventario]] — Ingredientes de la receta vinculados a ítems del inventario
- [[Capa de Servicios]] — productService
