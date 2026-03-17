# PRD: Pepinillo Native Android — Deep Work Companion for Android

**Version:** 1.0
**Fecha:** 2026-03-12
**Autor:** Tiago (con Claude Code Max)
**Referencia:** PRD_IOS v2.0 (adaptación para Android)

---

## 1. Visión y Posicionamiento

### El Problema
La misma oportunidad que iOS: el mercado de "focus/pomodoro" en Android está dominado por apps de una sola técnica (Forest, Focus To-Do, Brain Focus) que compiten en precio ($2-5). Ninguna ofrece:

1. **4 técnicas de enfoque** en una sola app (Pomodoro, Flowtime, Time Block, Stopwatch)
2. **Task management integrado** con niveles de energía y recurrencia
3. **Ecosistema Android completo** (Wear OS, widgets, Quick Settings, Google Assistant)
4. **Analítica de modos** para que el usuario descubra qué técnica le funciona mejor
5. **Precios LATAM-first** accesibles

### Posicionamiento
> "La única app de deep work diseñada para Android. Cuatro técnicas de enfoque. Tareas integradas. Todos tus dispositivos Android. Elige cómo te enfocas — Pepinillo se adapta a ti."

**Tier competitivo:** Premium ($25-40/año), no el mercado de timers gratis.

### Diferencias clave vs. versión iOS

| Aspecto | iOS | Android |
|---------|-----|---------|
| Stack | Swift + TCA + SwiftData | Kotlin + MVI (Circuit/Orbit) + Room |
| Sync | CloudKit | Backend propio (Go API) |
| Reloj | watchOS (SwiftUI) | Wear OS (Compose) |
| Widgets | WidgetKit | Glance (Jetpack Compose) |
| Live Activities | ActivityKit + Dynamic Island | Rich Ongoing Notifications |
| Asistente | Siri Shortcuts (App Intents) | Google Assistant App Actions |
| Control Center | Control Widget (iOS 18) | Quick Settings Tile |
| Health | Apple HealthKit | Google Health Connect |
| Pagos | StoreKit 2 | Google Play Billing 7 |
| Focus Mode | Apple Focus Filters | Android Focus Mode / DND |

---

## 2. Usuarios Objetivo

| Segmento | Descripción | Prioridad |
|----------|-------------|-----------|
| 🎯 Power users Android | Samsung/Pixel, buscan productividad premium | P0 |
| 🎓 Estudiantes LATAM | Precio accesible, español/portugués | P0 |
| 💼 Remotos | Necesitan estructura, Pomodoro + Time Blocks | P0 |
| 🧠 ADHD community | Múltiples técnicas para diferentes estados mentales | P1 |
| ⌚ Wear OS users | Quieren controlar timer desde el reloj | P1 |
| 🖥️ Tablet users | Samsung tablets, split-screen productivity | P2 |

---

## 3. Funcionalidades

### P0 — Must-Have (MVP)

| Feature | Descripción | Equivalente iOS |
|---------|-------------|-----------------|
| **Multi-mode Focus Engine** | 4 modos (Pomodoro, Flowtime, Time Block, Stopwatch) con Strategy pattern | FocusEngine actor |
| **Task Management** | CRUD + subtasks + energía + prioridad + pomodoro linking | TaskItem + TaskListFeature |
| **Recurring Tasks** | 5 presets (daily/weekdays/weekly/biweekly/monthly) | RecurrencePreset |
| **Home Screen Widgets** | Timer activo + stats diarios + quick-start (Glance Compose) | WidgetKit widgets |
| **Ongoing Notification** | Timer persistente con controles (pause/skip/stop) | Live Activity |
| **Lock Screen Widget** | Glance widget para lock screen (Android 14+) | Lock Screen WidgetKit |
| **Quick Settings Tile** | Toggle rápido start/stop desde panel de notificaciones | Control Center widget |
| **Wear OS app** | Timer independiente + selección de modo + complicaciones | watchOS app |
| **Google Assistant** | App Actions para iniciar sesiones por voz | Siri Shortcuts |
| **Sync con Backend** | API REST (Go backend existente) + offline-first Room | CloudKit |
| **Localization** | EN, ES, PT completos | Mismos idiomas |
| **Onboarding** | 5 pantallas: bienvenida → modos → test → config → start | Onboarding iOS |
| **Adaptive layouts** | Phone + tablet + foldable support | iPhone + iPad |

### P1 — Nice-to-Have

| Feature | Descripción |
|---------|-------------|
| **Mode Intelligence** | Sugiere mejor modo basado en historial |
| **Weekly Review** | Dashboard semanal con comparación de modos |
| **Google Health Connect** | Escribe "Mindful Minutes" a Health Connect |
| **Soundscapes** | 6 ambientes sonoros (rain, café, forest, etc.) |
| **Android Focus Mode** | Integración con Digital Wellbeing Focus Mode |
| **Google Tasks import** | Importar tareas desde Google Tasks |
| **Material You theming** | Dynamic color basado en wallpaper del usuario |
| **Streaks** | Racha de días consecutivos con focus sessions |
| **Task energy batching** | Agrupar tareas por nivel de energía |
| **Tile de Wear OS** | Tile nativa para Wear OS (Compose) |
| **Google Calendar integration** | Bloquear tiempo de focus en Google Calendar. Leer eventos para sugerir slots. Paridad con Apple Calendar (iOS). |
| **Task List en Wear OS** | Lista de tareas del día en reloj con mark-complete. Paridad con Apple Watch. |

---

## 4. Monetización

### Tiers

| Tier | Precio US | Precio LATAM | Incluye |
|------|-----------|--------------|---------|
| **Free** | $0 | $0 | Pomodoro + Stopwatch, 3 tareas max, 1 widget, stats 7 días |
| **Pro Monthly** | $4.99/mo | $2.99/mo | Todo: 4 modos, tareas ilimitadas, widgets, Wear OS, sync |
| **Pro Annual** | $34.99/yr | $19.99/yr | Igual que monthly, ~40% descuento |
| **Lifetime** | $79.99 | $49.99 | Todo para siempre |

### Implementación
- **Google Play Billing Library 7** (BillingClient 7.x)
- Verificación server-side via Go backend (ya existe el endpoint)
- Restore purchases via Google Play account
- Grace period: 3 días para renovación fallida

---

## 5. Métricas de Éxito

| Métrica | Objetivo | Cómo |
|---------|----------|------|
| Play Store rating | ≥ 4.5 ★ | In-app review prompt después de 5+ sesiones |
| Multi-mode adoption | ≥ 50% usuarios prueban 2+ modos en 14 días | Onboarding + sugerencias |
| Premium conversion | ≥ 6% free → paid | Paywall strategy + LATAM pricing |
| Session completion rate | ≥ 70% | UX pulida, notificaciones, Wear OS |
| DAU/MAU | ≥ 40% | Widgets + notifications + recurring tasks |
| Wear OS engagement | ≥ 30% de sessions iniciadas desde reloj | Complicaciones + tile |
| Crash-free sessions | ≥ 99.5% | Firebase Crashlytics |

---

## 6. Requisitos No-Funcionales

| Área | Requisito |
|------|-----------|
| **Min SDK** | API 26 (Android 8.0) — Widgets avanzados: API 33+ |
| **Target SDK** | API 35 (Android 15) |
| **Offline** | 100% funcional sin internet; sync al reconectar |
| **Performance** | Cold start < 1.5s; timer drift < 100ms |
| **Battery** | Foreground Service con notificación; no wake locks innecesarios |
| **Accessibility** | TalkBack, font scaling, high contrast, reduce motion |
| **Security** | HTTPS only, encrypted SharedPreferences, no tracking |
| **Size** | APK < 15MB (sin soundscapes); < 30MB (con soundscapes) |

---

## 7. Riesgos

| Riesgo | Impacto | Probabilidad | Mitigación |
|--------|---------|--------------|------------|
| Fragmentación Android (Samsung, Pixel, Xiaomi...) | Alto | Alta | Test en top 5 OEMs; usar Jetpack libraries |
| Battery optimization kills foreground service | Alto | Media | Foreground Service tipo `SPECIAL_USE`; guiar usuario a desactivar battery optimization |
| Wear OS adoption baja | Medio | Media | Wear OS es P1, no bloquea launch |
| Google Play Billing complexity | Medio | Media | Usar billing-ktx wrappers; test con testing tracks |
| Solo developer bandwidth (iOS + Android) | Alto | Alta | Reusar lógica de negocio; Android después de iOS launch |
| Scope creep con features exclusivas Android | Medio | Media | Strict parity con iOS primero |

---

## 8. Feature Parity Matrix: Flutter → Android Native

| Feature | Flutter actual | Android Native v1 |
|---------|---------------|-------------------|
| Pomodoro timer | ✅ | ✅ (Strategy pattern) |
| Stopwatch | ✅ | ✅ (Strategy pattern) |
| Flowtime | ❌ | ✅ |
| Time Block | ❌ | ✅ |
| Tasks CRUD | ✅ (SharedPrefs) | ✅ (Room + backend sync) |
| Subtasks | ✅ | ✅ |
| Recurring tasks | ❌ | ✅ |
| Dashboard/Stats | ✅ (básico) | ✅ (modo comparison) |
| Themes | ✅ (custom) | ✅ (Material You dynamic) |
| Firebase Auth | ✅ | ➡️ Backend JWT auth |
| Cloud sync | ✅ (Firestore) | ✅ (Go backend REST) |
| Home widgets | ❌ | ✅ (Glance Compose) |
| Ongoing notification | ❌ | ✅ (Rich notification) |
| Wear OS | ❌ | ✅ |
| Google Assistant | ❌ | ✅ (App Actions) |
| Quick Settings | ❌ | ✅ (TileService) |
| Health Connect | ❌ | ✅ |
| Soundscapes | ❌ | ✅ |
| Localization (EN/ES/PT) | ✅ | ✅ |
| RevenueCat payments | ✅ | ➡️ Google Play Billing |
| Offline mode | Parcial | ✅ (Room offline-first) |

---

## 9. Timeline de Alto Nivel

| Fase | Semanas | Foco |
|------|---------|------|
| **Phase 1:** Foundation | 1-10 | Proyecto, arquitectura, Focus Engine, Tasks, Room, Auth |
| **Phase 2:** Ecosystem | 11-18 | Widgets, Notifications, Wear OS, Assistant, Tablet |
| **Phase 3:** Polish | 19-25 | Health Connect, Soundscapes, Mode Intelligence, Billing, Weekly Review |
| **Phase 4:** Launch | 26-29 | Internal testing, Play Store, beta, marketing, launch |

**Target:** Q4 2026 (después de iOS launch en Q3 2026)

---

## 10. Decisiones Arquitectónicas Clave

1. **Kotlin-first, no KMP** — App nativa pura para máxima integración con Android APIs
2. **Jetpack Compose** — UI declarativa, misma filosofía que SwiftUI
3. **MVI con Circuit** — Equivalente más cercano a TCA; unidirectional data flow + testabilidad
4. **Room + backend sync** — No hay equivalente a CloudKit; usar Go backend existente con offline-first Room
5. **Foreground Service** — Para timer accuracy en background (no hay Live Activities en Android)
6. **Glance Compose** — Widgets modernos con Compose, no RemoteViews legacy
7. **Hilt** — DI estándar de Android, constructor injection como en iOS
8. **Gradle version catalogs** — Dependency management limpio

> Ver `03_TECHNICAL_ARCHITECTURE.md` para detalles completos de implementación.
