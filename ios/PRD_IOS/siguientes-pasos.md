# Pepinillo iOS — Siguientes Pasos (Actualizado)

**Fecha:** Marzo 16, 2026
**Estado del proyecto:** Core + Fase A + Fase B (7/8) + App Store Polish completos (101 archivos Swift, 44 tests, 0 failures). Proyecto Xcode generado con XcodeGen, todos los targets compilan, tests pasan. Listo para TestFlight.
**Estrategia:** Ecosistema Apple puro. Solo Sign in with Apple. Sin Firebase. Sin dependencia de Android.

---

## Estado Real del Código vs. Lo Que Falta

### ✅ Implementado en código (funcional)

| Feature | Archivos | Estado |
|---------|----------|--------|
| 4 modos de foco (Pomodoro, Flowtime, Time Block, Stopwatch) | FocusEngine, 4 Strategies, FocusFeature | Completo |
| Task CRUD con subtasks, energía, recurrencia | TaskListFeature, TaskDetailFeature, TaskItem | Completo |
| Analytics con breakdown por modo | AnalyticsFeature, AnalyticsView | Completo |
| Streaks + Achievements (6 logros) | AnalyticsFeature, CelebrationView | Completo |
| Weekly Review | WeeklyReviewFeature, WeeklyReviewView | Completo |
| Settings por modo | SettingsFeature, SettingsView | Completo |
| Paywall + StoreKit 2 | PaywallFeature, PaywallView | Completo |
| Sign in with Apple | AppFeature | Completo |
| Apple Health (Mindful Minutes) | HealthClient | Completo |
| Watch bridge bidireccional | WatchConnectivityClient | Completo |
| Widgets (S/M/L + Lock Screen) | FocusWidget, FocusWidgetProvider | Completo |
| Live Activity + Dynamic Island | FocusActivityAttributes, LiveActivityManager | Completo |
| Control Center widget | ControlCenterExtension | Completo |
| Mode Intelligence | ModeIntelligenceService, ModeIntelligenceBanner | Completo |
| Reminders import | RemindersImportService | Completo |
| Focus Mode integration (FocusFilterIntent) | FocusFilterIntent | Completo |
| Soundscapes (client) | SoundscapeClient, SoundscapePickerView | Cliente listo |
| Accessibility (VoiceOver, Reduce Motion, Haptics) | HapticManager, ConditionalAnimation, ModeColors | Completo |
| Temas (sistema) | AppTheme, ModeColors | Completo |
| Onboarding con selección de modo | OnboardingView | Completo |
| Mac commands básico | MacCommands.swift | Parcial |

### ✅ Fase A completada — Xcode Setup & Integración

| Item | Estado | Notas |
|------|--------|-------|
| Proyecto Xcode multi-target | ✅ Completo | XcodeGen + project.yml. 5 targets: Main, Widget, Watch, ControlCenter, Tests |
| App Group + Entitlements | ✅ Completo | group.com.pepinillo.app, iCloud, HealthKit, Siri, Push |
| SPM Dependencies | ✅ Completo | TCA 1.17+, SnapshotTesting 1.17+ |
| Build & Fix | ✅ Completo | Main app compila, 44 tests pasan (0 failures) |
| CloudKit config | ✅ Completo | SwiftData + CloudKit en main app, .none en extensions |
| StoreKit config | ✅ Completo | Pepinillo.storekit con 3 productos |
| Audio files | ✅ Completo | 8 archivos .m4a en Shared/Resources/Sounds/ |
| Localización | ✅ Completo | Localizable.xcstrings con EN, ES, PT |
| Info.plist entries | ✅ Completo | Privacy descriptions para notifications, Health, Reminders, Siri |
| App Icon | ✅ Completo | 1024x1024 en Assets.xcassets |
| Testing en device | 🟡 Pendiente | Requiere provisioning manual en Xcode. Verificar timer background, Live Activity, Watch. |

### ✅ Fase B completada — Features Competitivas (7/8)

| Item | Estado | Notas |
|------|--------|-------|
| B1: Timer persistente en notificación | ✅ Completo | UNNotificationContent con countdown, acciones contextuales |
| B2: Widgets interactivos | ✅ Completo | Botones Start/Pause/Stop con AppIntent en widgets S/M/L |
| B3: StandBy mode | ✅ Completo | Widget optimizado para horizontal: fuente grande, alto contraste |
| B4: Siri + App Intents completos | ✅ Completo | TaskEntityQuery real, StopFocusIntent, CheckStatsIntent, 3 idiomas |
| B5: Notificaciones con acciones | ✅ Completo | Categorías por fase: "Empezar Break" / "Siguiente Pomodoro" / "Terminar" |
| B6: Liquid Glass theme | ✅ Completo | GlassModifier.swift: .glassEffect() iOS 26+, fallback ultraThinMaterial |
| B7: iPad + Stage Manager | ✅ Completo | .defaultSize en iPad, split view constraints verificados |
| B8: macOS nativo | ❌ No hecho | Diferido — requiere menu bar extra, ventana principal, ~32h de trabajo |

### ✅ App Store Polish completado (NO en PRD original)

Features implementadas que no estaban contempladas en el PRD original pero son necesarias para App Store submission y visibilidad editorial.

| Item | Estado | Notas |
|------|--------|-------|
| PrivacyInfo.xcprivacy | ✅ Completo | 4 manifests (app, widget, watch, control center). BLOQUEANTE para submission. |
| Focus Filter entitlement + implement. | ✅ Completo | Entitlement en .entitlements + perform() funcional que escribe AppGroupDefaults |
| Accessibility mejorada | ✅ Completo | Timer circle a11y value/label, widget a11y combine, bar chart labels, reduceTransparency en GlassModifier |
| Siri phrase localization (ES+PT) | ✅ Completo | AppShortcuts.xcstrings con 21 frases en 3 idiomas |
| Intent donation | ✅ Completo | Donate StartFocusIntent en sessionCompleted, CheckStatsIntent en analytics onAppear |
| WritingTools en Journal | ✅ Completo | .writingToolsBehavior(.complete) condicional iOS 18.1+ |

### ✅ Apple Intelligence Intents (NO en PRD original como intents separados)

El PRD original contemplaba "Apple Intelligence Insights" como Writing Tools API. En su lugar, se implementaron 3 App Intents completos que exponen la inteligencia de la app directamente a Siri y Shortcuts.

| Item | Estado | Notas |
|------|--------|-------|
| GetWeeklyReportIntent | ✅ Completo | "How was my focus this week?" — usa WeeklyReportService (nuevo) |
| GetInsightsIntent | ✅ Completo | "Give me focus insights" — reutiliza InsightsService, top 3 insights |
| GetModeSuggestionIntent | ✅ Completo | "What mode should I use?" — reutiliza ModeIntelligenceService + time-of-day analysis |
| WeeklyReportService | ✅ Completo | Servicio puro extraído de WeeklyReviewFeature para reuso intent + TCA |
| FocusSessionRecord+DTO | ✅ Completo | Extensión toDTO() separada para evitar conflicto con widget target |

### ✅ Fase C parcialmente completada (items originales del PRD)

| Item | Estado | Notas |
|------|--------|-------|
| C1: Session Journaling | ✅ Completo | Post-session sheet con nota (500 chars) + emoji satisfacción (1-5). Persistido en SwiftData. |
| C3: Apple Calendar | ✅ Completo | EventKit integration para crear eventos de foco en calendario |
| C5: Spotlight Integration | ✅ Completo | CSSearchableIndex para tareas con deep links |
| C2: Handoff entre devices | ❌ No hecho | Requiere NSUserActivity + CloudKit sync verificado |
| C4: Shortcuts automations | 🟡 Parcial | Intent donation implementado. Falta: expose all intents como Shortcuts actions completos |
| C6: Apple Intelligence | ✅ Completo | Implementado como 3 App Intents (no Writing Tools API como en PRD original) |
| C7: ADHD-Friendly Mode | ❌ No hecho | Breaks guiados, gentle mode — para post-launch |
| C8: SharePlay | ❌ No hecho | Sesiones compartidas — para futuro |

### 🔴 Lo que falta para Launch

| Item | Prioridad | Esfuerzo |
|------|-----------|----------|
| B8: macOS nativo | P1 (PRD lo marca P0) | ~32h |
| Testing en device real | P0 | ~8h |
| TestFlight beta (100+ users) | P0 | ~8h setup + 2 sem |
| Bug fixes post-beta | P0 | Variable |
| App Store screenshots + preview video | P0 | ~16h |
| ASO en 3 idiomas | P0 | ~8h |
| C2: Handoff | P2 (post-launch) | ~16h |
| C4: Shortcuts completos | P2 (post-launch) | ~4h remaining |
| C7: ADHD Mode | P2 (post-launch) | ~12h |
| C8: SharePlay | P3 (futuro) | ~24h |

---

## Orden de Trabajo Completado

```
FASE A — Pre-Launch Setup ✅ COMPLETO (Marzo 2026)
├── ✅ Crear proyecto Xcode + targets + SPM
├── ✅ App Groups + CloudKit + Entitlements
├── ✅ Build & fix compilation (44 tests, 0 failures)
├── ✅ SwiftData + CloudKit config
├── ✅ StoreKit sandbox + productos
├── ✅ Audio files para soundscapes
├── ✅ Localización .xcstrings
└── 🟡 Testing en device (pendiente provisioning)

FASE B — Features Competitivas ✅ COMPLETO 7/8 (Marzo 2026)
├── ✅ B4: Siri + App Intents completos
├── ✅ B5: Notificaciones con acciones
├── ✅ B1: Timer en notificación
├── ✅ B2: Widgets interactivos
├── ✅ B3: StandBy mode
├── ✅ B6: Liquid Glass theme
├── ✅ B7: iPad + Stage Manager
└── ❌ B8: macOS nativo (diferido)

APP STORE POLISH ✅ COMPLETO (Marzo 2026) — NO EN PRD ORIGINAL
├── ✅ PrivacyInfo.xcprivacy (4 targets)
├── ✅ Focus Filter entitlement + implementación
├── ✅ Accessibility improvements (timer, widgets, glass)
├── ✅ Siri phrase localization (ES + PT, 21 frases)
├── ✅ Intent donation (Siri Suggestions)
└── ✅ WritingTools en Journal (iOS 18.1+)

APPLE INTELLIGENCE ✅ COMPLETO (Marzo 2026) — NO EN PRD ORIGINAL
├── ✅ GetWeeklyReportIntent
├── ✅ GetInsightsIntent
├── ✅ GetModeSuggestionIntent
└── ✅ WeeklyReportService (servicio extraído)

FASE C — Diferenciadores (parcial)
├── ✅ C1: Session Journaling
├── ✅ C3: Apple Calendar
├── ✅ C5: Spotlight integration
├── ✅ C6: Apple Intelligence (via App Intents)
├── 🟡 C4: Shortcuts automations (parcial — donation hecho)
├── ❌ C2: Handoff entre devices
├── ❌ C7: ADHD-friendly mode
└── ❌ C8: SharePlay (futuro)

SIGUIENTE → LAUNCH
├── Testing en device real
├── TestFlight beta (100+ users)
├── Bug fixes
├── App Store screenshots + preview video
├── ASO en 3 idiomas
├── Submission
└── Marketing (ProductHunt, Reddit, LATAM blogs)
```

---

## Timeline Actualizado

| Fase | Duración | Target |
|------|----------|--------|
| Fase A: Setup Xcode | ✅ Completo | Marzo 2026 |
| Fase B: Features competitivas (7/8) | ✅ Completo | Marzo 2026 |
| App Store Polish + Apple Intelligence | ✅ Completo | Marzo 2026 |
| Fase C: Diferenciadores (4/8) | ✅ Parcial | Marzo 2026 |
| TestFlight Beta | 2 semanas | Abril 2026 |
| Bug fixes + Polish | 2 semanas | Abril-Mayo 2026 |
| App Store Launch | — | Mayo-Junio 2026 |
| Fase C restante | Rolling (post-launch) | Jun-Oct 2026 |

**Target agresivo:** Lanzamiento Mayo 2026 (adelantado vs plan original — Fases A+B completadas en tiempo récord)

**Target conservador:** Junio 2026 (antes de iOS 26 release en septiembre, con Liquid Glass ya implementado → candidato a "App destacada" de Apple)

---

## Métricas de Éxito Actualizadas

| Métrica | Target | Stretch |
|---------|--------|---------|
| App Store rating | ≥ 4.6 | ≥ 4.8 |
| D7 retention | ≥ 25% | ≥ 35% |
| D30 retention | ≥ 20% | ≥ 30% |
| Premium conversion | ≥ 6% | ≥ 10% |
| Sessions from outside app (widget/watch/siri) | ≥ 40% | ≥ 60% |
| Multi-mode usage (≥2 modes tried) | ≥ 30% | ≥ 50% |
| Watch install rate | ≥ 15% | ≥ 25% |

---

## Decisiones Estratégicas Confirmadas

1. **Solo ecosistema Apple** — No Firebase, no Google, no cross-platform sync con Android
2. **Sign in with Apple only** — Simplifica auth, no necesitamos backend de usuarios
3. **CloudKit para sync** — Gratis, privado, nativo. Sin servidor propio.
4. **StoreKit 2 nativo** — Sin RevenueCat. Menos dependencias, más margen.
5. **Android independiente** — La app Flutter sigue su propio roadmap
6. **LATAM pricing** — Precios regionales en App Store Connect desde día 1
7. **Liquid Glass first** — Adoptar iOS 26 design desde launch para editorial de Apple
8. **Apple Intelligence via App Intents** — En vez de Writing Tools API (PRD original), se implementaron 3 intents que exponen productividad a Siri/Shortcuts directamente
9. **macOS diferido** — B8 pospuesto para priorizar launch. Menu bar timer para v1.1.
10. **Privacy Manifest desde día 1** — Bloqueante para App Store, implementado para todos los targets

---

## Archivos Nuevos Creados (Fase B + App Store Polish + AI)

| Archivo | Descripción |
|---------|-------------|
| `App/PrivacyInfo.xcprivacy` | Privacy manifest principal (UserDefaults + SystemBootTime) |
| `PepinilloWidget/PrivacyInfo.xcprivacy` | Privacy manifest widget (UserDefaults) |
| `PepinilloWatch/PrivacyInfo.xcprivacy` | Privacy manifest watch (UserDefaults) |
| `ControlCenterExtension/PrivacyInfo.xcprivacy` | Privacy manifest control center (UserDefaults) |
| `Shared/Design/GlassModifier.swift` | Liquid Glass modifier centralizado (iOS 26+ / fallback) |
| `Domain/Services/WeeklyReportService.swift` | Servicio puro para reporte semanal (TCA + Siri) |
| `PepinilloIntents/GetWeeklyReportIntent.swift` | Siri: "How was my focus this week?" |
| `PepinilloIntents/GetInsightsIntent.swift` | Siri: "Give me focus insights" |
| `PepinilloIntents/GetModeSuggestionIntent.swift` | Siri: "What mode should I use?" |
| `PepinilloIntents/FocusSessionRecord+DTO.swift` | Extensión toDTO() para intents |
| `PepinilloIntents/AppShortcuts.xcstrings` | Localización Siri phrases (21 frases, EN/ES/PT) |
