# Módulo Admin

#web #admin #dominio

> [!abstract] Resumen
> Panel de administración de la plataforma. Solo accesible con `role === 'admin'`. Dashboard con métricas globales y gestión de usuarios.

---

## Páginas

| Página | Ruta | Guard | Descripción |
|--------|------|-------|-------------|
| **AdminDashboard** | `/admin` | AdminRoute | Stats globales: usuarios, suscripciones, revenue |
| **AdminUsers** | `/admin/users` | AdminRoute | Tabla de usuarios con filtros, regalo de planes |

## AdminDashboard

Métricas mostradas:
- Total de usuarios registrados
- Usuarios con suscripción pagada
- Revenue total
- Usuarios activos (último mes)
- Gráficos con Recharts (tendencias)

## AdminUsers

| Funcionalidad | Detalle |
|--------------|---------|
| **Lista de usuarios** | Nombre, email, plan, estado, última actividad |
| **Filtros** | Todos, Activos, Inactivos, Con suscripción, Planes regalo |
| **Búsqueda** | Por nombre o email |
| **Sort** | Por nombre, actividad |
| **Gift Plan** | Regalar plan Pro a un usuario (acción admin) |
| **Stat Chips** | Contadores rápidos (total, activos, sin actividad, pagados, regalos) |

## Servicio

```
services/adminService.ts
```

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `getStats()` | GET /admin/stats | Métricas globales de la plataforma |
| `getUsers()` | GET /admin/users | Lista de todos los usuarios |

## Relaciones

- [[Routing y Guards]] — AdminRoute protege estas rutas
- [[Autenticación]] — Requiere `user.role === 'admin'`
