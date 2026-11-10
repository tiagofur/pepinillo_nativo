---
tags:
  - android
  - design
  - material3
  - wearos
  - ui
  - ux
aliases:
  - Material3 Expressive Android
  - Design Roadmap Android
platform: android
type: module
doc_role: design-spec
status: active
date: 2026-05-28
updated: 2026-07-24
---

# 🎨 Android — Diseño UI/UX Material 3 Expressive

> [!abstract] Resumen
> Plan de implementación en 8 sprints para alinear Pepinillo Android + Wear OS con los estándares de Material 3 Expressive y Material You. Cada sección es la especificación de referencia para su issue de GitHub correspondiente.

> [!info] Cómo usar este documento
> Cada sección `## Sprint N` corresponde exactamente a un issue de GitHub. El agente de ejecución debe leer la sección completa antes de implementar el issue.

> [!warning] Estado post Judgment Day (2026-07-24)
> Auditoría adversarial completa + backlog de fixes: [[Judgment Day Android UI-UX 2026-07-24]].
>
> | Sprint issue | Estado | Notas |
> |-------------:|--------|-------|
> | #487–#491 | CLOSED | Entregados (estructura OK) |
> | #492 Morph | CLOSED con **regresión** | Track: [#501](https://github.com/tiagofur/pepinillo_nativo/issues/501) |
> | #493 Adaptive | OPEN + WIP branch | Extensión MEDIUM: #523 |
> | #494 Palettes | OPEN | Alto impacto premium |
>
> Residual funcional/UX (27 issues): **#501–#527**.

---

## Contexto técnico base

| Aspecto | Estado actual |
|---|---|
| `composeBom` | `2024.09.00` → necesita bump a `2025.05.01`+ en Sprint 2 |
| Material3 teléfono | ✅ `androidx.compose.material3` vía BOM |
| Material3 Wear | ❌ usa `androidx.wear.compose.material` (M2) |
| `wearCompose` | `1.5.0` (incluye `compose-material3` para Wear, sin agregar aún) |
| Navegación adaptativa | Manual: `isExpanded`, `showNavRail`, `showBottomNav` en `MainActivity.kt` |
| `BackHandler` en app | Ninguno — Predictive Back funciona con ajustes mínimos |
| `CircularTimerRing` | Canvas custom en `feature/focus/components/CircularTimerRing.kt` |
| `TaskDetail` | `ModalBottomSheet` dentro de `TasksScreen.kt` — sin navegación separada |
| Tipografía | Montserrat (downloadable Google Fonts) en toda la escala M3 — `Type.kt` con 5 weights (Light→Bold); Wear mirror en `WearType.kt` (#516) |
| Shapes | `PepinilloShapes` (M3 slots) + `PepinilloShapeTokens` (roles semánticos card/button/textField/badge/pill) en `Shape.kt`; wear mirror en `WearShape.kt` (#511) |
| Temas custom | `AppTheme.kt`: MaterialYou, Classic, Forest, Ocean, Sunset |
| Colores base | `Color.kt`: palette M3 generado desde seed `#4CAF50` |

### Archivos clave por sprint

| Archivo | Ruta |
|---|---|
| `WearTheme.kt` | `wear/src/main/java/dev/creapolis/pepinillo/presentation/WearTheme.kt` |
| `TimerScreen.kt` (Wear) | `wear/src/main/java/dev/creapolis/pepinillo/presentation/TimerScreen.kt` |
| `MainActivity.kt` (Wear) | `wear/src/main/java/dev/creapolis/pepinillo/presentation/MainActivity.kt` |
| `MainActivity.kt` (app) | `app/src/main/java/dev/creapolis/pepinillo/MainActivity.kt` |
| `TopLevelDestination.kt` | `app/src/main/java/dev/creapolis/pepinillo/navigation/TopLevelDestination.kt` |
| `FocusScreen.kt` | `app/src/main/java/dev/creapolis/pepinillo/feature/focus/FocusScreen.kt` |
| `CircularTimerRing.kt` | `app/src/main/java/dev/creapolis/pepinillo/feature/focus/components/CircularTimerRing.kt` |
| `TasksScreen.kt` | `app/src/main/java/dev/creapolis/pepinillo/feature/tasks/TasksScreen.kt` |
| `TaskDetailScreen.kt` | `app/src/main/java/dev/creapolis/pepinillo/feature/tasks/detail/TaskDetailScreen.kt` |
| `Theme.kt` | `app/src/main/java/dev/creapolis/pepinillo/ui/theme/Theme.kt` |
| `AppTheme.kt` | `app/src/main/java/dev/creapolis/pepinillo/ui/theme/AppTheme.kt` |
| `Color.kt` | `app/src/main/java/dev/creapolis/pepinillo/ui/theme/Color.kt` |
| `Shape.kt` | `app/src/main/java/dev/creapolis/pepinillo/ui/theme/Shape.kt` |
| `Type.kt` | `app/src/main/java/dev/creapolis/pepinillo/ui/theme/Type.kt` |
| `libs.versions.toml` | `gradle/libs.versions.toml` |
| `wear/build.gradle.kts` | `wear/build.gradle.kts` |
| `app/build.gradle.kts` | `app/build.gradle.kts` |

---

## Sprint 1 — Migración del módulo `:wear` a Wear Compose Material 3 {#sprint-1}

**Issue GitHub:** `[Android] Sprint 1 — Migrar módulo :wear a Wear Compose Material 3`
**Labels:** `android`, `wear`

### Motivación

El módulo `:wear` usa `androidx.wear.compose.material` (M2). La librería `androidx.wear.compose.material3` está disponible en `wearCompose 1.5.0` como dependencia separada — solo falta adoptarla. Sin esta migración, los sprints 5 (háptico en Wear) y 6 (ring expresivo en Wear) no tienen base correcta.

### Archivos a modificar

`gradle/libs.versions.toml` · `wear/build.gradle.kts` · `WearTheme.kt` · `wear/presentation/MainActivity.kt` · `wear/presentation/TimerScreen.kt` · `wear/presentation/StatsScreen.kt` · `wear/presentation/TasksScreen.kt`

### Cambios requeridos

**1. `gradle/libs.versions.toml`** — agregar entry de M3 para Wear:
```toml
[libraries]
androidx-wear-compose-material3 = { group = "androidx.wear.compose", name = "compose-material3", version.ref = "wearCompose" }
```

**2. `wear/build.gradle.kts`** — reemplazar dependencia:
```kotlin
// Eliminar:
implementation(libs.androidx.wear.compose.material)
// Agregar:
implementation(libs.androidx.wear.compose.material3)
```

**3. `WearTheme.kt`** — migrar de `Colors` (M2) a `ColorScheme` (M3):
- Cambiar import: `androidx.wear.compose.material` → `androidx.wear.compose.material3`
- `Colors` → `ColorScheme`; eliminar `primaryVariant` y `secondaryVariant` (no existen en M3)
- `MaterialTheme(colors = ...)` → `MaterialTheme(colorScheme = ...)`
- Preservar los valores OLED (fondo `#0A0C08`) asignándolos a `background` y `surface`
- `MaterialTheme.colors.onSurface` → `MaterialTheme.colorScheme.onSurface` en todo el módulo

**4. `wear/presentation/MainActivity.kt`** — migrar scaffold:
- `Scaffold` de M2 → `AppScaffold` + `ScreenScaffold` de M3
- `AppScaffold` envuelve la app entera y gestiona `TimeText` global
- `ScreenScaffold` va dentro de cada página del `HorizontalPager` y gestiona el scroll indicator nativo
- Eliminar los parámetros `timeText`, `vignette`, `pageIndicator` del `Scaffold` actual — `AppScaffold` los maneja

```kotlin
// Estructura objetivo:
AppScaffold(
    timeText = { if (!isAmbient) TimeText() }
) {
    HorizontalPager(state = pagerState) { page ->
        ScreenScaffold { /* contenido de la página */ }
    }
}
```

**5. `TimerScreen.kt` y demás pantallas Wear** — migrar componentes punto a punto:
- `CircularProgressIndicator` M2 → M3: parámetros cambian a `colors = CircularProgressIndicatorDefaults.colors(indicatorColor = ..., trackColor = ...)`
- `Button` M2 → `Button` M3 (verificar parámetros de `colors`)
- `CompactChip` M2 → `CompactChip` M3
- `MaterialTheme.typography.caption2` → `MaterialTheme.typography.labelSmall` (equivalente M3)

### Criterios de aceptación

- [ ] Módulo `:wear` compila sin errores ni warnings de deprecación de M2
- [ ] Pantalla del timer muestra el ring de progreso correctamente en emulador Wear
- [ ] Modo ambient sigue funcionando (display dimmed, sin colores)
- [ ] `TimeText` aparece en todas las páginas excepto en ambient
- [ ] `WearModeColors` sigue resolviendo correctamente desde `WearDataStore`
- [ ] Tests existentes del módulo Wear siguen pasando

---

## Sprint 2 — Navegación Adaptativa con `NavigationSuiteScaffold` {#sprint-2}

**Issue GitHub:** `[Android] Sprint 2 — Reemplazar navegación manual por NavigationSuiteScaffold`
**Labels:** `android`, `navigation`

### Motivación

`PepinilloApp` en `MainActivity.kt` tiene lógica manual con `isExpanded`, `showNavRail`, `showBottomNav` y doble `AnimatedVisibility` para alternar entre `NavigationBar` y `NavigationRail`. `NavigationSuiteScaffold` hace esto automáticamente y además soporta `NavigationDrawer` en pantallas muy anchas (foldables completamente abiertos). Este sprint también hace el bump del `composeBom` que habilita las APIs del resto del plan.

### Archivos a modificar

`gradle/libs.versions.toml` · `app/build.gradle.kts` · `app/src/main/java/dev/creapolis/pepinillo/MainActivity.kt`

### Cambios requeridos

**1. `gradle/libs.versions.toml`** — bump de BOM y nueva dependencia:
```toml
[versions]
composeBom = "2025.05.01"  # bump desde 2024.09.00
material3AdaptiveNavSuite = "1.4.0"

[libraries]
androidx-material3-adaptive-navigation-suite = {
    group = "androidx.compose.material3",
    name = "material3-adaptive-navigation-suite",
    version.ref = "material3AdaptiveNavSuite"
}
```

**2. `app/build.gradle.kts`**:
```kotlin
implementation(libs.androidx.material3.adaptive.navigation.suite)
```

**3. `MainActivity.kt` — función `PepinilloApp`** — eliminar estas variables:
```kotlin
// ELIMINAR:
val isExpanded = configuration.screenWidthDp >= 600
val showNavRail = isExpanded && showBottomBar
val showBottomNav = !isExpanded && showBottomBar
```

Reemplazar el bloque `Scaffold { Row { NavigationRail... NavHost } }` por:
```kotlin
NavigationSuiteScaffold(
    navigationSuiteItems = {
        TopLevelDestination.entries.forEach { destination ->
            val isSelected = currentRoute == destination.route
            item(
                selected = isSelected,
                onClick = {
                    navController.navigate(destination.route) {
                        popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                        launchSingleTop = true
                        restoreState = true
                    }
                },
                icon = { Icon(if (isSelected) destination.selectedIcon else destination.unselectedIcon, null) },
                label = { Text(stringResource(destination.labelRes)) },
            )
        }
    },
    layoutType = if (!showBottomBar) NavigationSuiteType.None
                 else NavigationSuiteDefaults.calculateFromAdaptiveInfo(currentWindowAdaptiveInfo()),
) {
    Column {
        OfflineBanner(isOnline = isOnline)
        NavHost(navController = navController, ...)
    }
}
```

> [!important] Preservar
> - La variable `showBottomBar` y su lógica de rutas secundarias se mantiene intacta
> - `SnackbarHost` debe quedar visible — moverlo fuera del `NavigationSuiteScaffold` si hace falta
> - `saveState = true` / `restoreState = true` en todos los `navigate()` se preservan

### Criterios de aceptación

- [ ] Pixel 6 portrait: `NavigationBar` en la parte inferior
- [ ] Pixel 6 landscape (≥600dp): `NavigationRail` a la izquierda
- [ ] Pixel Tablet: `NavigationRail` sin configuración extra
- [ ] Rutas secundarias (Settings, Profile, Calendar): sin ninguna navegación visible
- [ ] Estado de cada tab se preserva al cambiar (`saveState`/`restoreState`)
- [ ] Variables `isExpanded`/`showNavRail`/`showBottomNav` eliminadas del código
- [ ] `OfflineBanner` y Snackbar siguen funcionando

---

## Sprint 3 — Shared Element Transitions y Coherencia de Animaciones {#sprint-3}

**Issue GitHub:** `[Android] Sprint 3 — Shared elements y coherencia de animaciones en toda la app`
**Labels:** `android`, `animation`

### Motivación

Las transiciones actuales son fade genérico para tabs y fade+slideUp para rutas de detalle — definidas como constantes inline en `MainActivity.kt`. Con `SharedTransitionLayout` (disponible tras el bump del Sprint 2) se conectan elementos entre pantallas para dar sensación de "fisicalidad". El objetivo es coherencia en *toda* la app: centralizar duraciones, aplicar shared elements en los flujos de detalle más frecuentes, y mejorar la animación de entrada del `TaskDetail` BottomSheet sin convertirlo en pantalla separada.

### Decisiones de diseño tomadas

- `TaskDetail` permanece como `ModalBottomSheet` — animación de entrada expresiva en lugar de shared element cross-screen
- Shared elements principales: Dashboard → Calendario y Plan → TaskAnalytics
- Todas las duraciones y curvas se centralizan en un nuevo archivo `NavigationTransitions.kt`

### Archivos a modificar / crear

`app/src/main/java/dev/creapolis/pepinillo/navigation/NavigationTransitions.kt` (nuevo) · `app/src/main/java/dev/creapolis/pepinillo/ui/components/LocalSharedTransitionScope.kt` (nuevo) · `MainActivity.kt` · `feature/dashboard/DashboardScreen.kt` · `feature/calendar/CalendarScreen.kt` · `feature/tasks/TasksScreen.kt` · `feature/tasks/TaskAnalyticsScreen.kt`

### Cambios requeridos

**1. Nuevo `NavigationTransitions.kt`** — centralizar todas las constantes:
```kotlin
object NavigationTransitions {
    const val DURATION_TOP_LEVEL = 200
    const val DURATION_DETAIL = 280
    const val DURATION_MODAL = 320

    val detailEnter: AnimatedContentTransitionScope<*>.() -> EnterTransition = {
        fadeIn(tween(DURATION_DETAIL)) +
            slideInVertically(initialOffsetY = { it / 12 }, animationSpec = tween(DURATION_DETAIL))
    }
    val detailPopExit: AnimatedContentTransitionScope<*>.() -> ExitTransition = {
        fadeOut(tween(DURATION_DETAIL)) +
            slideOutVertically(targetOffsetY = { it / 12 }, animationSpec = tween(DURATION_DETAIL))
    }
}
```
Reemplazar las constantes `DURATION_NAV_MS`, `DURATION_NAV_DETAIL_MS`, `SecondaryEnterTransition`, `SecondaryPopExitTransition` de `MainActivity.kt` por referencias a este objeto.

**2. `LocalSharedTransitionScope.kt`** — para inyectar el scope sin contaminar firmas:
```kotlin
val LocalSharedTransitionScope = staticCompositionLocalOf<SharedTransitionScope?> { null }
val LocalNavAnimatedVisibilityScope = staticCompositionLocalOf<AnimatedVisibilityScope?> { null }
```

**3. `MainActivity.kt`** — envolver el `NavHost`:
```kotlin
SharedTransitionLayout {
    CompositionLocalProvider(LocalSharedTransitionScope provides this) {
        NavHost(...) {
            composable("dashboard") {
                CompositionLocalProvider(LocalNavAnimatedVisibilityScope provides this) {
                    DashboardScreen(...)
                }
            }
            // idem para todas las rutas que participan en shared elements
        }
    }
}
```

**4. Shared element Dashboard → Calendario** — en el card/encabezado que navega:
```kotlin
// DashboardScreen.kt — en el elemento que dispara navigate("calendar"):
val sharedScope = LocalSharedTransitionScope.current
val visibilityScope = LocalNavAnimatedVisibilityScope.current
if (sharedScope != null && visibilityScope != null) {
    with(sharedScope) {
        Modifier.sharedBounds(
            rememberSharedContentState(key = "calendar-entry"),
            animatedVisibilityScope = visibilityScope,
        )
    }
}
// CalendarScreen.kt — en el encabezado equivalente: misma key "calendar-entry"
```

**5. Shared element Plan → TaskAnalytics** — en el `TaskItem` que dispara analytics:
```kotlin
// Modifier con key "task-analytics-${task.id}" en TasksScreen y TaskAnalyticsScreen
```

**6. Animación expresiva del `TaskDetail` BottomSheet** — en el contenido del sheet:
```kotlin
var contentVisible by remember { mutableStateOf(false) }
LaunchedEffect(Unit) { contentVisible = true }
AnimatedVisibility(
    visible = contentVisible,
    enter = fadeIn(tween(NavigationTransitions.DURATION_MODAL)) +
        scaleIn(initialScale = 0.93f, animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessMedium,
        ))
) {
    TaskDetailScreen(...)
}
```

**7. Respetar `reduceMotion`** — si `isReduceMotionEnabled()`, todas las duraciones → 0ms y los shared elements usan `snap()`.

### Criterios de aceptación

- [ ] Dashboard → Calendario: el elemento compartido se transforma suavemente (no hay corte)
- [ ] Plan → TaskAnalytics: el nombre de tarea hace shared element
- [ ] TaskDetail BottomSheet: animación de entrada expresiva (scale+fade), no el pop genérico
- [ ] Con "Reduce Motion" activo: todas las animaciones son instantáneas
- [ ] No hay constantes de duración duplicadas — todo pasa por `NavigationTransitions.kt`
- [ ] La transición pop (botón atrás) es la inversa correcta de la entrada

---

## Sprint 4 — Soporte Completo para Predictive Back {#sprint-4}

**Issue GitHub:** `[Android] Sprint 4 — Habilitar y verificar Predictive Back en toda la app`
**Labels:** `android`, `navigation`

### Motivación

Android 14+ permite previsualizar la pantalla anterior al deslizar desde el borde. Navigation Compose 2.8.4 (ya instalado) tiene soporte nativo. El trabajo principal es declararlo en el manifest y verificar que las animaciones del Sprint 3 no lo bloqueen.

### Archivos a modificar

`app/src/main/AndroidManifest.xml`

### Cambios requeridos

**1. `AndroidManifest.xml`** — verificar/agregar el flag en `<application>`:
```xml
<application
    android:enableOnBackInvokedCallback="true"
    ...>
```

**2. Auditoría post-Sprint 3** — verificar que ninguna transición de `SharedTransitionLayout` bloquea el gesto de back. Si se detecta bloqueo, envolver con `PredictiveBackHandler` para coordinar la reversión del shared element con el gesto del sistema.

**3. `ModalBottomSheet` del TaskDetail** — `ModalBottomSheet` de M3 gestiona el swipe-to-dismiss y el back gesture automáticamente. Verificar que la animación de entrada del Sprint 3 no introduce ningún `BackHandler` que compita con el sistema.

**4. Verificar `NavHost`** — confirmar que `enablePredictiveBack = true` (default en Navigation 2.8+) no fue desactivado en ningún lugar.

> [!note] No hay `BackHandler` en la app
> El análisis del código confirmó que no existe ningún `BackHandler`. El trabajo principal es el manifest y la verificación post-Sprint 3.

### Criterios de aceptación

- [ ] En Android 14+ con "Predictive back animations" ON en Opciones de desarrollador: deslizar desde el borde derecho muestra la pantalla anterior antes de confirmar
- [ ] Calendar, Settings, TaskAnalytics, Profile: se previsualizan sus pantallas origen al deslizar
- [ ] `TaskDetail` BottomSheet se cierra con swipe-down sin conflicto con el back gesture
- [ ] Back desde tabs top-level cierra la app (no navega entre tabs)
- [ ] Shared element transitions del Sprint 3 se revierten correctamente al hacer back predictivo

---

## Sprint 5 — Feedback Háptico Premium {#sprint-5}

**Issue GitHub:** `[Android] Sprint 5 — Sistema de feedback háptico centralizado y configurable`
**Labels:** `android`, `wear`, `ux`

### Motivación

La app ya tiene háptico disperso (`HapticFeedbackType.LongPress` en `FocusScreen.kt` al completar pomodoro, en botones de Wear). El objetivo es centralizarlo en un objeto semántico, extenderlo a momentos clave (completar tareas, transición de fase, cambio de modo) y hacerlo configurable desde ajustes — respetando usuarios que prefieren no tener vibración.

### Archivos a modificar / crear

`app/src/main/java/dev/creapolis/pepinillo/ui/haptics/PepinilloHaptics.kt` (nuevo) · `data/local/preferences/UserPreferences.kt` · `data/local/preferences/UserPreferencesRepository.kt` · `feature/settings/SettingsScreen.kt` · `feature/focus/FocusScreen.kt` · `feature/tasks/detail/TaskDetailScreen.kt` · `wear/presentation/TimerScreen.kt`

### Cambios requeridos

**1. Nuevo `PepinilloHaptics.kt`** — objeto centralizado con patrones semánticos:
```kotlin
object PepinilloHaptics {
    // onTimerTick: micro-pulso sutil — solo si el usuario lo activa en ajustes
    fun onTimerTick(haptic: HapticFeedback, enabled: Boolean) {
        if (enabled) haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
    }

    // onPhaseComplete: pulso doble distintivo usando VibrationEffect en API 29+
    fun onPhaseComplete(haptic: HapticFeedback, context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val vibrator = context.getSystemService(Vibrator::class.java)
            val effect = VibrationEffect.createWaveform(
                longArrayOf(0, 80, 60, 120),  // espera, vibra, pausa, vibra
                intArrayOf(0, 180, 0, 255),    // amplitudes
                -1                              // no repetir
            )
            vibrator.vibrate(effect)
        } else {
            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
        }
    }

    fun onTaskComplete(haptic: HapticFeedback) {
        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
    }

    fun onModeChange(haptic: HapticFeedback) {
        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
    }
}
```

**2. `UserPreferences`** — agregar dos flags:
```kotlin
val hapticFeedbackEnabled: Boolean = true,      // master toggle
val hapticTimerTickEnabled: Boolean = false,    // opt-in, off por defecto
```
Y sus claves correspondientes en `UserPreferencesRepository`.

**3. `SettingsScreen.kt`** — nueva sección "Experiencia táctil" con dos `Switch`:
- "Feedback háptico" (master, `hapticFeedbackEnabled`)
- "Pulso en cada segundo" (`hapticTimerTickEnabled`) — habilitado solo si el master está ON

**4. `FocusScreen.kt`** — integración:
- `LaunchedEffect(uiState.completedSessions)`: reemplazar `haptic.performHapticFeedback(HapticFeedbackType.LongPress)` → `PepinilloHaptics.onPhaseComplete(haptic, context)`
- Loop de tick del timer: agregar `PepinilloHaptics.onTimerTick(haptic, hapticTimerTickEnabled)`
- `LaunchedEffect(uiState.selectedMode)`: agregar `PepinilloHaptics.onModeChange(haptic)`

**5. `TaskDetailScreen.kt`** — al completar tarea (acción check): `PepinilloHaptics.onTaskComplete(haptic)`

**6. Wear OS** — verificar que los eventos de fase completada llegan al reloj y disparan el háptico local en `TimerScreen.kt` (Wear) cuando recibe el evento de transición de fase.

### Criterios de aceptación

- [ ] Al completar sesión Pomodoro: pulso doble distintivo en teléfono
- [ ] Al completar una tarea (check): pulso satisfactorio
- [ ] Al cambiar de modo de foco: pulso suave de confirmación
- [ ] Con "Feedback háptico" OFF en ajustes: ningún háptico se dispara en ningún flujo
- [ ] Con "Pulso en cada segundo" ON: micro-vibración cada segundo durante sesión activa
- [ ] Sin `hapticFeedbackEnabled` en ajustes previos (usuario existente): default `true` sin crash
- [ ] Unit test de `PepinilloHaptics` cubriendo los condicionales de toggle y versión de API

---

## Sprint 6 — Ring de Progreso Expresivo (Morphing) {#sprint-6}

**Issue GitHub:** `[Android] Sprint 6 — CircularTimerRing con morphing circular→squircle`
**Labels:** `android`, `animation`

### Motivación

El `CircularTimerRing` actual es un arco circular estático. El objetivo es comunicar urgencia de forma **periférica** — el usuario no necesita mirar el timer directamente para percibir que el tiempo se acaba. La solución: morphing gradual de circular a squircle cuando queda ≤20% del tiempo, y un spring bounce de vuelta a circular al completar. En modos count-up (Flow, Chrono) sin cuenta regresiva, el ring permanece siempre circular.

### Archivos a modificar

`feature/focus/components/CircularTimerRing.kt` · `feature/focus/FocusScreen.kt` · `wear/presentation/TimerScreen.kt`

### Cambios requeridos

**1. `CircularTimerRing.kt`** — agregar parámetro `morphProgress`:
```kotlin
@Composable
fun CircularTimerRing(
    progress: Float,
    ringColor: Color,
    trackColor: Color,
    strokeWidth: Dp = 13.dp,
    modifier: Modifier = Modifier,
    isRunning: Boolean = false,
    showDashedOverlay: Boolean = false,
    morphProgress: Float = 0f,          // 0f = círculo, 1f = squircle
) {
    // En el Canvas, interpolar el cornerRadius del path usando lerp:
    // cornerRadius = lerp(0f, size.minDimension * 0.25f, morphProgress)
    // Usar Path + addRoundRect en lugar de drawArc cuando morphProgress > 0
}
```

**2. `FocusScreen.kt`** — calcular y animar `morphProgress`:
```kotlin
// Solo para modos con cuenta regresiva (no Flow, no Chrono):
val hasCountdown = uiState.selectedMode.defaultTotalSeconds != null
val rawMorphProgress = if (hasCountdown && uiState.progress >= 0.8f) {
    (uiState.progress - 0.8f) / 0.2f  // 0f a 1f en el último 20%
} else 0f

val morphProgress by animateFloatAsState(
    targetValue = if (isReduceMotionEnabled()) 0f else rawMorphProgress,
    animationSpec = spring(stiffness = Spring.StiffnessLow),
    label = "morphProgress",
)

// Pasar morphProgress a CircularTimerRing
```

**3. Spring bounce al completar** — en `LaunchedEffect(uiState.completedSessions)` existente, agregar animación de retorno:
- Cuando la sesión termina (`progress >= 1f`): animar `morphProgress` de vuelta a 0f con `spring(dampingRatio = Spring.DampingRatioMediumBouncy)`
- El ring "rebota" de vuelta a su forma circular, reforzando visualmente el completado
- Coordinar con el háptico del Sprint 5 (`PepinilloHaptics.onPhaseComplete`)

**4. Wear OS** — aplicar la misma lógica de `morphProgress` al `CircularProgressIndicator` de `TimerScreen.kt` en Wear, adaptado a las APIs de Wear Compose M3 del Sprint 1.

**5. Respetar `reduceMotion`** — `morphProgress` siempre 0f si `isReduceMotionEnabled()`.

### Criterios de aceptación

- [ ] En sesión Pomodoro con ≤20% restante: el ring comienza a adquirir forma de squircle gradualmente
- [ ] Al completar la sesión: el ring hace spring bounce de vuelta a circular
- [ ] En modo Flow y Chrono (count-up): el ring permanece siempre circular
- [ ] Con "Reduce Motion" activo: el ring no morphea, permanece circular
- [ ] La animación de morphing no afecta el `contentDescription` semántico del timer
- [ ] Preview de Android Studio con `progress = 0.85f`, `0.95f`, `1.0f` muestra el morphing correctamente
- [ ] En Wear OS: mismo comportamiento en el `CircularProgressIndicator`

---

## Sprint 7 — Layout de Panel Dual para Tablets y Foldables {#sprint-7}

**Issue GitHub:** `[Android] Sprint 7 — ListDetailPaneScaffold para tablets y foldables`
**Labels:** `android`

### Motivación

En tablets y foldables abiertos, la pantalla Plan muestra la lista de tareas con el `TaskDetail` como BottomSheet — desperdicia el espacio extra y obliga a navegación de "ida y vuelta". `ListDetailPaneScaffold` de `material3-adaptive` muestra ambos paneles simultáneamente en pantallas anchas, mientras en móvil el comportamiento actual (BottomSheet) se preserva intacto.

### Archivos a modificar / crear

`gradle/libs.versions.toml` · `app/build.gradle.kts` · `feature/tasks/TasksAdaptiveLayout.kt` (nuevo) · `MainActivity.kt`

### Cambios requeridos

**1. `gradle/libs.versions.toml`** — si no es transitiva del Sprint 2:
```toml
[versions]
material3Adaptive = "1.1.0"

[libraries]
androidx-material3-adaptive = { group = "androidx.compose.material3", name = "material3-adaptive", version.ref = "material3Adaptive" }
```

**2. `app/build.gradle.kts`**:
```kotlin
implementation(libs.androidx.material3.adaptive)
```

**3. Nuevo `TasksAdaptiveLayout.kt`** — composable adaptativo:
```kotlin
@Composable
fun TasksAdaptiveLayout(
    onNavigateToAnalytics: (String) -> Unit,
    onNavigateToPaywall: () -> Unit,
    onStartFocusTask: () -> Unit,
) {
    val windowSizeClass = currentWindowAdaptiveInfo().windowSizeClass
    val isExpanded = windowSizeClass.windowWidthSizeClass == WindowWidthSizeClass.EXPANDED

    if (isExpanded) {
        // Panel dual: lista a la izquierda, detalle a la derecha
        val navigator = rememberListDetailPaneScaffoldNavigator<String>()
        ListDetailPaneScaffold(
            directive = navigator.scaffoldDirective,
            value = navigator.scaffoldValue,
            listPane = {
                AnimatedPane {
                    TasksScreen(
                        onTaskClick = { taskId ->
                            navigator.navigateTo(ListDetailPaneScaffoldRole.Detail, taskId)
                        },
                        onNavigateToAnalytics = onNavigateToAnalytics,
                        onNavigateToPaywall = onNavigateToPaywall,
                        onStartFocusTask = onStartFocusTask,
                    )
                }
            },
            detailPane = {
                AnimatedPane {
                    val taskId = navigator.currentDestination?.contentKey
                    if (taskId != null) {
                        val detailViewModel: TaskDetailViewModel = hiltViewModel(key = taskId)
                        LaunchedEffect(taskId) { detailViewModel.initialize(taskId) }
                        TaskDetailScreen(
                            onBack = { navigator.navigateBack() },
                            viewModel = detailViewModel,
                            onNavigateToPaywall = onNavigateToPaywall,
                            onNavigateToAnalytics = onNavigateToAnalytics,
                            onStartFocusTask = { onStartFocusTask() },
                        )
                    }
                }
            },
        )
    } else {
        // Móvil: comportamiento original con BottomSheet — sin cambios
        TasksScreen(
            onTaskClick = {},
            onNavigateToAnalytics = onNavigateToAnalytics,
            onNavigateToPaywall = onNavigateToPaywall,
            onStartFocusTask = onStartFocusTask,
        )
    }
}
```

**4. `MainActivity.kt`** — reemplazar la ruta `TopLevelDestination.Plan`:
```kotlin
// Antes:
composable(TopLevelDestination.Plan.route) {
    TasksScreen(...)
}
// Después:
composable(TopLevelDestination.Plan.route) {
    TasksAdaptiveLayout(...)
}
```

**5. Dashboard (opcional, misma fase)** — aplicar el mismo patrón en `DashboardScreen`: en `EXPANDED`, mostrar Dashboard a la izquierda y Calendario o AI Report a la derecha en un `ListDetailPaneScaffold`.

### Criterios de aceptación

- [ ] En Pixel Fold abierto: pantalla Plan muestra lista de tareas y detalle en paneles lado a lado
- [ ] En Pixel Fold cerrado: comportamiento original (BottomSheet)
- [ ] En Pixel Tablet: panel dual sin configuración extra
- [ ] El estado de selección de tarea se preserva durante rotación de pantalla
- [ ] En móvil (Compact): `TasksScreen` original sin cambios, sin regresiones
- [ ] El `TaskDetailScreen` funciona correctamente en ambos contextos (panel y BottomSheet)

---

## Sprint 8 — Regeneración Completa de Palettes con Material 3 Expressive {#sprint-8}

**Issue GitHub:** `[Android] Sprint 8 — Regenerar palettes Forest/Ocean/Sunset con M3 Expressive`
**Labels:** `android`, `wear`

### Motivación

Los temas Forest, Ocean y Sunset usan colores hardcoded sin aprovechar los algoritmos de generación de M3 1.3+. El palette base Pepinillo Green (`#4CAF50`) tampoco se ha regenerado con el modo "Expressive" del Material Theme Builder. El resultado: colores menos vibrantes, contraste subóptimo en containers, y falta de coherencia entre los accent colors de modo y el `ColorScheme` de `MaterialTheme`.

### Archivos a modificar

`app/src/main/java/dev/creapolis/pepinillo/ui/theme/Color.kt` · `app/src/main/java/dev/creapolis/pepinillo/ui/theme/Theme.kt` · `app/src/main/java/dev/creapolis/pepinillo/ui/theme/AppTheme.kt`

### Cambios requeridos

**1. Generar nuevos palettes** — usar [Material Theme Builder](https://material-foundation.github.io/material-theme-builder/) con modo "Expressive":
- Seed base Pepinillo: `#4CAF50`
- Seed Forest: `#2E7D32`
- Seed Ocean: `#0077B6`
- Seed Sunset: `#E64A19`
- Exportar cada uno como Compose (Kotlin)

**2. `Color.kt`** — reemplazar todos los valores `md_theme_light_*` y `md_theme_dark_*` con los generados. M3 1.3+ agrega tokens nuevos como `surfaceContainerLow`, `surfaceContainerHigh`, `surfaceBright` — incluirlos si el Builder los genera.

**3. `Theme.kt`** — actualizar `lightColorScheme()` y `darkColorScheme()` con los nuevos tokens. Verificar que el tema `MaterialYou` (dynamic color) sigue teniendo prioridad sobre los estáticos en API 31+.

**4. `AppTheme.kt`** — actualizar los accent colors de Forest/Ocean/Sunset para que deriven del nuevo palette generado. Los colores de modo (pomodoroColor, flowtimeColor, etc.) deben ser coherentes con el `ColorScheme` correspondiente:

```kotlin
// Helper para derivar AppTheme desde un ColorScheme generado:
fun AppTheme.Companion.fromColorScheme(
    id: String,
    scheme: ColorScheme,
    isFree: Boolean = false,
): AppTheme = AppTheme(
    id = id,
    pomodoroColor = scheme.error,           // rojo/cálido del scheme
    flowtimeColor = scheme.primary,         // color primario del scheme
    timeBlockColor = scheme.tertiary,       // terciario del scheme
    stopwatchColor = scheme.secondary,      // secundario del scheme
    streakColor = scheme.tertiaryContainer, // container cálido
    isFree = isFree,
)
```

**5. Auditoría de contraste WCAG AA** — para cada tema (light + dark), verificar que los pares interactivos cumplen ratio mínimo:
- `primaryContainer` / `onPrimaryContainer`: ≥ 4.5:1 (texto normal)
- `tertiaryContainer` / `onTertiaryContainer`: ≥ 4.5:1
- Si algún par falla post-Builder, ajustar luminosidad del container preservando el hue

**6. Sincronización con Wear** — `WearModeColors` lee de `WearDataStore.themeColors` sincronizado desde el teléfono. Verificar que los nuevos colores de accent son legibles sobre el fondo OLED `#0A0C08` del reloj.

### Criterios de aceptación

- [ ] Tema Forest en modo claro: verdes más vibrantes y coherentes entre ring, chips y cards
- [ ] Tema Ocean en modo oscuro: azules con identidad clara, legibles sobre fondo oscuro
- [ ] Tema Sunset en ambos modos: cálidos armónicos sin sobre-saturación
- [ ] Tema MaterialYou en API 31+: dynamic color sigue funcionando y tiene prioridad
- [ ] Todos los pares `container`/`onContainer` cumplen WCAG AA (4.5:1) — verificado con DevTools
- [ ] Usuarios Free (MaterialYou/Classic): sin cambios inesperados en su experiencia
- [ ] Wear OS: los nuevos accent colors de modo son legibles en la pantalla circular OLED del reloj

---

## Referencias

- [[Android MOC]]
- [[Arquitectura General]]
- [[Widgets & Wear OS]]
- [[Roadmap Paridad Funcional con iOS]]
- [[Estado Plataforma]]
- [Material Theme Builder](https://material-foundation.github.io/material-theme-builder/)
- [Wear Compose Material 3 — developer.android.com](https://developer.android.com/training/wearables/compose)
- [NavigationSuiteScaffold — developer.android.com](https://developer.android.com/develop/ui/compose/layouts/adaptive/navigation-suite-scaffold)
- [ListDetailPaneScaffold — developer.android.com](https://developer.android.com/develop/ui/compose/layouts/adaptive/list-detail)
