#android #dominio #calendario

# Módulo Calendario

> [!abstract] Resumen
> Vista mensual/semanal de eventos con marcadores visuales por estado. Sincroniza datos desde Room. Soporta navegación a detalle de evento desde el calendario.

---

## Pantallas

| Pantalla | Archivo | Descripción |
|----------|---------|-------------|
| `CalendarScreen` | `feature/calendar/ui/` | Vista de calendario con eventos |

---

## Funcionalidades

| Feature | Estado |
|---------|--------|
| Vista mensual | ✅ Implementado |
| Vista semanal | ✅ Implementado |
| Marcadores por estado | ✅ Colores de EventStatus |
| Tap en evento → detalle | ✅ Navega a EventDetail |
| Fechas no disponibles | ✅ Via `/unavailable-dates` |
| Drag-to-reschedule | ❌ No implementado |
| Sync con Google Calendar | ❌ No implementado |

---

## Visualización de Estados

| Estado | Color del marcador |
|--------|-------------------|
| Cotizado | Naranja `#D97706` |
| Confirmado | Azul `#007AFF` |
| Completado | Verde `#2D6A4F` |
| Cancelado | Rojo `#FF3B30` |

---

## Archivos Clave

| Archivo | Ubicación |
|---------|-----------|
| `CalendarScreen.kt` | `feature/calendar/ui/` |
| `CalendarViewModel.kt` | `feature/calendar/viewmodel/` |

---

## Relaciones

- [[Módulo Eventos]] — muestra eventos en el calendario
- [[Navegación]] — destino principal en bottom nav
- [[Sincronización Offline]] — datos reactivos desde Room
