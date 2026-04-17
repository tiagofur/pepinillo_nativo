#ios #dominio #calendario

# Módulo Calendario

> [!abstract] Resumen
> Vista de calendario mensual con eventos marcados por color de status. Gestión de fechas bloqueadas (unavailable dates). Creación rápida de evento desde una fecha del calendario.

---

## Pantallas

| Pantalla | Archivo | Descripción |
|----------|---------|-------------|
| `CalendarView` | `SolennixFeatures/Calendar/Views/` | Calendario mensual |

---

## Funcionalidades

| Feature | Estado |
|---------|--------|
| Vista mensual | ✅ Grid con marcadores por día |
| Marcadores por status | ✅ Colores de EventStatus |
| Tap en día → lista de eventos | ✅ |
| Tap en evento → detalle | ✅ |
| Crear evento desde fecha | ✅ Pre-llena fecha seleccionada |
| Fechas bloqueadas | ✅ Via `/unavailable-dates` |
| Vista semanal | ❌ No implementado |
| Sync con Apple Calendar | ❌ No implementado |

---

## Relaciones

- [[Módulo Eventos]] — muestra eventos en calendario
- [[Navegación]] — tab principal
- [[Manejo de Estado]] — CalendarViewModel
