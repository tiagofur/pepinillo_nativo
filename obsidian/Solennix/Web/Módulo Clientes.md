# Módulo Clientes

#web #clientes #dominio

> [!abstract] Resumen
> CRUD de clientes con foto de perfil, datos de contacto, y estadísticas de eventos/gasto total. Límite por plan (50 en básico).

---

## Páginas

| Página | Ruta | Descripción |
|--------|------|-------------|
| **ClientList** | `/clients` | Tabla con foto, nombre, contacto, eventos, gasto total, sort/search/paginate |
| **ClientForm** | `/clients/new`, `/clients/:id/edit` | Formulario con foto opcional, validación RHF+Zod |
| **ClientDetails** | `/clients/:id` | Perfil: stats (eventos, gasto), historial de eventos |

## Entidad

```typescript
interface Client {
  id: string;
  user_id: string;
  name: string;         // Requerido, mín. 2 chars
  phone: string;        // Requerido, mín. 10 dígitos
  email?: string;       // Opcional, validado si presente
  address?: string;
  city?: string;
  notes?: string;
  photo_url?: string;   // Upload a backend
  total_events: number; // Calculado por backend
  total_spent: number;  // Calculado por backend
}
```

## Funcionalidades

- **Foto de perfil** — Upload con preview local inmediato, max 10MB
- **Búsqueda** — Por nombre, email o teléfono
- **Acciones rápidas en tabla** — Llamar (tel:), Email (mailto:), Ver, Editar, Eliminar
- **Export CSV** — Nombre, teléfono, email, dirección, ciudad, eventos, gasto, notas
- **Paginación** — 8 items por página con sort por nombre, eventos, gasto
- **Límite de plan** — `usePlanLimits()` verifica si puede crear más clientes; muestra `UpgradeBanner` si no

## Servicio

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `getAll()` | GET /clients | Lista con stats calculadas |
| `getById(id)` | GET /clients/:id | Detalle individual |
| `create(data)` | POST /clients | Crear cliente |
| `update(id, data)` | PUT /clients/:id | Actualizar |
| `delete(id)` | DELETE /clients/:id | Eliminar (eventos quedan sin asignar) |
| `uploadPhoto(file)` | POST /clients/upload | Subir foto de perfil |

> [!warning] Cascada al Eliminar
> Al eliminar un cliente, los eventos existentes quedan sin cliente asignado (no se eliminan). El diálogo de confirmación lo explica claramente.

## Relaciones

- [[Módulo Eventos]] — Cada evento pertenece a un cliente
- [[Capa de Servicios]] — clientService
- [[Hooks Personalizados]] — usePlanLimits para límite de creación
