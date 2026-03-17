# Guía de Colaboración con Claude Code — Android

**Versión:** 1.0
**Fecha:** 2026-03-12

---

## 1. Dónde Claude Code Brilla en Android

| Tarea | Efectividad | Notas |
|-------|-------------|-------|
| Room entities + DAOs | ⭐⭐⭐⭐⭐ | Boilerplate pesado, Claude lo genera perfecto |
| Circuit Presenters | ⭐⭐⭐⭐⭐ | MVI pattern es muy estructurado |
| Compose UI screens | ⭐⭐⭐⭐ | Describe la pantalla, Claude la implementa |
| Domain models (traducir de iOS) | ⭐⭐⭐⭐⭐ | 1:1 translation Swift → Kotlin |
| Strategy pattern implementation | ⭐⭐⭐⭐⭐ | Ya está diseñado en iOS, solo traducir |
| Glance widgets | ⭐⭐⭐⭐ | Layout composable, Claude maneja bien |
| Hilt modules | ⭐⭐⭐⭐⭐ | Muy repetitivo, ideal para Claude |
| Unit tests | ⭐⭐⭐⭐⭐ | JUnit + Turbine, patterns claros |
| String resources (EN/ES/PT) | ⭐⭐⭐⭐⭐ | Traducción + XML formatting |
| Ktor API client | ⭐⭐⭐⭐ | Endpoints ya definidos en Go backend |
| AndroidManifest entries | ⭐⭐⭐⭐ | Services, receivers, permissions |
| Version catalog (TOML) | ⭐⭐⭐⭐⭐ | Dependency declaration |

### Dónde Claude Code Necesita Guía Humana

| Tarea | Efectividad | Razón |
|-------|-------------|-------|
| Foreground Service lifecycle | ⭐⭐⭐ | Android lifecycle es complejo, OEM differences |
| Play Billing integration | ⭐⭐ | Requires real Play Console testing |
| Wear OS real-device behavior | ⭐⭐ | Emulator ≠ reality for Wear OS |
| OEM-specific battery issues | ⭐ | Requires physical device testing |
| Performance profiling | ⭐⭐ | Android Studio Profiler required |
| Play Store submission | ⭐ | Manual process in Play Console |
| Visual design decisions | ⭐⭐ | Tiago decides look & feel |
| Sync conflict edge cases | ⭐⭐⭐ | Need real-world scenarios |

---

## 2. Workflow Recomendado

### Sesión Tipo (3-4 horas)

```
1. Morning Planning (15 min)
   └─ Revisar lo hecho ayer, definir 2-3 tareas del día

2. Claude Code Scaffolding (45 min)
   └─ "Crea el Room entity para TaskEntity basándote en TaskItem.swift de iOS"
   └─ "Genera el Circuit Presenter para TaskList siguiendo el patrón de FocusPresenter"

3. Review & Adjust (30 min)
   └─ Revisar código generado, ajustar UI, correr en emulador

4. Claude Code Implementation (90 min)
   └─ "Implementa el sync engine para tasks: dirty flag, push, pull, merge"
   └─ "Agrega tests para TaskListPresenter usando Circuit test utilities"

5. Evening Review (30 min)
   └─ Correr tests, commit, planear mañana
```

### Prompts de Inicio de Sesión

#### Nuevo Feature
```
Lee PRD_ANDROID/03_TECHNICAL_ARCHITECTURE.md y PRD_ANDROID/01_PRD_PEPINILLO_ANDROID.md.

Implementa [FEATURE] para Android siguiendo:
1. Domain model en domain/model/
2. Room entity en data/local/entity/
3. DAO en data/local/dao/
4. Repository interface + implementation
5. Circuit Presenter
6. Compose Screen
7. Tests

Usa el mismo patrón que [EXISTING_FEATURE] como referencia.
Traduce la lógica del equivalente iOS: [iOS_FILE_PATH]
```

#### Traducir desde iOS
```
Traduce este archivo Swift a Kotlin para Android:
- [path/to/swift/file]

Reglas:
- Swift actor → Kotlin class with coroutines
- TCA Reducer → Circuit Presenter
- SwiftData @Model → Room @Entity
- SwiftUI View → @Composable function
- @Dependency → @Inject (Hilt)
- async/await → suspend functions
- Combine → Flow/StateFlow
- String(localized:) → stringResource()
```

#### Bug Fix
```
El [FEATURE] tiene un bug: [DESCRIPCIÓN].
1. Lee los archivos relevantes
2. Identifica la causa
3. Propón fix
4. Implementa y agrega test de regresión
```

#### Test Writing
```
Genera tests para [PRESENTER/REPOSITORY/SERVICE]:
- Usa JUnit 5 + Turbine para Flow testing
- Usa MockK para mocks
- Circuit Presenter.test {} para presenter tests
- Cubre: happy path, edge cases, error handling
- Sigue el patrón AAA (Arrange, Act, Assert)
```

---

## 3. Archivos Clave a Cargar en Contexto

Siempre carga estos archivos al inicio de sesión:

```
# Siempre
PRD_ANDROID/01_PRD_PEPINILLO_ANDROID.md
PRD_ANDROID/03_TECHNICAL_ARCHITECTURE.md
CLAUDE.md

# Para features específicos
PRD_ANDROID/siguientes-pasos.md       # Estado actual

# Referencia iOS (para traducción)
apps/ios_nativa/Domain/Models/         # Models a traducir
apps/ios_nativa/Features/Focus/        # Focus engine reference
apps/ios_nativa/Features/Tasks/        # Task management reference
```

---

## 4. Integración SDD (Spec-Driven Development)

Para features complejas, usar el workflow SDD:

```bash
# Iniciar spec para un feature Android
/sdd:new android-focus-engine

# Fast forward (crear proposal → specs → design → tasks)
/sdd:ff android-focus-engine

# Implementar
/sdd:apply android-focus-engine

# Verificar
/sdd:verify android-focus-engine
```

### Features que ameritan SDD
- Focus Engine + Strategy Pattern (complejo)
- Sync Engine (Room ↔ Backend)
- Play Billing integration
- Wear OS communication layer

### Features que NO ameritan SDD
- Room entities (boilerplate directo)
- String translations
- Quick Settings Tile (simple)
- Individual screens (Compose straightforward)

---

## 5. Tips para Maximizar Claude Code Max 5x

### DO
- ✅ Batch related files: "Crea los 4 Strategy implementations juntos"
- ✅ Provide iOS reference: "Traduce FocusModels.swift y FocusEngine.swift a Kotlin"
- ✅ Use sub-agents for research: "Investiga Glance Compose best practices 2026"
- ✅ Generate tests alongside code: "Implementa + tests en la misma sesión"
- ✅ Let Claude scaffold, you refine: Don't micro-manage layout pixels

### DON'T
- ❌ Ask Claude to debug on real device (can't see device)
- ❌ Have Claude configure Play Console (web UI, not code)
- ❌ Ask for pixel-perfect Figma-to-Compose (describe, don't screenshot)
- ❌ Try to do sync engine in one shot (iterate in 2-3 sessions)
- ❌ Skip tests ("I'll add them later" = they never get added)

---

## 6. Checklist Pre-Coding (Setup Manual)

Antes de que Claude Code pueda ser efectivo, configura esto manualmente:

- [ ] Android Studio instalado con SDK 35
- [ ] Proyecto creado: `com.pepinillo.android`
- [ ] Gradle version catalogs configurado
- [ ] Hilt plugin agregado
- [ ] Room KSP processor configurado
- [ ] Firebase project creado (Analytics + Crashlytics)
- [ ] Google Play Console: app registrada
- [ ] Wear OS module creado en el proyecto
- [ ] Emuladores: Pixel 8 (API 35) + Wear OS (API 34)
- [ ] Go backend corriendo localmente (`docker compose up`)
- [ ] Signing keys generados (debug + release)
