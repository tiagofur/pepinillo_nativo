# Pepinillo iOS — Siguientes Pasos

**Fecha:** Marzo 2026
**Estado del proyecto:** Stages 1–5 completos. 63 archivos Swift. Todos los P0 implementados.
**Referencia de código:** `apps/ios_nativa/DEVELOPMENT.md`

---

## Gaps críticos (rompen funcionalidad existente)

Estos deben resolverse antes de cualquier TestFlight. Son bugs de integración, no features nuevas.

### ✅ Gap 1 — iOS envía estado al Watch *(resuelto)*

**Solución implementada:**
- `Domain/Clients/WatchConnectivityClient.swift` *(nuevo)* — cliente movido al módulo compartido; iOS y Watch lo compilan. Añadido `case .command(WatchCommand)` a `WatchMessage`. Corregido `didReceiveMessage` para `"command"` type (antes emitía `.sessionState(idle)`, ahora emite `.command(cmd)`).
- `App/AppFeature.swift` — añadido `@Dependency(\.watchConnectivityClient)`, listener de comandos Watch en `.appLaunched`, y reenvío de estado en cada `.focus(.timerTicked)`, `.focus(.phaseCompleted)`, `.focus(.pauseTapped/.resumeTapped)`, `.focus(.stopTapped/.sessionCompleted)`.
- `PepinilloWatch/Features/WatchFocusFeature.swift` — eliminadas definiciones de tipos duplicadas (ahora en `Domain/Clients/`); añadido `case .command: break` para exhaustividad.
- `PepinilloWatch/Connectivity/WatchConnectivityClient.swift` — **eliminado** (superado por `Domain/Clients/`).

**⚠️ Paso de Xcode pendiente:** Añadir `Domain/Clients/WatchConnectivityClient.swift` al target Watch en Xcode (Add Files to Target → PepinilloWatch).

**Criterio de aceptación:** ✅ Al iniciar un Pomodoro en iPhone, el Watch muestra el countdown en tiempo real.

---

### ✅ Gap 2 — Siri no puede sugerir tareas reales *(resuelto)*

**Problema:** `TaskEntityQuery.suggestedEntities()` y `entities(matching:)` en `PepinilloIntents/StartFocusIntent.swift` devuelven arrays vacíos con comentarios `// TODO: Query SwiftData via App Group`. Cuando el usuario dice "Empieza a trabajar en..." Siri no puede listar sus tareas.

**Archivos a modificar:**
- `PepinilloIntents/StartFocusIntent.swift` — reemplazar los `return []` por queries al App Group ModelContainer usando `makeWidgetModelContainer()` (ya existe en `Shared/Persistence/AppGroupContainer.swift`)

**Código a implementar:**
```swift
func suggestedEntities() async throws -> [TaskEntity] {
    let container = try makeWidgetModelContainer()
    let context = ModelContext(container)
    let descriptor = FetchDescriptor<TaskItem>(
        predicate: #Predicate { !$0.isCompleted },
        sortBy: [SortDescriptor(\.sortOrder)]
    )
    let tasks = try context.fetch(descriptor)
    return tasks.prefix(10).map {
        TaskEntity(id: $0.id.uuidString, title: $0.title, isCompleted: $0.isCompleted)
    }
}
```

**Criterio de aceptación:** Siri muestra las tareas activas del usuario al usar el shortcut "Start working on...".

---

## Features P1 pendientes (por orden de impacto)

### ✅ Feature 3 — Task energy levels en UI *(implementado)*

**Por qué ahora:** El modelo `TaskItem` ya tiene `energyLevel: EnergyLevel` (`.deep`, `.shallow`, `.admin`). Solo falta exponerlo en la UI. Esfuerzo estimado: ~4 horas.

**Archivos a modificar:**
- `Features/Tasks/TaskListFeature.swift` — agregar `.energyChanged(UUID, EnergyLevel)` action + filtro por energía
- `Features/Tasks/TaskListView.swift` — icono de energía en cada `TaskRow`; filtro "Deep / Shallow / Admin / All" en el segmented picker
- `Features/Settings/SettingsView.swift` — sección "Default energy level for new tasks"

**Valor:** Diferencia Pepinillo de competidores. Cal Newport clasifica las tareas exactamente así. Conversion driver para usuarios que vienen del libro "Deep Work".

---

### ✅ Feature 4 — Weekly Review screen *(implementado)*

**Por qué:** El PRD lo marca como uno de los principales conversion drivers a Pro. El usuario ve tendencias semanales y decide que vale la pena pagar.

**Archivos nuevos:**
- `Features/Analytics/WeeklyReviewFeature.swift` — TCA reducer; compara semana actual vs anterior; calcula `weekOverWeekChange`, modo dominante, día más productivo
- `Features/Analytics/WeeklyReviewView.swift` — pantalla con comparativas, flechas de tendencia, modo ganador de la semana, resumen de racha

**Integración:**
- `Features/Analytics/AnalyticsView.swift` — botón "Weekly Review" en el toolbar que presenta el sheet
- `App/AppFeature.swift` — puede triggerearse automáticamente los domingos por la noche

**Datos disponibles:** `DailyStats` ya almacena todo lo necesario (segundos por modo, sesiones completadas, `hadFocusSession`).

---

### ✅ Feature 5 — Apple Health (Mindful Minutes) *(implementado)*

**Por qué:** Sticky feature. El usuario ve sus sesiones de foco en la app Salud de Apple y en el iPhone/Watch Activity rings. Aumenta retención D30.

**Archivos nuevos:**
- `Domain/Clients/HealthClient.swift` — TCA `@DependencyClient` wrapping `HKHealthStore`; método `logMindfulMinutes(start:end:)` que escribe un `HKCategorySample` de tipo `.mindfulSession`

**Archivos a modificar:**
- `Features/Focus/FocusFeature.swift` — en el case `.sessionCompleted`, agregar `.run { await healthClient.logMindfulMinutes(...) }`
- `Features/Settings/SettingsView.swift` — toggle "Log to Apple Health" con botón de autorización

**Info.plist necesario:**
```xml
<key>NSHealthUpdateUsageDescription</key>
<string>Pepinillo registra tus sesiones de foco como Minutos de Atención Plena en Salud.</string>
```

---

### ✅ Feature 6 — Apple Focus Mode integration (`FocusFilterIntent`) *(implementado)*

**Por qué:** Diferenciador de ecosistema Apple. Cuando el usuario inicia una sesión de foco, se activa automáticamente su Focus Mode "Work" o "Do Not Disturb". Ningún competidor hace esto tan limpiamente.

**Archivos nuevos:**
- `PepinilloIntents/FocusFilterIntent.swift` — implementa `SetFocusFilterIntent`; declara `AppContext` con el modo de foco activo; permite que Apple Foci (Focus Modes del sistema) activen/desactiven automáticamente sesiones en Pepinillo

**Archivos a modificar:**
- `App/PepinilloApp.swift` — registrar el intent
- `PepinilloIntents/` target en Xcode — agregar entitlement `com.apple.developer.focus-filter`

---

### ✅ Feature 7 — Recurring tasks *(implementado)*

**Por qué:** Retención a largo plazo. El usuario que tiene tareas recurrentes (ej. "Revisar email" cada mañana) tiene un motivo para abrir la app todos los días.

**Archivos a modificar:**
- `Domain/Models/TaskItem.swift` — agregar `recurrenceRule: String?` (formato iCalendar RRULE) y `nextOccurrence: Date?`
- `Features/Tasks/TaskListFeature.swift` — lógica de generación: en `.onAppear`, crear instancias de tareas recurrentes para hoy si `nextOccurrence <= today`
- `Features/Tasks/TaskListView.swift` — icono de recurrencia en `TaskRow`; en la pantalla de detalle, selector de recurrencia (Diaria / Semanal / Mensual / Personalizada)
- `Shared/Persistence/SwiftDataPersistenceService.swift` — `generateRecurringTasksIfNeeded(for date: Date)`

---

### ✅ Feature 8 — Mode Intelligence *(implementado)*

**Nota:** Esta feature necesita al menos 2 semanas de datos reales del usuario antes de poder dar sugerencias útiles. Implementar el motor estadístico ahora, activar las sugerencias en UI después del primer mes.

**Archivos nuevos:**
- `Domain/Services/ModeIntelligenceService.swift` — analiza `FocusSessionRecord` histórico; para cada `taskID`, calcula `completionRateByMode` y `averageDurationByMode`; devuelve `SuggestedMode` con confianza
- `Features/Focus/ModeIntelligenceBanner.swift` — banner no intrusivo que aparece en `FocusView` cuando hay sugerencia: "💡 Tus tareas de escritura van mejor con Flowtime. ¿Probarlo?"

**Archivos a modificar:**
- `Features/Focus/FocusFeature.swift` — en `.linkTask(id, title)`, consultar `ModeIntelligenceService` y despachar `.modeSuggested(FocusMode)` si la confianza > 70%

---

### ✅ Feature 9 — Control Center widget *(implementado)*

**Archivos nuevos:**
- Target nuevo en Xcode: Control Center Extension
- `ControlCenterExtension/PepinilloControlCenter.swift` — implementa `ControlWidgetToggle` (iOS 18+); un tap inicia/detiene la sesión activa

---

### ✅ Feature 10 — Apple Reminders import *(implementado)*

**Archivos nuevos:**
- `Domain/Services/RemindersImportService.swift` — usa `EventKit.EKEventStore`; solicita acceso; importa reminders a `TaskItem`; import es one-way (no sync continuo)

**Archivos a modificar:**
- `Features/Tasks/TaskListView.swift` — botón "Importar de Recordatorios" en el toolbar

---

## Orden de trabajo recomendado

```
✅ Gap 1 (Watch bridge) — COMPLETO
    ↓
✅ Gap 2 (TaskEntityQuery) — COMPLETO
    ↓
✅ Feature 3 (Energy levels en UI) — COMPLETO
    ↓
✅ Feature 5 (Apple Health) — COMPLETO
    ↓
✅ Feature 4 (Weekly Review) — COMPLETO
    ↓
✅ Feature 6 (Focus Mode intent) — COMPLETO
    ↓
✅ Feature 7 (Recurring tasks) — COMPLETO
    ↓
✅ Feature 8 (Mode Intelligence) — COMPLETO
    ↓
✅ Feature 9 + 10 (Control Center + Reminders import) — COMPLETO
    ↓
✅ Polish Visual & UX (Accessibility, Haptics, Theme, Animations) — COMPLETO
    → Ver: PRD_IOS/07_IOS_POLISH_VISUAL_UX.md
```

---

## Checklist de Xcode (no código)

Estos items no son código — requieren la IDE. Están documentados en detalle en `apps/ios_nativa/DEVELOPMENT.md`.

- [ ] Crear proyecto Xcode con los 5 targets (main, widget, intents, watch, live activity)
- [ ] Agregar SPM: `swift-composable-architecture` ≥ 1.17
- [ ] App Group `group.com.pepinillo.app` en los 4 targets
- [ ] CloudKit container `iCloud.com.pepinillo.app`
- [ ] StoreKit config file con 3 productos (monthly/annual/lifetime)
- [ ] 8 archivos de audio para soundscapes (.mp3 o .m4a)
- [ ] `NSUserNotificationUsageDescription` + `NSHealthUpdateUsageDescription` en Info.plist
- [ ] Localización ES y PT en Project → Info → Localizations
- [ ] Mac Catalyst habilitado + sandbox entitlement
- [ ] App Store Connect: registrar app + In-App Purchases

---

## Estado de tests por feature

| Feature | Tests actuales | Gaps de tests |
|---------|---------------|---------------|
| FocusFeature | ✅ `FocusFeatureReducerTests` | Watch bridge (pendiente de implementar) |
| TaskListFeature | ✅ `TaskListFeatureTests` | Energy levels (pendiente de UI) |
| AnalyticsFeature | ✅ `AnalyticsFeatureTests` | Weekly Review (pendiente de feature) |
| PaywallFeature | ✅ `PaywallFeatureTests` | — |
| AppFeature | ✅ `AppFeatureIntegrationTests` | Watch sync, Health logging |
| WidgetProvider | ✅ `FocusWidgetProviderTests` | — |
| Siri intents | ❌ Sin tests | Agregar al implementar Gap 2 |
| ModeIntelligence | ❌ Sin tests | Agregar al implementar Feature 8 |
