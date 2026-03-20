# Roadmap Unificado — Pepinillo (iOS + Android)

**Fecha:** Marzo 2026
**Versión:** 1.0

---

## 1. Supuestos

- **Desarrollador:** Tiago (solo) + Claude Code Max 5x
- **Horas/semana:** 20-30 horas
- **iOS empezó primero**, Android segundo
- **Reutilización estimada:** ~40% del diseño y lógica de negocio se traduce directamente de iOS a Android (Strategy pattern, modelos de dominio, flujos de UX)
- **Backend Go:** compartido entre ambas plataformas; iOS usa CloudKit para sync local, Android usa sync engine custom contra el backend

---

## 2. Estimación de Esfuerzo Comparativa

| Área | iOS (horas) | Android (horas) | Ratio | Notas |
|------|-------------|-----------------|-------|-------|
| Motor de Enfoque (Strategy) | 80 | 55 | 0.69x | Patrón ya diseñado en iOS, solo traducir a coroutines |
| Tareas (CRUD, subtasks, recurrencia) | 60 | 45 | 0.75x | Room + Circuit vs SwiftData + TCA |
| UI (pantallas principales) | 120 | 100 | 0.83x | Compose es más verboso pero similar a SwiftUI |
| Analytics (dashboard, charts) | 24 | 20 | 0.83x | Vico (Android) vs SwiftCharts (iOS) |
| Widgets | 40 | 50 | 1.25x | Glance es más nuevo, menos documentación |
| Live Activity / Notificación | 40 | 45 | 1.13x | Foreground Service más complejo que Live Activities |
| Watch / Wear OS | 65 | 60 | 0.92x | Wear OS tiene más boilerplate |
| Siri / Google Assistant | 18 | 30 | 1.67x | App Actions XML + BII mapping vs App Intents |
| Sincronización | 20 | 70 | 3.50x | CloudKit gratis vs sync engine custom + backend |
| Auth | 10 | 30 | 3.00x | Sign in with Apple vs JWT + Go backend |
| Billing | 20 | 35 | 1.75x | Play Billing significativamente más complejo que StoreKit 2 |
| Health | 15 | 20 | 1.33x | Health Connect es API más nueva |
| Soundscapes | 25 | 25 | 1.00x | ExoPlayer ~ AVAudioPlayer |
| Onboarding | 20 | 18 | 0.90x | Compose pages son simples |
| Settings | 15 | 15 | 1.00x | DataStore vs UserDefaults |
| Localization | 15 | 12 | 0.80x | Android string resources son directos |
| Testing | 60 | 50 | 0.83x | Circuit testing es excelente |
| CI/CD + Store | 20 | 20 | 1.00x | GitHub Actions + Play Console |
| Polish + QA | 60 | 70 | 1.17x | Fragmentación Android requiere más testing OEM |
| **Total estimado** | **~814** | **~750** | **0.92x** | |

**Conclusión:** Android toma ~8% menos horas en total, pero la distribución es diferente. Las áreas donde Android es más costoso:
1. Sync engine custom (+50h vs CloudKit)
2. Auth JWT (+20h vs Sign in with Apple)
3. Play Billing (+15h vs StoreKit 2)
4. Testing OEM (+10h por fragmentación)

---

## 3. Fases — iOS

### Fase 1: Foundation (Semanas 1-11, ~268h)

**Objetivo:** App multi-modo de enfoque en iPhone con gestión de tareas y CloudKit.

| Tarea | Horas | Claude Code |
|-------|-------|-------------|
| Setup Xcode, targets, App Groups, TCA | 4h | Alto |
| SwiftData models (TaskItem, SubTask, FocusSession, DailyStats) | 10h | Alto |
| FocusModeProtocol + Strategy pattern | 8h | Alto |
| 4 estrategias (Pomodoro, Flowtime, TimeBlock, Stopwatch) | 32h | Alto |
| FocusEngine Actor (motor unificado) | 24h | Medio |
| FocusFeature TCA + FocusView SwiftUI | 36h | Alto/Medio |
| Task List + Task Detail (CRUD, reorder, swipe, subtasks) | 32h | Alto |
| Link tasks a sesiones de enfoque | 8h | Alto |
| Analytics dashboard (SwiftCharts, breakdown por modo) | 24h | Medio |
| Settings, Navigation, Notificaciones | 32h | Alto |
| Temas (4 themes + Liquid Glass) | 16h | Medio |
| Onboarding con selector de modo | 10h | Medio |
| Localización (EN, ES, PT) | 12h | Alto |
| Unit tests (4 estrategias + FocusEngine + Tasks) | 20h | Alto |

**Milestone:** App multi-modo funcional. 4 modos, tareas vinculadas, analytics con breakdown por modo. TestFlight interno.

### Fase 2: Apple Ecosystem (Semanas 12-20, ~261h)

**Objetivo:** Widgets, Live Activities, Watch, Siri, iPad, Mac -- todo consciente de los modos.

| Tarea | Horas | Claude Code |
|-------|-------|-------------|
| Home Screen Widgets (S/M/L, mode-aware) | 32h | Medio |
| Lock Screen Widget | 10h | Alto |
| Live Activity + Dynamic Island (4 UIs por modo) | 40h | Medio |
| Apple Watch app (mode picker + timer + tasks + complications) | 45h | Medio |
| Watch-Phone connectivity (sync de modos) | 20h | Bajo |
| Siri / App Intents (comandos multi-modo, 3 idiomas) | 18h | Alto |
| iPad adaptive layouts (NavigationSplitView, Stage Manager) | 16h | Alto |
| macOS target (menu bar + ventana + keyboard shortcuts) | 32h | Medio |
| CloudKit sync setup + resolución de conflictos offline | 32h | Medio |
| Integration tests | 16h | Alto |

**Milestone:** Ecosistema completo. Cada superficie de Apple conoce los 4 modos.

### Fase 3: Polish & Premium (Semanas 21-27, ~196h)

**Objetivo:** Calidad digna de suscripción. Las features que hacen que los usuarios paguen.

| Tarea | Horas | Claude Code |
|-------|-------|-------------|
| Integración Focus Modes del sistema | 12h | Medio |
| Apple Health (Mindful Minutes) | 10h | Alto |
| Soundscapes ambientales (rain, cafe, library, white noise) | 16h | Medio |
| Tareas recurrentes (iCalendar RRULE) | 12h | Alto |
| Weekly Review (comparativa semanal, tendencias) | 14h | Alto |
| Mode Intelligence (sugerir modo optimo por tipo de tarea) | 16h | Medio |
| Streaks + milestones | 10h | Alto |
| Energy levels en UI (deep/shallow/admin) | 6h | Alto |
| StoreKit 2 (paywall, tiers, precios LATAM, restore) | 22h | Medio |
| Control Center widget | 6h | Alto |
| Animaciones y micro-interacciones | 20h | Bajo |
| Accessibility audit (VoiceOver, Dynamic Type) | 12h | Alto |
| Performance optimization | 12h | Medio |
| App Store screenshots + preview video + ASO | 24h | Medio/Alto |
| Privacy Policy + Terms | 4h | Alto |

**Milestone:** Premium-ready. Soundscapes, Mode Intelligence, Weekly Review: las features que valen $35/anio.

### Fase 4: Launch (Semanas 28-31, ~89h)

| Tarea | Horas | Claude Code |
|-------|-------|-------------|
| TestFlight public beta (100+ usuarios) | 8h | N/A |
| Bug fixes de beta | 35h | Alto |
| App Store submission | 4h | N/A |
| Marketing site / landing page | 12h | Alto |
| Launch campaign (ProductHunt, Reddit, Twitter, blogs LATAM) | 10h | Medio |
| Post-launch monitoring + hot fixes | 20h | Alto |

---

## 4. Fases — Android

### Fase 1: Foundation (Semanas 1-10, ~250h)

**Objetivo:** App funcional con 4 modos, tasks, auth y sync.

| Tarea | Horas | Claude Code |
|-------|-------|-------------|
| Proyecto Android + Gradle + Hilt + CI setup | 20h | 70% |
| Room database + entities + DAOs + migrations | 25h | 80% |
| Domain models (FocusMode, FocusPhase, FocusConfig) | 15h | 90% |
| Strategy pattern: 4 estrategias de modo | 30h | 70% |
| FocusEngine (coroutines, StateFlow) | 25h | 50% |
| FocusPresenter (Circuit) + FocusScreen (Compose) | 30h | 60% |
| TaskListPresenter + TaskListScreen + TaskDetail | 25h | 70% |
| Auth (JWT login/register via Go backend) | 20h | 60% |
| Sync engine (Room - Backend, dirty flags) | 35h | 40% |
| Onboarding flow (5 pantallas, test de modo) | 20h | 80% |
| Unit tests (domain, presenters, DAOs) | 25h | 70% |

**Milestone:** App funcional con 4 modos, tasks, auth y sync.

### Fase 2: Ecosystem (Semanas 11-18, ~220h)

**Objetivo:** Ecosistema Android completo: widgets, notificacion, Wear OS, Assistant.

| Tarea | Horas | Claude Code |
|-------|-------|-------------|
| Foreground Service + ongoing notification | 30h | 50% |
| Home Screen widgets (Glance: timer + stats) | 30h | 60% |
| Quick Settings Tile | 15h | 80% |
| Wear OS: timer screen + mode picker | 35h | 50% |
| Wear OS: tile + complication + phone sync | 25h | 50% |
| Google Assistant App Actions | 20h | 70% |
| Tablet/foldable adaptive layouts | 20h | 60% |
| Material You dynamic color + theming | 15h | 80% |
| Integration tests (sync, notification, widget) | 30h | 60% |

**Milestone:** Ecosistema completo: widgets, Wear OS, Assistant, layouts adaptativos.

### Fase 3: Polish (Semanas 19-25, ~185h)

**Objetivo:** Feature-complete, listo para testing.

| Tarea | Horas | Claude Code |
|-------|-------|-------------|
| Dashboard + analytics charts (Vico) | 20h | 70% |
| Weekly Review screen | 15h | 80% |
| Mode Intelligence service | 15h | 90% |
| Soundscapes (ExoPlayer, 6 tracks) | 20h | 60% |
| Google Health Connect integration | 15h | 60% |
| Google Play Billing 7 (subscriptions) | 30h | 40% |
| Recurring task generation engine | 10h | 90% |
| Google Tasks import | 15h | 60% |
| Streaks + achievements | 10h | 80% |
| Android Focus Mode / DND integration | 10h | 60% |
| Accessibility (TalkBack, font scaling) | 10h | 50% |
| Performance optimization + ProGuard | 15h | 40% |

**Milestone:** Feature-complete, listo para testing.

### Fase 4: Launch (Semanas 26-29, ~95h)

| Tarea | Horas | Claude Code |
|-------|-------|-------------|
| Internal testing track en Play Store | 15h | 30% |
| Bug fixes de testing | 25h | 50% |
| OEM testing (Samsung, Pixel, Xiaomi, OnePlus) | 20h | 20% |
| Play Store listing (screenshots, descripcion, ASO) | 15h | 60% |
| Beta (open testing track) | 10h | 30% |
| Launch (staged rollout 10% - 50% - 100%) | 10h | 30% |

---

## 5. Timeline Visual

```
2026:
        Ene     Feb     Mar     Abr     May     Jun     Jul     Ago     Sep     Oct     Nov     Dic
iOS:    [========= Fase 1 =========][======= Fase 2 =======][===== Fase 3 =====][= F4 =]
        Foundation (268h)           Ecosystem (261h)         Polish (196h)       Launch
        Semanas 1-11                Semanas 12-20            Semanas 21-27       S28-31

Android:                                [========= Fase 1 =========][======= Fase 2 =======][== Fase 3 ==][F4]
                                        Foundation (250h)           Ecosystem (220h)         Polish (185h) Launch
                                        Semanas 1-10                Semanas 11-18            S19-25        S26-29
```

**Notas del timeline:**
- iOS inicia en Enero 2026, target de lanzamiento Septiembre 2026 (alineado con iOS 26)
- Android inicia despues del lanzamiento de iOS (Q3 2026), target Q4 2026 - Q1 2027
- El solapamiento entre Fase 4 de iOS y Fase 1 de Android es posible: bugs de beta iOS mientras se hace foundation de Android

---

## 6. Camino Critico

### iOS — Camino Critico

```
Project Setup --> SwiftData Models --> FocusModeProtocol
                                            |
                      PomodoroStrategy + FlowtimeStrategy
                      TimeBlockStrategy + StopwatchStrategy
                                            |
                                       FocusEngine (Actor)
                                            |
                                       FocusFeature (TCA)
                                            |
                                       Task Management
                                            |
                                      Link Tasks a Sessions
                                            |
                               Mode-Aware Analytics + Settings
                                            |
                                 CloudKit Sync ----> Widgets (mode-aware)
                                       |                    |
                                 Watch App          Live Activities (4 UIs)
                                 (mode picker)              |
                                       |              iPad / macOS
                                 Siri (multi-mode)
                                       |
                           Soundscapes + Mode Intelligence
                                       |
                              StoreKit 2 + Polish
                                       |
                                    LAUNCH
```

**Riesgo principal:** FocusEngine Actor es el cuello de botella. Todo depende de que el motor funcione correctamente con los 4 modos antes de poder construir widgets, Watch y Live Activities.

### Android — Camino Critico

```
Gradle setup --> Room models --> Domain models
    |                              |
Hilt DI -----------> Strategy Pattern --> FocusEngine --> FocusPresenter --> FocusScreen
                                               |
                                    Foreground Service --> Ongoing Notification
                                               |
                                         Glance Widgets
                                               |
                                          Wear OS sync

Room models --> TaskPresenter --> TaskScreen
    |
Sync Engine (requiere Auth + Room + Ktor)
    |
Backend integration tests

Play Billing ----> Paywall UI ----> Feature gating
```

**Riesgo principal:** Sync Engine es el cuello de botella de Android. A diferencia de iOS (CloudKit automatico), Android necesita un sync engine custom completo antes de poder considerar la app funcional.

---

## 7. Efectividad Claude Code

| Fase | iOS % | Android % | Mejor para | Solo humano |
|------|-------|-----------|------------|-------------|
| Fase 1 (Foundation) | 65% | 65% | Modelos, boilerplate Strategy, Circuit/TCA | Sync engine edge cases, auth flow |
| Fase 2 (Ecosystem) | 50% | 55% | Widget layouts, Tile service, App Actions/Intents | Foreground Service lifecycle, Watch real-device |
| Fase 3 (Polish) | 45% | 60% | Health, billing boilerplate, import logic | Play Billing testing, soundscape mixing |
| Fase 4 (Launch) | 40% | 35% | Store descriptions, bug triage | OEM testing, staged rollout, beta management |
| **Overall** | **~50%** | **~55%** | | |

**Impacto estimado:** Claude Code ahorra ~400-450 horas en total entre ambas plataformas, reduciendo el timeline efectivo de ~62 semanas a ~35-40 semanas.

---

## 8. Riesgos y Mitigaciones

### iOS

| Riesgo | Impacto | Mitigacion |
|--------|---------|------------|
| 4 estrategias de modo aumentan superficie de testing | +1-2 semanas | Strategy pattern mantiene modos aislados. Testear independientemente |
| UX de calculo de break en Flowtime poco clara | +1 semana | User test en beta. Formula simple primero, iterar |
| Complejidad del audio engine para soundscapes | +1 semana | AVAudioPlayer para v1 (presets simples). AVAudioEngine solo si se necesita |
| Mode Intelligence necesita 2+ semanas de datos | N/A | Enviar como fast-follow P1. Recolectar datos desde dia 1 |

### Android

| Riesgo | Impacto | Mitigacion |
|--------|---------|------------|
| Complejidad de Play Billing 7 | +1-2 semanas | Empezar temprano, usar samples de billing-ktx |
| Bugs de Wear OS DataLayer | +1 semana | MVP minimo de Wear OS primero |
| OEMs matando procesos en background | +1 semana | Guia de dontkillmyapp.com + educacion al usuario |
| Conflictos del sync engine | +1 semana | Simple last-write-wins, sin CRDT |
| Curva de aprendizaje de Circuit | +0.5 semanas | Docs de Circuit son excelentes; modelo mental similar a TCA |

### Compartidos

| Riesgo | Impacto | Mitigacion |
|--------|---------|------------|
| Backend Go no listo a tiempo | Bloquea sync Android | Priorizar endpoints criticos; iOS usa CloudKit |
| Solo developer = bus factor de 1 | Alto | Documentacion exhaustiva + Claude Code como knowledge base |
| Burnout a 25h/semana durante 60+ semanas | Alto | Fases claras con milestones celebrables. Breaks entre fases |

**Buffer total de riesgo:** +3-5 semanas por plataforma
**Timeline realista con riesgo:** iOS Sep-Nov 2026, Android Q1-Q2 2027
