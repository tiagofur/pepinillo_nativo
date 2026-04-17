---
tags:
  - backend
  - módulos
  - auxiliar
  - go
  - api
created: 2025-04-05
updated: 2025-04-05
related:
  - "[[Backend MOC]]"
  - "[[Integraciones]]"
  - "[[Performance]]"
  - "[[Roadmap Backend]]"
---

# Módulos Auxiliares del Backend

Documentación consolidada de cuatro módulos auxiliares del backend de Solennix. Cada uno cumple un rol específico dentro del ecosistema API y operan de forma independiente entre sí.

> [!info] Resumen Rápido
> | Módulo | Handler | Propósito |
> |--------|---------|-----------|
> | Calendario | `UnavailableDateHandler` | Gestión de fechas no disponibles |
> | Búsqueda Global | `SearchHandler` | Búsqueda unificada entre entidades |
> | Uploads | `UploadHandler` | Subida y servicio de imágenes |
> | Dispositivos | `DeviceHandler` | Registro de push tokens |

---

## Módulo Calendario (Fechas No Disponibles)

> [!tip] Propósito
> Permite al organizador marcar rangos de fechas como **no disponibles**, bloqueando la creación de eventos en esos períodos.

### Endpoints

| Método | Ruta | Descripción |
|--------|------|-------------|
| `GET` | `/api/unavailable-dates` | Lista todas las fechas no disponibles del usuario |
| `POST` | `/api/unavailable-dates` | Crea un nuevo rango de fechas no disponibles |
| `DELETE` | `/api/unavailable-dates/{id}` | Elimina un rango de fechas no disponibles |

### Modelo de Datos — `UnavailableDate`

```
UnavailableDate {
    id         string    // UUID, PK
    user_id    string    // FK → users, obligatorio
    start_date time.Time // Inicio del rango
    end_date   time.Time // Fin del rango
    reason     string    // Opcional — motivo de la no disponibilidad
}
```

### Comportamiento Clave

- **Rangos de fechas**: Se almacena un `start_date` y `end_date`, no fechas individuales. Un solo registro puede cubrir un bloque completo (ej: vacaciones del 10 al 20 de marzo).
- **Filtrado por `user_id`**: Toda query filtra por el usuario autenticado. Es multi-tenant a nivel de fila — ver [[Seguridad]].
- **Validación**: `start_date` debe ser anterior o igual a `end_date`.

> [!example] Ejemplo de Request — Crear rango
> ```json
> POST /api/unavailable-dates
> {
>   "start_date": "2026-01-10",
>   "end_date": "2026-01-20",
>   "reason": "Vacaciones personales"
> }
> ```

> [!warning] Nota de Diseño
> Actualmente no existe validación automática al crear eventos que verifique solapamiento con fechas no disponibles. Esa lógica debe implementarse en el [[Módulo Eventos]].

---

## Módulo Búsqueda Global

> [!tip] Propósito
> Búsqueda unificada que permite al usuario buscar un término y obtener resultados de **múltiples entidades** agrupados por tipo.

### Endpoint

| Método | Ruta | Rate Limit |
|--------|------|------------|
| `GET` | `/api/search?q=query` | 30 requests/minuto |

### Entidades y Campos Buscados

| Entidad | Campos donde se busca |
|---------|-----------------------|
| Clients | `name`, `phone`, `email` |
| Products | `name`, `category` |
| Inventory | `name` |
| Events | `service_type` |

### Comportamiento Clave

- **Resultados agrupados**: La respuesta devuelve los resultados separados por tipo de entidad, no como una lista plana.
- **Estrategia actual — `ILIKE`**: Usa `ILIKE '%query%'` de PostgreSQL para matching case-insensitive. Funciona pero es un **full table scan** — no usa índices estándar.
- **Filtrado por `user_id`**: Cada búsqueda se restringe al usuario autenticado.

> [!example] Ejemplo de Response
> ```json
> GET /api/search?q=juan
> {
>   "clients": [{ "id": "...", "name": "Juan Pérez", ... }],
>   "products": [],
>   "inventory": [],
>   "events": []
> }
> ```

> [!bug] Limitación de Performance
> El uso de `ILIKE '%termino%'` con wildcard inicial impide el uso de índices B-tree. Para volúmenes grandes de datos, esto degrada significativamente. Ver [[Performance]] para el plan de mejora.

> [!roadmap] Mejora Planeada — Full-Text Search
> Migrar a **PostgreSQL Full-Text Search** con índices `GIN`:
> - Crear `tsvector` columns en las tablas relevantes
> - Indexar con `GIN` para búsquedas sub-milisegundo
> - Soporte para stemming y acentos en español
> - Ver detalles en [[Roadmap Backend]]

---

## Módulo Uploads

> [!tip] Propósito
> Gestiona la subida de imágenes (fotos de eventos, productos, etc.) y las sirve como archivos estáticos con cache agresivo.

### Endpoints

| Método | Ruta | Rate Limit | Descripción |
|--------|------|------------|-------------|
| `POST` | `/api/uploads/image` | 5 requests/minuto | Sube una imagen |
| `GET` | `/api/uploads/*` | — | Sirve archivos estáticos (cache 1 año) |

### Flujo de Subida

```
Cliente → POST /api/uploads/image (multipart)
    → Validación de tipo (JPEG, PNG)
    → Verificación de límite de plan
    → Almacenamiento en disco local
    → Generación automática de thumbnail
    → Response con URL del archivo
```

### Almacenamiento en Disco

```
{UPLOAD_DIR}/
  └── {userID}/
      ├── {filename}.{ext}          # Imagen original
      └── {filename}_thumb.{ext}    # Thumbnail auto-generado
```

- Cada usuario tiene su propio subdirectorio.
- Thumbnails se generan automáticamente al subir la imagen.

### Límites por Plan

| Plan | Máx. Uploads |
|------|-------------|
| Basic | 50 |
| Pro | 200 |

### Formatos Aceptados

- **JPEG** (`image/jpeg`)
- **PNG** (`image/png`)

> [!warning] Limitación Crítica — Almacenamiento Local
> El almacenamiento actual es **disco local del servidor**. Esto significa:
>
> - **No funciona con múltiples instancias** — cada instancia tiene su propio filesystem
> - **Sin replicación** — si el servidor cae, las imágenes se pierden
> - **Sin CDN** — el ancho de banda sale del servidor de la app
>
> Para producción multi-instancia, migrar a S3/GCS. Ver [[Roadmap Backend]] y [[Despliegue]].

> [!info] Cache de Archivos Estáticos
> Los archivos servidos por `GET /api/uploads/*` tienen headers de cache de **1 año** (`Cache-Control: max-age=31536000`). Esto es seguro porque los filenames incluyen un identificador único — si se re-sube una imagen, el nombre cambia y no hay stale cache.

---

## Módulo Dispositivos (Push Tokens)

> [!tip] Propósito
> Registra y desregistra **push tokens** de dispositivos para habilitar notificaciones push futuras.

### Endpoints

| Método | Ruta | Descripción |
|--------|------|-------------|
| `POST` | `/api/devices/register` | Registra un token de dispositivo |
| `POST` | `/api/devices/unregister` | Elimina un token de dispositivo |

### Modelo de Datos — `DeviceToken`

```
DeviceToken {
    id       string    // UUID, PK
    user_id  string    // FK → users
    token    string    // Push token del servicio (APNs/FCM)
    platform string    // "ios" | "android" | "web"
}
```

### Plataformas Soportadas

| Plataforma | Servicio Push |
|-----------|---------------|
| `ios` | Apple Push Notification service (APNs) |
| `android` | Firebase Cloud Messaging (FCM) |
| `web` | Web Push API |

### Comportamiento Clave

- **Un token por dispositivo**: Si se registra un token que ya existe para el usuario, se actualiza en lugar de duplicar.
- **Unregister elimina**: Al desregistrar, el token se borra de la base de datos.

> [!danger] Estado de Implementación — Incompleto
> Los endpoints de registro funcionan correctamente y los tokens **se almacenan** en la base de datos. Sin embargo:
>
> - **NO se envían notificaciones push** — no existe integración con APNs ni FCM todavía
> - **NO hay sistema de cola** — no hay mecanismo para procesar envíos asíncronos
> - **NO hay templates** — no hay definición de tipos de notificación ni formatos
>
> Este módulo es la **base** para el sistema de notificaciones, pero el envío real está pendiente. Ver [[Roadmap Backend]] para el timeline.

> [!roadmap] Plan de Implementación de Notificaciones
> 1. Integrar SDK de FCM (Android/Web) y APNs (iOS)
> 2. Crear servicio de cola con workers asíncronos
> 3. Definir templates de notificación (nuevo evento, recordatorio, pago recibido, etc.)
> 4. Panel de preferencias de notificación por usuario
> 5. Ver [[Integraciones]] para detalles de los servicios externos

---

## Vista de Dependencias

```
┌─────────────────────────────────────────────────┐
│                  Auth Middleware                 │
│              (todos los módulos)                 │
├─────────┬──────────┬──────────┬─────────────────┤
│Calendar │ Search   │ Uploads  │ Devices         │
│ Handler │ Handler  │ Handler  │ Handler         │
├─────────┼──────────┼──────────┼─────────────────┤
│unavail. │ clients  │ disk     │ device_tokens   │
│ _dates  │ products │ storage  │ table           │
│ table   │ inventory│          │                 │
│         │ events   │          │                 │
└─────────┴──────────┴──────────┴─────────────────┘
         │          │          │          │
         ▼          ▼          ▼          ▼
      PostgreSQL PostgreSQL  Local FS  PostgreSQL
```

## Cross-References

| Tema | Documentación |
|------|--------------|
| Middleware de autenticación | [[Middleware Stack]] |
| Límites de plan y suscripción | [[Autenticación]] |
| Esquema de base de datos | [[Base de Datos]] |
| Plan de mejora de performance | [[Performance]] |
| Roadmap de features pendientes | [[Roadmap Backend]] |
| Servicios externos (FCM, S3) | [[Integraciones]] |
| Despliegue multi-instancia | [[Despliegue]] |
| Seguridad y multi-tenancy | [[Seguridad]] |
| Índice general del backend | [[Backend MOC]] |
