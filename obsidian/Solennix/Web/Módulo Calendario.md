# Módulo Calendario

#web #calendario #dominio

> [!abstract] Resumen
> Vista mensual de eventos con fechas coloreadas por estado. Soporte para bloquear fechas no disponibles y crear eventos directamente desde el calendario.

---

## Páginas

| Página | Ruta | Descripción |
|--------|------|-------------|
| **CalendarView** | `/calendar` | Vista mensual interactiva con eventos y fechas bloqueadas |

## Componentes

| Componente | Función |
|-----------|---------|
| `CalendarView` | Grid mensual, click para ver evento, context menu |
| `UnavailableDatesModal` | Modal para agregar/eliminar fechas bloqueadas |

## Funcionalidades

- **Vista mensual** — Grid con eventos coloreados por status
- **Click en evento** → Navega al resumen del evento
- **Click en fecha vacía** → Opción de crear nuevo evento con fecha pre-llenada
- **Fechas bloqueadas** — Marcadas visualmente, configurables por rango
- **Navegación** — Mes anterior / siguiente

## Servicio

```
services/unavailableDatesService.ts
```

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `getDates(from, to)` | GET /unavailable-dates | Fechas bloqueadas en rango |
| `addDates(data)` | POST /unavailable-dates | Bloquear rango de fechas |
| `removeDate(id)` | DELETE /unavailable-dates/:id | Desbloquear fecha |

## Relaciones

- [[Módulo Eventos]] — Eventos mostrados en el calendario
- [[Componentes Compartidos]] — react-day-picker como base
