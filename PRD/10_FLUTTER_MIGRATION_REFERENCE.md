# Referencia de Migracion: Flutter a Plataformas Nativas

**Referencia unificada de migracion desde Flutter hacia iOS nativo y Android nativo.**

---

## 1. Inventario del Flutter Original

| Componente | Cantidad |
|------------|----------|
| Providers (state management) | 13 |
| Screens | 15 |
| Entidades de dominio | 6 (+modelos de soporte) |
| Servicios Firebase | 4 (Auth, Firestore, Storage, Crashlytics) |
| Monetizacion | RevenueCat (`purchases_flutter`) |
| Keys de localizacion (EN) | ~644 |
| Keys de localizacion (ES) | ~310 |
| Keys de localizacion (PT) | ~310 |
| Dependencias totales | 30+ |

### Providers Flutter

| Provider | Responsabilidad |
|----------|----------------|
| SessionProvider | Sesion de usuario, estado de suscripcion RevenueCat, CRUD de perfil, upload de imagen, eliminacion de cuenta, sign-out |
| AuthenticationProvider | Estado de formularios sign-in/sign-up (nombre, email, fecha nacimiento, password, username) |
| ThemeProvider | Seleccion de tema, Material 3 dynamic colors, gating de temas premium (4 gratis, resto premium) |
| DynamicColorProvider | Wrapper de generacion de colores dinamicos Material 3 |
| PomodoroProvider | Configuracion del timer (duraciones work/break/rest, cantidad, meta diaria, auto-advance), persistencia de estado |
| PomodoroDashboardProvider | Carga de stats diarios/rango de fechas, paleta de colores para graficos |
| ProductivityInsightsProvider | Analytics avanzados: heatmap 90 dias, rachas, comparacion semanal, dia mas productivo, prediccion de productividad |
| TimerProvider | Toggle modo countdown vs stopwatch, persistencia de configuracion |
| CountdownProvider | Timer countdown con configuracion de duracion, wakelock, notificaciones |
| CronometerProvider | Implementacion de cronometro/stopwatch con wakelock |
| TaskProvider | CRUD de tareas, busqueda, filtrado (all/pending/completed/today/overdue), integracion calendario, vista My Day, sync con Firebase |
| TaskDashboardProvider | Analytics de tareas: distribucion, precision Pomodoro (estimado vs completado), velocidad semanal |

### Pantallas Flutter

| Pantalla | Modulo | Funcion |
|----------|--------|---------|
| signin_screen | Auth | Login email/password |
| signup_screen | Auth | Registro (nombre, email, fecha nacimiento, password, username) |
| account_screen | Auth | Vista de perfil con estado de sesion/tareas/Pomodoro |
| edit_user_screen | Auth | Editar perfil (nombre, email, fecha nacimiento) |
| home_screen | Home | Shell principal con navegacion de 3 tabs (Pomodoro, Timer, Tasks) |
| pomodoro_screen | Pomodoro | Display del timer Pomodoro activo con progreso circular |
| pomodoro_dashboard_screen | Pomodoro | Metas diarias, resumen de sesiones, insights de productividad |
| pomodoro_settings_screen | Pomodoro | Configurar duraciones, auto-advance, metas diarias, notificaciones |
| timer_screen | Timer | Countdown/stopwatch con toggle de modo |
| countdown_settings_screen | Timer | Configurar duracion de countdown, toggle de notificacion |
| tasks_screen | Tasks | Lista de tareas con filtros, busqueda, vista calendario |
| task_screen | Tasks | Detalle de tarea individual con subtareas |
| task_dashboard_screen | Tasks | Estadisticas y analytics de tareas |
| theme_settings_screen | Theme | Seleccion de paleta, picker de imagen de fondo, indicadores premium |
| paywall | Store | Ofertas de suscripcion RevenueCat |

### Entidades de Dominio

- **TaskEntity**: id, title, description, createdDate, finishDate, isFinished, priority, category, subTasks (List), updatedAt, estimatedPomodoros, completedPomodoros, focusedSeconds, activeSessionId
- **SubTaskEntity**: id, title, isFinished, taskId
- **PomodoroEntity**: pomodoroTime, breakTime, restTime, qtyPomodoros, dailyGoal, notifications, autoPomodoro, autoBreak, lastUpdate
- **PomodoroSessionEntity**: id, taskId, startedAt, endedAt, phase, durationSeconds, elapsedSeconds, pauseCount, totalPauseSeconds, wasCompleted, sharedWithTaskIds, createdAt
- **PomodoroStatsEntity**: date, pomodoros, pomodoroDuration, breaks, breakDuration, rests, restDuration, dailyGoal, dailyCompleted, count, lastUpdate
- **UserModel**: email, name, uid, subscriptionExpireAt, subscriptionStartDate, imageProfile, birthDate
- **Modelos de soporte**: TimerModel, CountdownModel, ThemeModel

---

## 2. Mapeo Flutter a iOS Nativo

| Flutter | iOS Nativo |
|---------|------------|
| Provider + ChangeNotifier | TCA @Reducer + Store |
| GoRouter | NavigationStack / NavigationSplitView |
| Freezed models | Swift structs / SwiftData @Model |
| SharedPreferences | UserDefaults / @AppStorage / SwiftData |
| sqflite (SQLite) | SwiftData (Core Data por debajo) |
| Firebase Auth | Sign in with Apple |
| Cloud Firestore | CloudKit (via SwiftData) |
| Firebase Storage | CloudKit Assets |
| Firebase Crashlytics | Xcode Organizer / TelemetryDeck |
| RevenueCat | StoreKit 2 (nativo) |
| fl_chart | Swift Charts |
| table_calendar | Calendario SwiftUI custom |
| audioplayers | AVAudioEngine / AVFoundation |
| flutter_intl (ARB) | String Catalog (.xcstrings) |
| connectivity_plus | NWPathMonitor |
| wakelock_plus | UIApplication.shared.isIdleTimerDisabled |
| image_picker | PhotosUI (PHPickerViewController) |
| flutter_local_notifications | UNUserNotificationCenter |
| http | URLSession |
| google_fonts | Fuentes del sistema / fuentes bundled |

---

## 3. Mapeo Flutter a Android Nativo

| Flutter | Android Nativo |
|---------|----------------|
| Provider + ChangeNotifier | ViewModel + StateFlow / Circuit Presenter |
| GoRouter | Navigation Compose / Circuit screens |
| Freezed models | Kotlin data class |
| SharedPreferences | Jetpack DataStore (Proto) |
| sqflite (SQLite) | Room |
| Firebase Auth | JWT + backend Go |
| Cloud Firestore | Room (local) + REST API (remoto) |
| Firebase Storage | Backend upload |
| Firebase Crashlytics | Play Console / Sentry |
| RevenueCat | Google Play Billing 7 |
| fl_chart | Vico (Compose charts) |
| table_calendar | Calendario Compose custom |
| audioplayers | Media3 / ExoPlayer |
| flutter_intl (ARB) | strings.xml (res/values/) |
| connectivity_plus | ConnectivityManager |
| wakelock_plus | WakeLock + Foreground Service |
| image_picker | CameraX / Gallery intent |
| flutter_local_notifications | NotificationCompat + Foreground Service |
| http | Retrofit / Ktor Client |
| google_fonts | Fuentes del sistema / fuentes bundled |

---

## 4. Features Nuevas (No Existian en Flutter)

Las siguientes features son completamente nuevas en las versiones nativas y no tienen equivalente en la app Flutter original:

| # | Feature | Descripcion | Prioridad |
|---|---------|-------------|-----------|
| 1 | Flowtime | Enfoque abierto + descansos dinamicos proporcionales al tiempo trabajado | P0 |
| 2 | Time Block | Bloques de trabajo profundo de duracion fija | P0 |
| 3 | Motor multi-modo | Patron Strategy, 4 modos compartiendo un core engine comun | P0 |
| 4 | Niveles de energia | Categorizacion de tareas (deep/shallow/admin) | P0 |
| 5 | Tareas recurrentes | Generacion automatica diaria/semanal/mensual | P0 |
| 6 | Widgets de Home Screen | Timer y stats de un vistazo (WidgetKit / Glance Compose) | P0 |
| 7 | Live Activity / Notificacion persistente | Visibilidad constante del timer (Dynamic Island en iOS, Foreground Service en Android) | P0 |
| 8 | Watch / Wear OS | App independiente de timer en el reloj + complicaciones | P0 |
| 9 | Siri / Google Assistant | Sesiones de enfoque activadas por voz | P0 |
| 10 | Apple Health / Health Connect | Escritura de Mindful Minutes | P1 |
| 11 | Motor de soundscapes | Sonidos ambientales durante sesiones de enfoque | P1 |
| 12 | Mode Intelligence | Sugerencia de modo basada en IA/patrones | P1 |
| 13 | Weekly / Monthly Review | Analytics comparativos por modo y periodo | P1 |
| 14 | AI Reports | Reportes generados por IA sobre productividad | P1 |
| 15 | Rachas y logros | Tracking de dias consecutivos y gamificacion | P1 |
| 16 | Layouts adaptativos | Soporte para iPad / tablets / pantallas grandes | P1 |
| 17 | Quick Settings Tile (Android) | Toggle de enfoque desde el shade de notificaciones | P0 |
| 18 | Import de Google Tasks | Importacion one-way desde Google Tasks | P1 |

---

## 5. Datos Flutter y Estrategia de Migracion

### Almacenamiento en Flutter

| Dato | Storage Flutter | Formato |
|------|----------------|---------|
| Tareas | SharedPreferences | JSON array (key: `pepinillo_tasks`) |
| Sesiones Pomodoro | SQLite (sqflite) | Tabla `pomodoro_sessions` con indices |
| Stats Pomodoro | SharedPreferences | JSON por fecha (key: `pomodoro_stats_YYYY-MM-DD`) |
| Preferencias de timer | SharedPreferences | Keys individuales |
| Perfil de usuario | Firebase Auth + Firestore | Documento por usuario |
| Imagen de perfil | Firebase Storage | URL remota |

### Estrategia de Migracion de Datos

**No hay migracion automatica.** Las apps nativas son apps nuevas en sus respectivas tiendas.

| Escenario | Solucion |
|-----------|----------|
| Usuario con cuenta Flutter | Backend sync como puente: login en la app nativa sincroniza datos via API |
| Usuario sin cuenta (datos locales) | Datos se pierden al cambiar de app (no hay forma segura de leer datos de otra app) |
| iOS: Import desde Flutter | No aplica (apps separadas en App Store) |
| Android: Import desde Flutter | Boton opcional "Importar desde Pepinillo Classic" que lee SharedPreferences/sqflite del paquete Flutter (si esta instalado) |

### Limitaciones
- Firebase Auth a Sign in with Apple/JWT requiere que el usuario haga login de nuevo.
- Stats historicos pueden tener formato diferente (Pomodoro-only vs multi-modo).
- IDs de subtareas pueden necesitar remapeo.
- No todos los strings Flutter aplican (muchos son Firebase-specific o Flutter-specific).

---

## 6. Strings y Localizacion

### Migracion de Strings

```
Flutter: lib/l10n/intl_en.arb (644 keys)
   |
   +---> iOS:     Localizable.xcstrings (EN)
   +---> Android: res/values/strings.xml

Flutter: lib/l10n/intl_es.arb (310 keys)
   |
   +---> iOS:     Localizable.xcstrings (ES)
   +---> Android: res/values-es/strings.xml

Flutter: lib/l10n/intl_pt.arb (309 keys)
   |
   +---> iOS:     Localizable.xcstrings (PT-BR)
   +---> Android: res/values-pt/strings.xml
```

### Consideraciones
- No todos los strings Flutter aplican -- muchos son para features Firebase-specific o Flutter-specific.
- Solo migrar los strings que aplican a cada plataforma nativa.
- **~100+ strings nuevos** necesarios para features exclusivas nativas:
  - 4 nombres + descripciones de modos de enfoque
  - Nombres de niveles de energia
  - Nombres de presets de recurrencia
  - Labels de widgets
  - Strings de Watch / Wear OS
  - Labels de Quick Settings (Android)
  - Frases de Siri / Google Assistant
  - Permisos de Health / Health Connect
  - Strings de UI de StoreKit / Play Billing
  - Nombres de canales de notificacion

---

## 7. Endpoints del Backend

### Endpoints Existentes

| Endpoint | Metodo | Usado por |
|----------|--------|-----------|
| `/api/v1/auth/register` | POST | Flujo de autenticacion |
| `/api/v1/auth/login` | POST | Flujo de autenticacion |
| `/api/v1/auth/refresh` | POST | Renovacion de token |
| `/api/v1/auth/logout` | POST | Cierre de sesion |
| `/api/v1/users/me` | GET/PUT | Perfil de usuario |
| `/api/v1/users/me/avatar` | POST | Imagen de perfil |
| `/api/v1/tasks` | GET/POST | Sync de tareas |
| `/api/v1/tasks/:id` | PUT/DELETE | Sync de tareas |
| `/api/v1/tasks/:id/subtasks` | GET/POST | Sync de subtareas |
| `/api/v1/pomodoro-sessions` | GET/POST | Sync de sesiones |
| `/api/v1/health` | GET | Health check |

### Endpoints Pendientes de Crear

| Feature | Endpoint Necesario | Estado |
|---------|-------------------|--------|
| Stats diarios | `GET /api/v1/stats/daily?date=...` | Por crear |
| Stats semanales | `GET /api/v1/stats/weekly?week=...` | Por crear |
| Verificacion de suscripcion (iOS) | `POST /api/v1/subscriptions/verify` (App Store receipt) | Por crear |
| Verificacion de suscripcion (Android) | `POST /api/v1/subscriptions/verify` (Play Store receipt) | Por crear |
| Sesiones multi-modo | `POST /api/v1/focus-sessions` (con campo `mode`) | Parcial -- actualizar modelo |

### Endpoints que ya soportan features nuevas
- **Niveles de energia**: campo ya existe en el modelo de tareas.
- **Tareas recurrentes**: campos de recurrence ya existen en tareas (verificar completitud).

---

## 8. Esquema de Base de Datos: Flutter vs Nativo

### Tareas

| Aspecto | Flutter | iOS Nativo | Android Nativo |
|---------|---------|------------|----------------|
| Storage | SharedPreferences (JSON) | SwiftData @Model | Room @Entity |
| ID | Auto-increment int | UUID | String (UUID) |
| Campos nuevos | -- | energyLevel, preferredMode, recurrenceRule | energyLevel, preferredMode, recurrenceRule, syncedAt, isDirty |
| Migraciones | Sin soporte | SwiftData auto-migration | Room auto-migration |
| Sync | Firebase Firestore | CloudKit via SwiftData | REST API custom |

### Sesiones de Enfoque

| Aspecto | Flutter | iOS Nativo | Android Nativo |
|---------|---------|------------|----------------|
| Storage | sqflite | SwiftData @Model | Room @Entity |
| Nombre tabla | pomodoro_sessions | FocusSession | focus_sessions |
| Campo modo | No (solo Pomodoro) | mode (String) | mode (String) |
| Campos nuevos | -- | mode, linkedTaskId | mode, linkedTaskId, syncedAt, isDirty |

---

## 9. Assets y Recursos

### Sonidos
- tick.wav, complete.wav, break_start.wav, session_start.wav
- **Nuevos (nativos):** soundscapes ambientales (lluvia, bosque, cafe, white noise, etc.)

### Fuentes
- Fasthand, Kalam (weights 300, 400, 700)
- Fuentes del sistema como alternativa en nativo.

### Enums Compartidos (mantener paridad)

| Enum | Valores |
|------|---------|
| FocusMode | pomodoro, flowtime, timeBlock, stopwatch |
| FocusPhase | work, shortBreak, longBreak, dynamicBreak |
| TimerStatus | idle, running, paused, completed |
| TaskFilter | all, pending, completed, today, overdue |
| EnergyLevel | deep, shallow, admin |
| SoundType | tick, complete, breakStart, sessionStart |
