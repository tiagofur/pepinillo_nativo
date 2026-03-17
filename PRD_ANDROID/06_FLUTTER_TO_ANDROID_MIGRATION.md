# Guía de Migración: Flutter → Android Nativo

**Versión:** 1.0
**Fecha:** 2026-03-12

---

## 1. Inventario de Features Flutter Actuales

Basado en `PRD_IOS/06_FLUTTER_FEATURE_INVENTORY.md` y análisis del codebase Flutter.

### Features que migran 1:1

| Flutter Feature | Flutter Tech | Android Native Tech |
|----------------|-------------|---------------------|
| Pomodoro timer | `TimerProvider` + `CountdownProvider` | `PomodoroStrategy` + `FocusEngine` |
| Stopwatch | `SessionProvider` | `StopwatchStrategy` + `FocusEngine` |
| Task CRUD | `TaskProvider` + SharedPrefs | `TaskPresenter` + Room |
| Subtasks | `TaskEntity.subtasks` | `SubtaskEntity` (Room relation) |
| Dashboard | `DashboardScreen` + `fl_chart` | `DashboardScreen` + Vico charts |
| Settings | `SettingsScreen` + SharedPrefs | `SettingsPresenter` + DataStore |
| Themes | `ThemeProvider` (custom themes) | Material You (dynamic color) |
| Auth | `AuthenticationProvider` + Firebase | `AuthPresenter` + JWT (Go backend) |
| Cloud sync | `SyncService` + Firestore | `SyncEngine` + REST API |
| Localization | `intl` ARB files (EN/ES/PT) | Android string resources (XML) |
| Profile image | `image_picker` + Firebase Storage | CameraX/Gallery + backend upload |
| Notifications | `flutter_local_notifications` | NotificationCompat + Foreground Service |
| Paywall | `purchases_flutter` (RevenueCat) | Google Play Billing 7 |

### Features NUEVAS (no existen en Flutter)

| Feature | Descripción | Priority |
|---------|-------------|----------|
| Flowtime mode | Open-ended focus + dynamic breaks | P0 |
| Time Block mode | Fixed-duration deep work blocks | P0 |
| Multi-mode engine | Strategy pattern, 4 modes sharing core | P0 |
| Energy levels | Task categorization (deep/shallow/admin) | P0 |
| Recurring tasks | Daily/weekly/monthly auto-generation | P0 |
| Home widgets | Glance Compose (timer + stats) | P0 |
| Ongoing notification | Rich notification with timer controls | P0 |
| Quick Settings Tile | Toggle focus from notification shade | P0 |
| Wear OS | Independent timer + complications | P0 |
| Google Assistant | Voice-activated focus sessions | P0 |
| Health Connect | Write mindful minutes | P1 |
| Soundscapes | Ambient sounds during focus | P1 |
| Mode Intelligence | AI-powered mode suggestion | P1 |
| Weekly Review | Mode comparison analytics | P1 |
| Streaks | Consecutive day tracking | P1 |
| Google Tasks import | One-way import | P1 |

---

## 2. Mapeo Técnico: Flutter → Kotlin

### Lenguaje

| Flutter/Dart | Kotlin |
|-------------|--------|
| `class TaskEntity` | `data class Task` |
| `@freezed` | `data class` (no codegen needed) |
| `late final` | `val` (lazy via `by lazy {}`) |
| `Future<T>` | `suspend fun(): T` |
| `Stream<T>` | `Flow<T>` |
| `async/await` | `suspend` / `coroutineScope` |
| `Provider` | Hilt `@Inject` |
| `ChangeNotifier` | `StateFlow` / `MutableStateFlow` |
| `GoRouter` | Compose Navigation / Circuit screens |
| `BuildContext` | `@Composable` scope |
| `Widget` | `@Composable fun` |
| `StatefulWidget` | `remember` + `mutableStateOf` |
| `String(localized:)` | `stringResource(R.string.x)` |

### Arquitectura

| Flutter Pattern | Android Pattern |
|----------------|----------------|
| Clean Architecture (3 layers) | Same: domain / data / presentation |
| Provider + ChangeNotifier | Circuit Presenter + StateFlow |
| GoRouter (declarative) | Compose Navigation + Circuit |
| Freezed models | Kotlin data classes |
| Repository interface | Same (interface in domain/) |
| Firebase Auth | JWT auth via Go backend |
| Firestore | Room (local) + REST API (remote) |
| SharedPreferences | Jetpack DataStore (Proto) |
| sqflite | Room |
| fl_chart | Vico (Compose charts) |
| RevenueCat | Google Play Billing 7 |

### Persistencia

| Flutter | Android |
|---------|---------|
| `SharedPreferences` (tasks, prefs) | `Room` (tasks) + `DataStore` (prefs) |
| `sqflite` (pomodoro sessions) | `Room` (all entities in one DB) |
| JSON serialization manual | Room type converters |
| No migration support | Room auto-migration |
| Firebase Firestore sync | Custom sync engine (Room ↔ REST) |

---

## 3. Modelo de Datos: Traducción

### TaskEntity (Flutter → Android)

```dart
// Flutter (Freezed)
@freezed
class TaskEntity with _$TaskEntity {
  const factory TaskEntity({
    required String id,
    required String title,
    String? description,
    required bool isCompleted,
    DateTime? completedDate,
    required int position,
    required DateTime createdAt,
    // ... subtasks as List<SubTask>
  }) = _TaskEntity;
}
```

```kotlin
// Android (Room)
@Entity(tableName = "tasks")
data class TaskEntity(
    @PrimaryKey val id: String,
    val title: String,
    val notes: String? = null,
    val isCompleted: Boolean = false,
    val completedAt: Instant? = null,
    val priority: Int = 0,
    val sortOrder: Int = 0,
    val energyLevel: String = "deep",       // NEW
    val estimatedPomodoros: Int = 1,         // NEW
    val completedPomodoros: Int = 0,         // NEW
    val preferredMode: String? = null,       // NEW
    val recurrenceRule: String? = null,      // NEW
    val nextOccurrence: Instant? = null,     // NEW
    val isRecurringTemplate: Boolean = false,// NEW
    val recurringTemplateId: String? = null, // NEW
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = Instant.now(),
    val syncedAt: Instant? = null,          // NEW (for sync)
    val isDirty: Boolean = true,            // NEW (for sync)
)
```

### PomodoroSession (Flutter → Android)

```dart
// Flutter (sqflite)
class PomodoroSession {
  final int id;
  final DateTime date;
  final int duration;
  final bool completed;
  // stored in raw SQL
}
```

```kotlin
// Android (Room) — expanded to multi-mode
@Entity(tableName = "focus_sessions")
data class FocusSessionEntity(
    @PrimaryKey val id: String,
    val mode: String,                // "pomodoro", "flowtime", etc.
    val phase: String,               // "work", "shortBreak", etc.
    val startedAt: Instant,
    val endedAt: Instant,
    val targetDurationMs: Long?,
    val actualDurationMs: Long,
    val wasCompleted: Boolean,
    val interruptions: Int = 0,
    val pomodoroNumber: Int? = null,
    val linkedTaskId: String? = null, // FK to tasks
    val syncedAt: Instant? = null,
    val isDirty: Boolean = true,
)
```

---

## 4. Strings: ARB → Android XML

### Proceso de migración

```
Flutter: lib/l10n/intl_en.arb (644 keys)
    ↓
Android: res/values/strings.xml

Flutter: lib/l10n/intl_es.arb (310 keys)
    ↓
Android: res/values-es/strings.xml

Flutter: lib/l10n/intl_pt.arb (309 keys)
    ↓
Android: res/values-pt/strings.xml
```

**Nota:** Muchos strings Flutter son para features que no aplican (Firebase-specific, Flutter-specific). Solo migrar los que aplican + agregar nuevos para features exclusivas Android.

**Strings nuevos a agregar (~100):**
- 4 focus mode names + descriptions
- Energy level names
- Recurrence preset names
- Widget labels
- Wear OS strings
- Quick Settings labels
- Google Assistant phrases
- Health Connect permissions
- Play Billing UI strings
- Notification channel names

---

## 5. Backend Integration Points

El Go backend en `apps/backend` ya tiene estos endpoints que Android usará directamente:

| Endpoint | Method | Usado por |
|----------|--------|-----------|
| `/api/v1/auth/register` | POST | Auth flow |
| `/api/v1/auth/login` | POST | Auth flow |
| `/api/v1/auth/refresh` | POST | Token refresh |
| `/api/v1/tasks` | GET/POST | Task sync |
| `/api/v1/tasks/:id` | PUT/DELETE | Task sync |
| `/api/v1/tasks/:id/subtasks` | GET/POST | Subtask sync |
| `/api/v1/pomodoro-sessions` | GET/POST | Session sync |
| `/api/v1/users/me` | GET/PUT | Profile |
| `/api/v1/users/me/avatar` | POST | Profile image |
| `/api/v1/health` | GET | Health check |

### Endpoints que podrían necesitar actualización en el backend

| Feature | Endpoint necesario | Existe? |
|---------|-------------------|---------|
| Multi-mode sessions | `POST /api/v1/focus-sessions` (con campo `mode`) | Parcial — actualizar modelo |
| Daily stats | `GET /api/v1/stats/daily?date=...` | ❌ Crear |
| Weekly review | `GET /api/v1/stats/weekly?week=...` | ❌ Crear |
| Energy levels | Tasks ya tienen el campo | ✅ |
| Recurring tasks | Tasks ya tienen campos de recurrence | ✅ (verificar) |
| Subscriptions | `POST /api/v1/subscriptions/verify` | ❌ Crear (Play receipt verification) |

---

## 6. User Data Migration (Flutter → Android Native)

Para usuarios que ya usan Pepinillo Flutter en Android:

### Estrategia
1. **No migration automática** — Android native es una app nueva en Play Store
2. **Backend sync as bridge** — Si el usuario tiene cuenta en Flutter, sus datos ya están en el backend → login en la app nativa sincroniza todo
3. **Import manual opcional** — Botón "Import from Pepinillo Classic" que lee SharedPreferences y sqflite del paquete Flutter (si está instalado)

### Datos a migrar

| Dato | Flutter Storage | Android Native |
|------|----------------|----------------|
| Tasks | SharedPreferences (JSON) | Room |
| Pomodoro sessions | sqflite | Room |
| Preferences | SharedPreferences | DataStore |
| Auth | Firebase Auth token | JWT (re-login needed) |
| Profile image | Firebase Storage URL | Backend URL |

### Limitaciones
- Firebase Auth → JWT requiere que el usuario haga login de nuevo
- Historical stats may have different format (Pomodoro-only vs multi-mode)
- Subtask IDs may need remapping
