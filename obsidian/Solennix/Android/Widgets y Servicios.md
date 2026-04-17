#android #widgets #servicios #glance

# Widgets y Servicios

> [!abstract] Resumen
> Widgets de home screen con **Glance AppWidget** para acceso rápido: próximos eventos, KPIs, y acciones rápidas. Quick Settings tile para crear eventos. Firebase Messaging para push notifications (stub).

---

## Home Screen Widgets

### Upcoming Events Widget

| Aspecto | Detalle |
|---------|---------|
| Framework | Glance AppWidget |
| Contenido | Lista de próximos 3-5 eventos con fecha y tipo |
| Tap | Deep link a `solennix://event/{id}` |
| Refresh | Cada sync de WorkManager (15 min) |

### KPI Widget

| Aspecto | Detalle |
|---------|---------|
| Contenido | Cards compactas con métricas clave |
| Métricas | Ingresos del mes, eventos pendientes |
| Tap | Deep link a Dashboard |

### Quick Actions Widget

| Aspecto | Detalle |
|---------|---------|
| Contenido | Botones de acceso rápido |
| Acciones | Nuevo evento, nuevo cliente, búsqueda |
| Tap | Deep links respectivos |

---

## Quick Settings Tile

| Aspecto | Detalle |
|---------|---------|
| Tipo | `TileService` |
| Acción | Crear nuevo evento |
| Deep link | `solennix://new-event` |

---

## Firebase Messaging

> [!warning] Stub implementado
> `FirebaseMessagingService` está definido pero **deshabilitado/incompleto**. No hay manejo de tokens FCM ni procesamiento de notificaciones push del backend.

---

## Notificaciones Locales

| Tipo | Trigger | Contenido |
|------|---------|-----------|
| Evento del día | SyncWorker detecta evento hoy | "Tenés un evento hoy: {nombre}" |

---

## Archivos Clave

| Archivo | Ubicación |
|---------|-----------|
| `UpcomingEventsWidget.kt` | `widget/` |
| `KPIWidget.kt` | `widget/` |
| `QuickActionsWidget.kt` | `widget/` |
| `NewEventTileService.kt` | `app/service/` |

---

## Relaciones

- [[Navegación]] — deep links desde widgets
- [[Sincronización Offline]] — refresh de datos para widgets
- [[Módulo Dashboard]] — KPIs compartidos
- [[Módulo Eventos]] — datos de eventos en widgets
