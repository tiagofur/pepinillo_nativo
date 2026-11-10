# Registro de Skills — Software Factory de Pepinillo

Este registro mapea **roles cognitivos**, **contextos de stack** y skills
globales G-ODD a sus rutas canónicas y reglas de activación.

---

## 1. Skills de rol cognitivo (locales al proyecto, orientados a tarea)

Separamos **roles cognitivos de tarea** del **conocimiento de stack**. Cada
unidad de ejecución carga exactamente un skill de rol cognitivo primario:

| Skill | Ruta | Disparador / regla de activación |
| :--- | :--- | :--- |
| `leader` | `.agents/skills/leader/SKILL.md` | Orquestar una issue de extremo a extremo (`C1`–`C5`), elegir G-ODD `Inline Direct` vs `Delegated Direct`, despachar workers acotados, generar paquetes stateless de revisión (`scripts/factory_handoff.py`) o preparar la entrega del PR (`scripts/check_pr_metadata.py`). |
| `explorer` | `.agents/skills/explorer/SKILL.md` | Mapeo read-only de código/contexto (handoff `<2k` tokens con evidencia `path:line`) O triage de GitHub Issues convirtiendo `status:new` en especificaciones `status:ready` con DoR y etiquetas de taxonomía. |
| `implementer` | `.agents/skills/implementer/SKILL.md` | Implementación de único escritor en rama aislada dentro de `## Allowed edit surfaces`, flujo Contract-First OpenAPI, ejecución test-first RED → GREEN → Refactor, verificación proporcional `V0`/`V1`/`V2` y commits atómicos de unidad. |
| `reviewer` | `.agents/skills/reviewer/SKILL.md` | Revisión Independiente Stateless con Contexto Limpio (`C4`) con **cero** acceso al transcript del implementador, evaluando solo el bundle determinista de `scripts/factory_handoff.py` contra la rúbrica `P0`–`P3` y las reglas de escalado `judgment-day`. |
| `ux-brief` | `.agents/skills/ux-brief/SKILL.md` | Issue etiquetada `ux:shape` sin brief vigente: brief UX publicado como comentario de issue antes de implementar (lo ejecuta el rol `explorer`; nunca escribe código). |

---

## 2. Skills de stack y superficie (locales al proyecto, bajo demanda)

Los skills de stack se cargan **bajo demanda** por `explorer`, `implementer` o
`reviewer` cuando la tarea o las rutas tocadas coinciden con la superficie:

| Skill | Ruta | Disparadores de rutas | Disparadores de intención |
| :--- | :--- | :--- | :--- |
| `go-backend` | `.agents/skills/go-backend/SKILL.md` | `backend/**`, `*.go`, `go.mod`, `contracts/openapi.yaml` | Hexagonal Go + Fiber v2 + GORM + PostgreSQL 16/Redis 7, middleware de tiers, sincronización LWW, `go test ./...`. |
| `ios-native` | `.agents/skills/ios-native/SKILL.md` | `ios/**`, `*.swift`, `*.xcodeproj`, `*.xcworkspace` | Swift 6, TCA, SwiftUI, watchOS companion, `PepinilloMac` (SwiftUI+AppKit), `xcodebuild test` con scheme `Pepinillo Dev`. |
| `android-native` | `.agents/skills/android-native/SKILL.md` | `android/**`, `*.kt`, `*.gradle*` | Kotlin, Jetpack Compose, Coroutines/Flow, Wear OS companion, `./gradlew :app:testDebugUnitTest :wear:testDebugUnitTest`. |
| `critique` | `.agents/skills/critique/SKILL.md` | Reviews de UI/UX | Evaluar diseño desde UX, jerarquía visual, carga cognitiva, accesibilidad. |
| `frontend-design` | `.agents/skills/frontend-design/SKILL.md` | Componentes de UI | Guías de estilado UI/frontend de grado producción. |

---

## 3. Skills globales de workflow G-ODD

Instalados en el entorno global `~/.agents/skills/` del operador; gobiernan
workflows transversales de commits, slicing de PRs y revisión adversarial:

| Skill | Ruta global | Disparador / regla de activación |
| :--- | :--- | :--- |
| `work-unit-commits` | `~/.agents/skills/work-unit-commits/SKILL.md` | Planificar o cerrar una tarea G-ODD con un Conventional Commit atómico y autocontenido (código + tests + docs). |
| `chained-pr` | `~/.agents/skills/chained-pr/SKILL.md` | El pronóstico o la ejecución supera **400 líneas** cambiadas, requiriendo PRs apilados o slicing en cadena. |
| `branch-pr` | `~/.agents/skills/branch-pr/SKILL.md` | Crear ramas, abrir pull requests o validar la estructura del cuerpo y etiquetas del PR contra las plantillas del repo. |
| `judgment-day` | `~/.agents/skills/judgment-day/SKILL.md` | Revisión dual ciega en paralelo (`jd-judge-a` + `jd-judge-b`) cuando un disparador de `CHECKPOINTS.md` C4.4 se activa (el bundle reporta `judgment_day_required`). |
| `go-testing` | `~/.agents/skills/go-testing/SKILL.md` | Escribir unit tests table-driven en Go, subtests o suites con race detector. |
| `issue-creation` | `~/.agents/skills/issue-creation/SKILL.md` | Autorar o refinar GitHub Issues con criterios verificables (`S1..Sn`), exclusiones y etiquetas de taxonomía. |

---

## 4. Protocolo de resolución

1. Antes de iniciar cualquier tarea, identifica tu **rol cognitivo**
   (`leader`, `explorer`, `implementer` o `reviewer`) y lee su `SKILL.md`.
2. Inspecciona las rutas objetivo (`## Allowed edit surfaces` o rutas del diff)
   y carga todos los **Skills de Stack y Superficie** que coincidan.
3. Al delegar a un subagente, inyecta las rutas de skills resueltas
   explícitamente y exige `skill_resolution: paths-injected` en el reporte del
   worker.
