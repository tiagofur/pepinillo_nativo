# Pepinillo — Documento Unificado de Features

**Version:** 1.0
**Fecha:** 2026-03-20
**Plataformas:** iOS (iPhone/iPad/Mac), Android (Phone/Tablet), watchOS, Wear OS
**Autor:** Tiago David + Claude Code
**Estado:** Borrador

---

## Convenciones de Etiquetas

| Etiqueta | Significado |
|----------|-------------|
| **[Todas]** | Feature compartida en todas las plataformas |
| **[iOS]** | Exclusiva de iOS (iPhone, iPad, Mac) |
| **[Android]** | Exclusiva de Android (Phone, Tablet, Foldable) |
| **[watchOS]** | Exclusiva de Apple Watch |
| **[Wear OS]** | Exclusiva de Wear OS |

---

## P0 — Must-Have (Obligatorio)

### Motor de Enfoque Multi-Modo [Todas]

El diferenciador principal de Pepinillo: 4 modos de enfoque en una sola app, implementados con **Strategy pattern** para compartir el 80% del motor de timer entre modos.

#### Modos disponibles

| Modo | Descripcion | Tier |
|------|-------------|------|
| **Pomodoro** | Intervalos clasicos 25/5/15. Ciclos automaticos work-break-work. Seguimiento de numero de pomodoro (ej. "3 de 4"). Duraciones personalizables. | FREE |
| **Flowtime** | Sesion abierta sin intervalos fijos. Al sentir fatiga, el usuario toma un break. La app sugiere duracion de break segun tiempo enfocado (10 min -> 2 min break, 50 min -> 10 min break). Ideal para trabajo creativo. | PRO |
| **Time Block** | Bloque fijo de tiempo (ej. "2 horas de escritura"). Un countdown continuo con check-ins opcionales a mitad de bloque. Seguimiento de bloques completados por dia. | PRO |
| **Stopwatch (Chrono)** | Timer ascendente sin presion. Sin metas ni estructura. Solo rastrea cuanto tiempo trabajas. Pausa y stop. Ideal para el segmento casual/flexible. | FREE |

#### Arquitectura del motor

- **Strategy pattern** unificado: una interfaz comun (`FocusModeStrategy` / `FocusModeProtocol`) con implementaciones especificas por modo
- **Estado compartido**: timer, pause/resume, interruption tracking, session linking
- **Supervision en background**: el timer debe sobrevivir minimizacion, cambio de app y lock de pantalla
  - **[iOS]**: Live Activity + aritmetica de `Date` para recalcular al volver al foreground. No depende de timers en background.
  - **[Android]**: Foreground Service (`START_STICKY`) con notificacion persistente. Survive process death.
- **Pause/Resume**: tracking preciso de tiempo pausado y numero de interrupciones por sesion
- **Session Journaling**: reflexion post-sesion con nota de texto libre ("Que logre?") + rating de satisfaccion 1-5 estrellas

---

### Gestion de Tareas [Todas]

Sistema de tareas integrado con el motor de enfoque. No es un task manager generico: esta disenado para planificar y ejecutar sesiones de deep work.

#### Funcionalidades core

| Feature | Tier | Detalle |
|---------|------|---------|
| CRUD de tareas | FREE | Crear, editar, eliminar tareas con titulo, descripcion |
| Drag-to-reorder | FREE | Reordenar tareas por prioridad arrastrando |
| Subtareas | PRO | Subtareas anidadas (hasta 20 por tarea) con checkbox individual |
| Prioridad | FREE | Ninguna / Baja / Media / Alta — indicador visual |
| Niveles de energia | FREE | Deep Work / Shallow Work / Admin — para agrupar tareas similares |
| Pomodoros estimados/completados | FREE | Asignar estimacion de pomodoros a una tarea, trackear los completados |
| Vincular tarea a sesion de enfoque | FREE | Cualquier modo de enfoque puede vincularse a una tarea activa. La sesion registra: tarea, modo usado, duracion, estado de completitud |
| Tareas recurrentes | PRO | 5 presets: diario, dias de semana, semanal, bisemanal, mensual |
| Limite de tareas | FREE: 3 activas / PRO: ilimitadas | Motiva upgrade natural |

---

### Analytics y Dashboard [Todas]

Panel analitico con desglose por modo de enfoque — no solo "horas totales" sino como rinde cada tecnica para el usuario.

#### Vistas temporales

| Vista | Tier |
|-------|------|
| Hoy + ultimos 7 dias | FREE |
| 30 dias | PRO |
| 1 ano | PRO |

#### Componentes del dashboard

| Componente | Tier | Detalle |
|------------|------|---------|
| Resumen diario | FREE | Horas de focus, sesiones completadas, tareas terminadas |
| Desglose por modo | PRO | Graficas que muestran distribucion de tiempo entre Pomodoro/Flowtime/TimeBlock/Chrono |
| Horas mas productivas | PRO | Analisis por hora del dia y dia de la semana |
| Tasa de completitud por modo | PRO | Para que el usuario descubra cual tecnica le funciona mejor |
| Logros (Achievements) | FREE | 6 tipos de insignia: Primera Sesion, Racha Semanal, Maestro Pomodoro, Deep Diver, Club del Centenario, Madrugador |
| Weekly Review | PRO | Comparacion semanal: horas de focus, distribucion de modos, tareas, streaks. Flechas de tendencia vs semana anterior |
| Monthly Review | PRO | Revision mensual con tendencias a largo plazo y patrones de productividad |
| AI Productivity Reports | PRO | Reportes generados por IA on-device, sin enviar datos a la nube |

#### Implementacion de AI Reports por plataforma

- **[iOS]**: Apple Foundation Models (iOS 26+). Si el dispositivo no soporta Foundation Models, fallback a plantillas predefinidas con datos interpolados.
- **[Android]**: ML on-device (Gemini Nano / plantillas inteligentes). Fallback a plantillas con datos interpolados si ML no esta disponible.

---

### Widgets [Todas]

Multiples widgets para interactuar con Pepinillo sin abrir la app.

#### Widgets de Home Screen

| Tamano | Contenido | Tier |
|--------|-----------|------|
| Small (S) | Timer activo o progreso diario | FREE |
| Medium (M) | Timer + top 3 tareas del dia | PRO |
| Large (L) | Timer + tareas + stats diarios por modo | PRO |

**Implementacion:**
- **[iOS]**: WidgetKit con Timeline Provider. Soporte para interactividad (iOS 17+).
- **[Android]**: Glance Compose (Jetpack). No RemoteViews legacy.

#### Widget de Lock Screen

- **[iOS]**: WidgetKit Lock Screen widgets (circular, rectangular, inline)
- **[Android]**: Glance widget con categoria `KEYGUARD` (API 33+, Android 13+)

**Tier:** Widget basico de timer = FREE. Widgets adicionales = PRO.

---

### Notificaciones [Todas]

| Tipo | Detalle | Tier |
|------|---------|------|
| Transicion de fase | Alerta cuando termina work/break en Pomodoro, cuando se sugiere break en Flowtime | FREE |
| Recordatorio diario | Notificacion configurable para recordar iniciar una sesion | FREE |
| Sesion completada | Celebracion y resumen al terminar una sesion | FREE |
| Acciones desde notificacion | Pausar/Reanudar/Detener directamente desde la notificacion sin abrir la app | FREE |

**Implementacion de acciones:**
- **[Android]**: Botones de accion en la notificacion del Foreground Service (pause, skip, stop)
- **[iOS]**: `UNNotificationAction` con categorias registradas. Acciones procesadas via `UNUserNotificationCenterDelegate`.

---

### Live Activity / Notificacion Persistente

Indicador visual permanente del timer activo fuera de la app.

#### [iOS] — Live Activity + Dynamic Island

- **ActivityKit** para crear y actualizar Live Activities
- **Dynamic Island**: vista compacta (icono de modo + countdown), vista expandida (modo, tarea, progreso, controles)
- Muestra: countdown, icono de modo, nombre de tarea, barra de progreso
- Quick actions: pausar, skip, detener
- Funciona para los 4 modos de enfoque
- **Tier:** FREE

#### [Android] — Notificacion Foreground Persistente

- Notificacion ongoing vinculada al Foreground Service
- Muestra: countdown, modo activo, nombre de tarea
- Botones de accion: pausar/reanudar, skip, detener
- Prioridad `FOREGROUND_SERVICE_IMMEDIATE` para visibilidad
- Custom layout con progress bar
- **Tier:** FREE

---

### Reloj Inteligente

#### [watchOS] — Apple Watch Companion App

App completa e independiente para Apple Watch:

| Feature | Detalle | Tier |
|---------|---------|------|
| Timer | Iniciar cualquier modo de enfoque desde el reloj | PRO |
| Seleccion de modo | Elegir entre los 4 modos de enfoque | PRO |
| Lista de tareas | Ver tareas del dia, marcar como completadas | PRO |
| Dashboard | Stats del dia: horas de focus, sesiones, racha | PRO |
| Haptics | Feedback haptico al terminar sesion, transiciones de fase | PRO |
| Complications | Enhanced: circular uses actual progress, corner uses live countdown, rectangular shows live countdown + phase + linked task. Smart Stack relevance (score 100 active, 10 idle). 5-min refresh when active (15-min idle). | PRO |
| Sync | Comunicacion bidireccional con iPhone via WatchConnectivity | PRO |

#### [Wear OS] — Wear OS Companion App

App completa para Wear OS:

| Feature | Detalle | Tier |
|---------|---------|------|
| Timer | Iniciar/pausar/detener sesiones de enfoque | PRO |
| Seleccion de modo | Los 4 modos de enfoque disponibles | PRO |
| Lista de tareas | Tareas del dia con mark-complete | PRO |
| Stats | Resumen diario de focus time y sesiones | PRO |
| Focus Timer Tile | Enhanced tile with progress arc (colored by mode), timer display, phase label, session counter, linked task name. Distinct idle/running/paused states. Built with Tiles 1.4.1 + ProtoLayout Material 1.2.1. | PRO |
| Tasks Tile | Second tile showing top 4 tasks with energy emoji, truncated title, pomodoro progress, and completed/total header. | PRO |
| Complication | Datos de focus en watch face | PRO |
| Sync | DataLayer API para comunicacion con phone | PRO |

---

### Asistente de Voz

#### [iOS] — Siri Shortcuts + App Intents

- Framework: **App Intents** (iOS 16+) para integracion nativa con Siri y Shortcuts
- Comandos soportados:
  - "Inicia deep work en Pepinillo"
  - "Inicia un Pomodoro"
  - "Cuanto me enfoque hoy?"
  - "Empieza a trabajar en [tarea]"
  - "Pausa mi sesion"
  - "Dame mi reporte semanal"
  - "Que modo me recomiendas?"
- **3 idiomas**: EN, ES, PT
- Shortcuts personalizables por el usuario en la app Shortcuts
- **Tier:** FREE

#### [Android] — Google Assistant App Actions

- Framework: **App Actions** con `actions.xml`
- Comandos soportados equivalentes a iOS
- Built-in intents (BII) para productividad
- **3 idiomas**: EN, ES, PT
- **Tier:** FREE

---

### Sincronizacion

#### [iOS] — CloudKit

- **CloudKit private database** para sincronizacion automatica entre iPhone, iPad, Mac
- Estrategia de merge: **last-write-wins** con timestamps
- Offline-first: todos los datos se guardan localmente primero (SwiftData), sync es oportunista
- Entidades sincronizadas: tareas, sesiones de focus, preferencias, streaks, logros
- **Tier:** PRO

#### [Android] — Backend REST API + Room

- **Go backend** con API REST para sync de datos
- **Room** como base de datos local con dirty-flag pattern
- **WorkManager** para sync en background (respeta Doze mode y battery optimization)
- Offline-first: Room es la fuente de verdad, sync al reconectar
- Entidades sincronizadas: mismas que iOS
- **Tier:** PRO

---

### Temas y Diseno

#### Temas disponibles [Todas]

| Tema | Tier |
|------|------|
| Classic (Default) | FREE |
| Forest | PRO |
| Ocean | PRO |
| Sunset | PRO |

#### Theme Picker [Todas]

- Selector de tema con **horizontal scroll cards** mostrando preview de cada tema
- Colores de modo de enfoque consistentes en todos los temas: Pomodoro=rojo, Time Block=morado, Chrono=verde
- **[Android]**: Incluye una opcion adicional **Material You** (dynamic colors basados en wallpaper)
- **[iOS]**: Integrado en la pantalla de Settings
- **[Wear OS]**: El tema seleccionado en el telefono Android se sincroniza automaticamente al reloj via Data Layer API
- **Tier:** FREE (Classic) / PRO (Forest, Ocean, Sunset)

#### Modos de apariencia [Todas]

- **[iOS]**: Selector de apariencia Light / Dark / System en la pantalla de Settings
- **[Android]**: Seguir tema del sistema (Dark/Light automatico)
- **Tier:** FREE

#### Efectos especificos por plataforma

- **[iOS]**: Soporte para **Liquid Glass** (iOS 26) como tema premium adicional. Efectos de glassmorphism en componentes de UI.
- **[Android]**: **Material You** dynamic colors como opcion adicional junto a los 4 temas nombrados. Material 3 theming system.

---

### Localizacion [Todas]

3 idiomas completos en todas las plataformas:

| Idioma | Codigo |
|--------|--------|
| Ingles | EN |
| Espanol | ES |
| Portugues | PT |

**Implementacion:**
- **[iOS]**: `.xcstrings` (String Catalogs de Xcode). Frases de Siri localizadas.
- **[Android]**: `strings.xml` con directorios `values/`, `values-es/`, `values-pt/`. App Actions localizadas.

**Tier:** FREE

---

### Onboarding [Todas]

Flujo de primera ejecucion para introducir al usuario a Pepinillo.

| Pantalla | Contenido |
|----------|-----------|
| 1. Bienvenida | Branding, propuesta de valor |
| 2. Modos de enfoque | Explicacion visual de los 4 modos |
| 3. Seleccion de modo por defecto | El usuario elige su modo preferido |
| 4. Configuracion | Duraciones, permisos (notificaciones, Health) |
| 5. Inicio | Listo para empezar |

- **[Android]**: 5 pantallas con onboarding interactivo
- **[iOS]**: 3-4 pantallas con setup de permisos incluido

**Tier:** FREE

---

### Soporte Offline [Todas]

- Arquitectura **offline-first** en ambas plataformas
- 100% funcional sin conexion a internet
- Todos los datos se guardan localmente primero:
  - **[iOS]**: SwiftData (local) -> CloudKit (sync)
  - **[Android]**: Room (local) -> Backend API (sync)
- Cambios se encolan y sincronizan automaticamente al recuperar conexion
- Sin degradacion de funcionalidad offline (timer, tareas, analytics locales)

**Tier:** FREE

---

## P1 — Nice-to-Have (Deseable)

### Soundscapes / Sonidos Ambientales [Todas]

Sonidos de fondo durante sesiones de enfoque. Se reproducen automaticamente al iniciar sesion y pausan durante breaks.

#### Catalogo de sonidos

| Soundscape | Tier |
|------------|------|
| Rain (Lluvia) | FREE |
| Forest (Bosque) | FREE |
| Cafe | FREE |
| White Noise (Ruido Blanco) | FREE |
| Binaural Beats | PRO |
| Lo-fi | PRO |
| Ocean (Oceano) | PRO |
| Fireplace (Chimenea) | PRO |

**Total:** 4 gratis, 8 con PRO.

**Implementacion:**
- **[iOS]**: `AVAudioEngine` con actor pattern para thread-safety. Crossfade entre reproduccion y pausa.
- **[Android]**: Media3 / ExoPlayer para reproduccion eficiente. Audio focus management.

---

### Mode Intelligence [Todas]

Analisis historico de sesiones para sugerir el mejor modo de enfoque por tipo de tarea.

- Requiere 2+ semanas de datos para activarse
- Sugiere modo cuando la confianza es >70%
- Ejemplo: "Completas 80% mas tareas de escritura con Flowtime. Quieres probarlo para el blog de hoy?"
- Banner no intrusivo en la pantalla de focus al seleccionar tarea

**Tier:** PRO

---

### Streaks y Logros [Todas]

#### Streaks (Rachas)

- Dias consecutivos con al menos 1 sesion completada
- Milestones en: 7, 30, 100, 365 dias
- Streak Protection: 1 skip gratis por semana (PRO)
- Animaciones de celebracion al alcanzar milestones

#### Logros (Achievements)

| Logro | Criterio |
|-------|----------|
| Primera Sesion | Completar la primera sesion de focus |
| Racha Semanal | 7 dias consecutivos |
| Maestro Pomodoro | 100 sesiones Pomodoro completadas |
| Deep Diver | 10 horas acumuladas en Flowtime |
| Club del Centenario | 100 sesiones totales |
| Madrugador (Early Bird) | 10 sesiones iniciadas antes de las 7 AM |

- Scroll horizontal en la vista de Analytics
- Indicador de progreso hacia cada logro

**Tier:** FREE (streaks basicos), PRO (streak protection, logros avanzados)

---

### Integracion Salud

#### [iOS] — Apple Health (HealthKit)

- Escribe `HKCategorySample` como **Mindful Minutes** por cada sesion completada
- Lectura de datos de sueno para sugerir ventanas optimas de enfoque (futuro)
- Requiere permiso del usuario

#### [Android] — Health Connect

- Escribe `MindfulnessSessionRecord` por cada sesion completada
- API de Health Connect (Android 14+)
- Requiere permiso del usuario

**Tier:** PRO

---

### Control Rapido

#### [iOS] — Control Center Widget

- Widget para Control Center (iOS 18+)
- Quick-start de sesion de enfoque sin abrir la app
- Muestra estado actual (idle / en sesion)

#### [Android] — Quick Settings Tile

- `TileService` en el panel de notificaciones
- Toggle rapido start/stop de sesion
- Indicador visual del estado actual

**Tier:** FREE

---

### Importar Tareas

#### [iOS] — Apple Reminders

- Importacion one-way via **EventKit**
- Seleccionar lista de Reminders -> importar como tareas de Pepinillo
- No sync bidireccional

#### [Android] — Google Tasks

- Importacion via **OAuth** + Google Tasks API
- Seleccionar lista -> importar tareas
- No sync bidireccional

**Tier:** PRO

---

### Integracion Calendario

#### [iOS] — Apple Calendar (EventKit)

- Bloquear tiempo de focus en el calendario nativo
- Leer eventos existentes para sugerir slots disponibles
- Visualizar sesiones pasadas como eventos

#### [Android] — Google Calendar

- **Google Calendar API** + content provider
- Misma funcionalidad: bloquear tiempo, leer eventos, sugerir slots
- Paridad con la integracion de Apple Calendar

**Tier:** PRO

---

### Modos de Concentracion del Sistema

#### [iOS] — Focus Modes (Apple Focus Filters)

- **FocusFilterIntent** para activar automaticamente un Focus Mode del sistema al iniciar sesion
- El usuario vincula un modo de enfoque de Pepinillo con un Focus Mode de iOS
- Silencia notificaciones contextualmente

#### [Android] — DND / Focus Mode

- Integracion con **Digital Wellbeing Focus Mode** API
- Activar Do Not Disturb automaticamente al iniciar sesion
- Restaurar estado previo al terminar

**Tier:** PRO

---

### Suscripcion / Billing

#### [iOS] — RevenueCat SDK v5+

- RevenueCat SDK v5+ wrapping StoreKit 2 nativo
- Productos: Monthly, Annual, Lifetime
- iOS Public API Key: `appl_xnChlVXXtUFhusIfJyNrNDcMGLj`
- Entitlement: `pro` (unified as `premium` in backend)
- Verificacion server-side via backend Go + RevenueCat
- Restore purchases nativo
- Grace period: 3 dias soportado

#### [Android] — RevenueCat Purchases SDK v8.10.0 ✅ NEW

- RevenueCat Purchases SDK v8.10.0
- Productos: Monthly, Annual, Lifetime
  - com.pepinillo.app.pro.monthly
  - com.pepinillo.app.pro.annual
  - com.pepinillo.app.pro.lifetime
- Android Public API Key: `goog_ITPYSPEdubAzAeoNGxezZuZJELT`
- Entitlement: `premium` (unified with iOS)
- Verificacion server-side via backend Go + RevenueCat
- Grace period: 3 dias soportado
- **Cross-platform parity ACHIEVED:** Both iOS and Android now use RevenueCat

#### Precios

| Plan | Global (US/EU) | LATAM (MX/CO/AR/BR/CL/PE) |
|------|----------------|----------------------------|
| Monthly | $3.99/mes | $1.99/mes |
| Annual | $24.99/ano (~$2.08/mes, 48% ahorro) | $12.99/ano (~$1.08/mes) |
| Lifetime | $49.99 | $29.99 |

---

### Perfil de Usuario [Todas]

Pantalla de perfil con informacion de cuenta y estadisticas de productividad.

#### Informacion de cuenta

| Campo | Detalle | Tier |
|-------|---------|------|
| Avatar | Foto de perfil del usuario (de Google/Apple o personalizada) | FREE |
| Nombre y email | Datos basicos de la cuenta | FREE |
| Tipo de cuenta | Free o Pro (con tier: mensual/anual/lifetime + fecha de expiracion) | FREE |
| Cuentas vinculadas | Proveedores conectados (Google, Apple, email/password) | FREE |

#### Estadisticas del perfil

| Estadistica | Detalle | Tier |
|-------------|---------|------|
| Racha actual | Dias consecutivos con al menos 1 sesion | FREE |
| Racha mas larga | Record historico de dias consecutivos | FREE |
| Horas totales de enfoque | Suma acumulada de todas las sesiones | FREE |
| Sesiones totales | Numero total de sesiones completadas | FREE |
| Tareas completadas | Numero total de tareas marcadas como completadas | FREE |
| Miembro desde | Fecha de registro de la cuenta | FREE |

**Implementacion:**
- **[iOS]**: Pantalla SwiftUI con datos de perfil del backend + estadisticas locales/sincronizadas
- **[Android]**: Pantalla Compose con Circuit presenter, datos del backend via Ktor

---

### Login Social [Todas]

Autenticacion con proveedores sociales ademas de email/password.

#### Proveedores

| Proveedor | Plataforma | Implementacion | Tier |
|-----------|-----------|----------------|------|
| Google Sign-In | **[Android]** | Credential Manager API (reemplaza play-services-auth legacy) | FREE |
| Sign In with Apple | **[iOS]** | AuthenticationServices framework (nativo) | FREE |
| Email / Password | **[Todas]** | JWT via backend Go (ya implementado) | FREE |

#### Account Linking

- Conectar multiples proveedores a una misma cuenta (ej. Google + Apple + email)
- Permite al usuario acceder desde cualquier dispositivo con cualquier proveedor vinculado
- El backend es la fuente de verdad para la identidad del usuario
- **Tier:** FREE

---

### Cloud Sync y Multi-Dispositivo [Todas]

Sincronizacion bidireccional de datos entre dispositivos via backend Go.

#### Datos sincronizados

| Entidad | Direccion | Resolucion de conflictos |
|---------|-----------|--------------------------|
| Tareas | Bidireccional | last-write-wins por `updatedAt` |
| Sesiones de enfoque | Bidireccional | last-write-wins por `updatedAt` |
| Estadisticas | Bidireccional | Merge aditivo |
| Preferencias | Bidireccional | last-write-wins por `updatedAt` |

#### Mecanismos de sync

| Mecanismo | Uso | Detalle |
|-----------|-----|---------|
| WebSocket | Real-time | Notificacion instantanea de cambios entre dispositivos conectados |
| REST API periodico | Fallback | WorkManager (Android) / BackgroundTasks (iOS) cada 15 min |
| Dirty flags | Offline | Cambios locales se marcan como pendientes y se envian al reconectar |

#### Multi-dispositivo

- Misma cuenta en multiples dispositivos (phone + watch + tablet) se mantiene sincronizada
- El backend coordina el estado entre dispositivos
- Offline-first: cada dispositivo funciona independientemente, sync al reconectar

**Implementacion:**
- **[Android]**: SyncEngine + Room dirty flags + WorkManager (ya existe, necesita mejoras WebSocket)
- **[iOS]**: Nuevo API client Ktor/URLSession, reemplaza CloudKit como fuente de sync principal

**Tier:** PRO

---

### Suscripciones Cross-Platform [Todas]

Pagar en cualquier tienda (App Store o Google Play) y obtener PRO en todas las plataformas.

#### Flujo

1. Usuario compra suscripcion en App Store o Google Play
2. El cliente envia el recibo al backend Go (`/api/v1/billing/verify`)
3. El backend verifica el recibo con la tienda correspondiente (Apple App Store Server API / Google Play Developer API)
4. El backend actualiza el estado de suscripcion del usuario
5. Todos los dispositivos del usuario reciben el estado PRO al sincronizar

#### Arquitectura

| Componente | Detalle |
|------------|---------|
| Fuente de verdad | Backend Go (no el dispositivo local) |
| Verificacion Apple | App Store Server API v2 (server-to-server) |
| Verificacion Google | Google Play Developer API (server-to-server) |
| Grace period | 3 dias antes de revocar acceso tras fallo de renovacion |
| Polling | El cliente consulta estado de suscripcion al iniciar app y periodicamente |

**Tier:** — (infraestructura de billing)

---

## P2 — Futuro

| Feature | Plataforma | Descripcion |
|---------|-----------|-------------|
| AI Insights Avanzados | [Todas] | Predecir ventanas productivas, sugerir programacion de tareas, detectar patrones de burnout |
| Social Accountability | [Todas] | Sesiones de focus compartidas con un partner. CloudKit shared zones (iOS) / Backend (Android) |
| Export CSV/PDF | [Todas] | Exportar datos de productividad en formatos estandar |
| Apple Vision Pro | [iOS] | Entorno inmersivo de focus con SwiftUI multiplatform |
| Handoff entre dispositivos | [iOS] | `NSUserActivity` para continuar sesion entre iPhone/iPad/Mac sin interrupciones |
| Shortcuts Automation | [iOS] | Workflows complejos: "Cuando llegue a la biblioteca, iniciar Pomodoro" via Shortcuts |
| Cross-platform Sync | [Todas] | Sincronizacion iOS <-> Android via backend Go compartido |
| Pomodoro -> Flowtime auto-switch | [Todas] | Si el usuario consistentemente salta breaks de Pomodoro, sugerir cambiar a Flowtime |
| Tablet optimizado | [Android] | Samsung tablets, split-screen productivity, layouts adaptativos para foldables |

---

## Tabla de Paridad de Features

### Leyenda

| Simbolo | Significado |
|---------|-------------|
| ✅ | Implementado |
| 🔄 | En progreso |
| ⬜ | Pendiente |
| ➖ | No aplica (N/A) |

### P0 — Must-Have

| Feature | iOS | Android | watchOS | Wear OS | Tier |
|---------|-----|---------|---------|---------|------|
| **Motor de Enfoque** | | | | | |
| Pomodoro mode | ✅ | ✅ | ⬜ | ✅ | FREE |
| Flowtime mode | ✅ | ✅ | ⬜ | ✅ | PRO |
| Time Block mode | ✅ | ✅ | ⬜ | ✅ | PRO |
| Stopwatch/Chrono mode | ✅ | ✅ | ⬜ | ✅ | FREE |
| Strategy pattern engine | ✅ | ✅ | ⬜ | ✅ | — |
| Background timer survival | ✅ | ✅ | ⬜ | ⬜ | FREE |
| Pause/Resume tracking | ✅ | ✅ | ⬜ | ✅ | FREE |
| Session journaling | ✅ | ✅ | ➖ | ➖ | FREE |
| **Gestion de Tareas** | | | | | |
| CRUD de tareas | ✅ | ✅ | ⬜ | ✅ | FREE |
| Drag-to-reorder | ✅ | ✅ | ➖ | ➖ | FREE |
| Subtareas | ✅ | ✅ | ➖ | ➖ | PRO |
| Prioridad (none/low/med/high) | ✅ | ✅ | ➖ | ➖ | FREE |
| Niveles de energia | ✅ | ✅ | ➖ | ➖ | FREE |
| Pomodoros estimados/completados | ✅ | ✅ | ➖ | ➖ | FREE |
| Vincular tarea a sesion | ✅ | ✅ | ⬜ | ⬜ | FREE |
| Tareas recurrentes | ✅ | ✅ | ➖ | ➖ | PRO |
| **Analytics y Dashboard** | | | | | |
| Resumen diario (7 dias) | ✅ | ✅ | ⬜ | ✅ | FREE |
| Vista 30 dias | ✅ | ✅ | ➖ | ➖ | PRO |
| Vista 1 ano | ✅ | ✅ | ➖ | ➖ | PRO |
| Desglose por modo (charts) | ✅ | ✅ | ➖ | ➖ | PRO |
| Achievements (6 tipos) | ✅ | ✅ | ➖ | ➖ | FREE |
| Weekly Review | ✅ | ✅ | ➖ | ➖ | PRO |
| Monthly Review | ✅ | ✅ | ➖ | ➖ | PRO |
| AI Productivity Reports | 🔄 | 🔄 | ➖ | ➖ | PRO |
| **Widgets** | | | | | |
| Home Screen — Small | ✅ | ⬜ | ➖ | ➖ | FREE |
| Home Screen — Medium | ✅ | ⬜ | ➖ | ➖ | PRO |
| Home Screen — Large | ✅ | ⬜ | ➖ | ➖ | PRO |
| Lock Screen widget | ✅ | ⬜ | ➖ | ➖ | FREE |
| **Notificaciones** | | | | | |
| Transicion de fase | ✅ | ✅ | ✅ | ✅ | FREE |
| Recordatorio diario | ✅ | ✅ | ➖ | ➖ | FREE |
| Sesion completada | ✅ | ✅ | ✅ | ✅ | FREE |
| Acciones desde notificacion | ✅ | ✅ | ➖ | ➖ | FREE |
| **Live Activity / Notif. Persistente** | | | | | |
| Dynamic Island + Live Activity | ✅ | ➖ | ➖ | ➖ | FREE |
| Foreground notification con progreso | ➖ | ✅ | ➖ | ➖ | FREE |
| **Reloj Inteligente** | | | | | |
| Timer en reloj | ⬜ | ➖ | ⬜ | ✅ | PRO |
| Seleccion de modo | ⬜ | ➖ | ⬜ | ✅ | PRO |
| Lista de tareas en reloj | ⬜ | ➖ | ⬜ | ✅ | PRO |
| Dashboard/Stats en reloj | ⬜ | ➖ | ⬜ | ✅ | PRO |
| Complications (enhanced) | ⬜ | ➖ | ✅ | ✅ | PRO |
| Focus Timer Tile (enhanced) | ➖ | ➖ | ➖ | ✅ | PRO |
| Tasks Tile | ➖ | ➖ | ➖ | ✅ | PRO |
| Haptics en reloj | ⬜ | ➖ | ⬜ | ⬜ | PRO |
| **Asistente de Voz** | | | | | |
| Siri Shortcuts + App Intents | ✅ | ➖ | ➖ | ➖ | FREE |
| Google Assistant App Actions | ➖ | ⬜ | ➖ | ➖ | FREE |
| **Sincronizacion** | | | | | |
| CloudKit sync | ✅ | ➖ | ✅ | ➖ | PRO |
| Backend REST API + Room sync | ➖ | 🔄 | ➖ | 🔄 | PRO |
| **Temas y Diseno** | | | | | |
| Classic theme | ✅ | ✅ | ✅ | ✅ | FREE |
| Forest / Ocean / Sunset | ✅ | ✅ | ⬜ | ✅ | PRO |
| Theme picker (horizontal scroll cards) | ✅ | ✅ | ➖ | ➖ | FREE |
| Liquid Glass (iOS 26) | ⬜ | ➖ | ⬜ | ➖ | PRO |
| Material You dynamic colors | ➖ | ✅ | ➖ | ✅ | FREE |
| Light/Dark/System appearance selector | ✅ | ✅ | ✅ | ✅ | FREE |
| Focus mode colors (red/purple/green) | ✅ | ✅ | ✅ | ✅ | FREE |
| Theme sync phone -> watch | ➖ | ➖ | ✅ | ✅ | FREE |
| Glassmorphism effects | ✅ | ✅ | ➖ | ➖ | FREE |
| **Localizacion** | | | | | |
| Ingles (EN) | ✅ | ✅ | ⬜ | ⬜ | FREE |
| Espanol (ES) | ✅ | ✅ | ⬜ | ⬜ | FREE |
| Portugues (PT) | ✅ | ✅ | ⬜ | ⬜ | FREE |
| **Onboarding** | | | | | |
| Flujo de primera ejecucion | ✅ | ✅ | ➖ | ➖ | FREE |
| Seleccion de modo por defecto | ✅ | ✅ | ➖ | ➖ | FREE |
| Solicitud de permisos | ✅ | ✅ | ➖ | ➖ | FREE |
| **Soporte Offline** | | | | | |
| Offline-first architecture | ✅ | ✅ | ⬜ | ✅ | FREE |

### P1 — Nice-to-Have

| Feature | iOS | Android | watchOS | Wear OS | Tier |
|---------|-----|---------|---------|---------|------|
| Soundscapes (4 basicos) | ✅ | ⬜ | ➖ | ➖ | FREE |
| Soundscapes (8 total) | ✅ | ⬜ | ➖ | ➖ | PRO |
| Mode Intelligence | ✅ | ⬜ | ➖ | ➖ | PRO |
| Streaks (rachas) | ✅ | ✅ | ⬜ | ⬜ | FREE |
| Streak Protection (1 skip/semana) | ⬜ | ⬜ | ➖ | ➖ | PRO |
| Apple Health (Mindful Minutes) | ⬜ | ➖ | ➖ | ➖ | PRO |
| Health Connect (Mindful Minutes) | ➖ | ⬜ | ➖ | ➖ | PRO |
| Control Center widget (iOS 18+) | ✅ | ➖ | ➖ | ➖ | FREE |
| Quick Settings Tile | ➖ | ⬜ | ➖ | ➖ | FREE |
| Apple Reminders import | ⬜ | ➖ | ➖ | ➖ | PRO |
| Google Tasks import | ➖ | ⬜ | ➖ | ➖ | PRO |
| Apple Calendar integration | ✅ | ➖ | ➖ | ➖ | PRO |
| Google Calendar integration | ➖ | ✅ | ➖ | ➖ | PRO |
| Focus Modes (FocusFilterIntent) | ⬜ | ➖ | ➖ | ➖ | PRO |
| DND / Focus Mode API | ➖ | ⬜ | ➖ | ➖ | PRO |
| StoreKit 2 subscriptions | ✅ | ➖ | ➖ | ➖ | — |
| Google Play Billing 7 | ➖ | 🔄 | ➖ | ➖ | — |

### P2 — Futuro

| Feature | iOS | Android | watchOS | Wear OS | Tier |
|---------|-----|---------|---------|---------|------|
| AI Insights avanzados | ⬜ | ⬜ | ➖ | ➖ | PRO |
| Social Accountability | ⬜ | ⬜ | ➖ | ➖ | PRO |
| Export CSV/PDF | ⬜ | ⬜ | ➖ | ➖ | PRO |
| Apple Vision Pro | ⬜ | ➖ | ➖ | ➖ | PRO |
| Handoff entre dispositivos | ⬜ | ➖ | ⬜ | ➖ | PRO |
| Shortcuts automation | ⬜ | ➖ | ➖ | ➖ | PRO |
| Cross-platform sync (iOS <-> Android) | ⬜ | ⬜ | ⬜ | ⬜ | PRO |
| Pomodoro -> Flowtime auto-switch | ⬜ | ⬜ | ➖ | ➖ | PRO |
| Tablet/Foldable optimizado | ➖ | ⬜ | ➖ | ➖ | FREE |

### Planificadas — Backend y Cuentas

| Feature | iOS | Android | watchOS | Wear OS | Tier |
|---------|-----|---------|---------|---------|------|
| **Perfil de Usuario** | | | | | |
| Pantalla de perfil (avatar, nombre, tipo cuenta) | ⬜ | ⬜ | ➖ | ➖ | FREE |
| Estadisticas del perfil (streak, horas, sesiones) | ⬜ | ⬜ | ➖ | ➖ | FREE |
| Cuentas vinculadas (Google/Apple/email) | ⬜ | ⬜ | ➖ | ➖ | FREE |
| **Login Social** | | | | | |
| Google Sign-In (Credential Manager) | ➖ | ⬜ | ➖ | ➖ | FREE |
| Sign In with Apple | ⬜ | ➖ | ➖ | ➖ | FREE |
| Account linking (multiples proveedores) | ⬜ | ⬜ | ➖ | ➖ | FREE |
| **Cloud Sync y Multi-Dispositivo** | | | | | |
| Sync bidireccional via backend Go | ⬜ | 🔄 | ⬜ | 🔄 | PRO |
| WebSocket real-time sync | ⬜ | ⬜ | ⬜ | ⬜ | PRO |
| Multi-device coordination | ⬜ | ⬜ | ⬜ | ⬜ | PRO |
| **Suscripciones Cross-Platform** | | | | | |
| Verificacion server-side de recibos | ⬜ | ⬜ | ➖ | ➖ | — |
| PRO status compartido entre tiendas | ⬜ | ⬜ | ⬜ | ⬜ | — |

---

## Resumen de Conteo de Features

| Categoria | Total | Implementadas (al menos 1 plataforma) | Pendientes |
|-----------|-------|----------------------------------------|------------|
| P0 — Must-Have | 52 | 38 | 14 |
| P1 — Nice-to-Have | 17 | 8 | 9 |
| Planificadas — Backend y Cuentas | 12 | 0 | 12 |
| P2 — Futuro | 9 | 0 | 9 |
| **Total** | **90** | **46** | **44** |

---

## Notas de Paridad Cross-Platform

1. **Wear OS y watchOS tiles/widgets enhanced**: Wear OS now has two rich tiles (Focus Timer with progress arc + Tasks with top 4 tasks) and enhanced complications. watchOS Smart Stack widgets redesigned with live countdowns, phase info, linked task names, and smart relevance scoring. Both platforms persist extended snapshot data (linked task, session count, theme colors, phase dates) for tile/widget access.

2. **iOS esta adelantado en ecosistema**: Widgets, Live Activity, Siri, Calendar, Control Center, Mode Intelligence, y Soundscapes ya estan implementados en iOS. Android tiene pendientes en widgets, Quick Settings, Assistant, y Soundscapes.

3. **Android tiene Paywall en progreso**: PaywallScreen y PaywallViewModel existen pero el feature gating completo aun no esta enforcement.

4. **Feature gating inconsistente en iOS**: Segun el analisis del PLAN_FREE_PRO_TIERS, varias features anunciadas como PRO en el paywall de iOS no estan realmente gateadas (analytics >7 dias, sync, widgets, temas, subtareas, recurrencia). Requiere alineacion.

6. **Theme parity achieved**: Ambas plataformas (Android + iOS) tienen 4 temas nombrados (Classic, Forest, Ocean, Sunset) con theme picker de horizontal scroll cards, colores de modo de enfoque consistentes (Pomodoro=rojo, TimeBlock=morado, Chrono=verde), y PRO gating para Forest/Ocean/Sunset. Android ademas ofrece Material You como opcion. iOS tiene selector Light/Dark/System. Wear OS sincroniza el tema seleccionado desde el telefono Android.

5. **Session Journaling promovido a P0**: Originalmente P2 en iOS PRD, ahora implementado en ambas plataformas phone como parte del motor de enfoque.

7. **Backend Go existente pero no desplegado**: El backend en `backend/` implementa API REST completa (auth, tasks, sessions, stats, billing verify, push notifications, WebSocket, AI insights) pero aun no esta en produccion. Necesita hosting (Railway/Fly.io/VPS) + PostgreSQL + Redis.

8. **Login social planificado**: Google Sign-In (Android via Credential Manager) y Sign In with Apple (iOS via AuthenticationServices) estan planificados. El backend necesita agregar OAuth providers. Account linking permitira conectar multiples proveedores a una cuenta.

9. **Cloud sync unificado planificado**: Actualmente iOS usa CloudKit y Android usa backend Go. El plan es migrar ambas plataformas a sync via backend Go para habilitar cross-platform sync y suscripciones compartidas.
