# PRD v2 — Pepinillo (fuente de verdad de producto)

**Versión**: 2.0 (consolidación 2026-11-10 de la serie legacy `PRD/01..14`,
archivada en `docs/legacy/PRD/`)
**Cadencia**: se actualiza en el mismo PR que introduzca el cambio de alcance.

Pepinillo es un **compañero nativo de deep work** que ayuda a planificar trabajo
con sentido, entrar en sesiones de foco y entender los patrones de
productividad. El bucle canónico es `Plan → Focus → Complete → Reflect`.

Pepinillo **no es**: un gestor de tareas genérico, una plataforma de gestión de
proyectos, ni una competición de features contra cada app de productividad.

---

## 1. Fase y prioridades

Fase actual: **Validación de Crecimiento**. La pregunta ya no es "¿se puede
construir?", sino "¿los usuarios vuelven, crean hábito y pagan?".

Prioridades en orden:
1. **Activación**: de instalación a primera sesión completada con mínima fricción.
2. **Retención**: bucle Focus → Complete → Return (D1/D7/D30, rachas, reviews).
3. **Monetización**: claridad del paywall y conversión de los dos tiers.
4. **Confiabilidad**: calidad de producción en plataformas activas.

Embudo a medir (`docs/strategy/GROWTH_VALIDATION_PLAN.md`): install →
onboarding → tarea → primera sesión → sesión completada → retorno D1 → uso
semanal → paywall → conversión.

---

## 2. Usuario objetivo

Knowledge workers, estudiantes, trabajadores remotos y creativos (LATAM-first)
que hacen deep work a diario. Contextos: escritorio Mac, lock screen de phone,
Apple Watch / Wear OS tile, Siri/Assistant. Cada segundo de fricción entre
"quiero enfocarme" y "timer corriendo" es un fallo de producto.

---

## 3. Pilares canónicos

- **Focus** (experiencia primaria): sesión activa con mínima fricción.
- **Plan**: las tareas existen para soportar la ejecución enfocada.
- **Reflect**: analíticas y reviews que revelan qué modos funcionan mejor.
- Shell phone canónica: **`Focus / Plan / Dashboard / More`** (iOS y Android).
  En macOS la navegación es sidebar (`Focus`, `Plan`, `Dashboard`) + Account.

---

## 4. Motor de foco (4 modos)

| Modo | Regla | Free/Premium | Fases backend |
| :--- | :--- | :--- | :--- |
| **Pomodoro** | Intervalos estructurados (25/5/15 default, ciclo largo, auto-advance) | **Free** | `work`, `short_break`, `long_break` |
| **Flowtime** | Count-up; descansos sugeridos (<25→5, <50→8, <90→10, ≥90→15 min) | Pepinillo+ | `flow`, `break` |
| **Time Block** | Duración planificada (60 min default) + midpoint check-in opcional | Pepinillo+ | `work`, `check_in` |
| **Stopwatch** | Count-up libre | **Free** | `freeform` |

Invariantes del motor: anclaje a wall-clock (sobrevive al sleep/kills),
recuperación de sesión huérfana (ghost resume/discard), hold de espera de fase
con skip, stats por modo. Paridad funcional obligatoria en iOS, watchOS, macOS,
Android y Wear OS (`AGENTS.md` §3).

---

## 5. Tareas

- CRUD, subtareas, prioridad, energía (`deep`/`shallow`/`admin`), fechas,
  categoría, estimación de pomodoros.
- **Recurrencia**: reglas RRULE-like con generación server-side (ventana
  rodante 14 días, cron 24 h) y generación manual (hasta 370 días), con lock
  anti-duplicación (`recurrence_window_in_progress`).
- **Import**: Apple Reminders (iOS) y EventKit Calendar (iOS); calendario
  propio multiplataforma para planear sesiones alrededor del schedule.
- Límite Free: **3 tareas activas**.
- Las tareas se vinculan opcionalmente a sesiones (`taskId`, `taskSyncId`);
  el linking nunca es requisito para iniciar foco.

---

## 6. Modelo comercial (v3.1, Apple-first)

Principio de transparencia: **Pepinillo+ se comunica siempre como "una compra.
Tuya para siempre. No es una suscripción."** No se promociona valor no
entregado: las features "Próximamente" solo aparecen dentro del paywall.

| Capa | Oferta | Tipo | Precio global | Precio LATAM | Entitlement / producto |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | **Free** | Gratis | — | — | Pomodoro + Stopwatch, 3 tareas, 7 días de analítica, widgets base |
| 2 | **Pepinillo+** | Compra única | **$19.99** | **$9.99** | `pepinillo_plus` / `com.pepinillo.app.pro.lifetime`: Flowtime + Time Block, subtareas, recurrencia, premium local, soundscapes pro, analítica completa, widgets premium, companion de reloj, iCloud sync (Apple), **IA on-device** (Foundation Models + fallback plantilla), export |
| 3 | **Everywhere/AI+** | Suscripción | **$4.99/mes · $34.99/año** | **$2.49/mes · $17.99/año** | `everywhere_plus` / `pro.monthly`·`pro.annual`: todo lo de Pepinillo+ **+ backend sync multi-dispositivo** (LWW), recovery por cuenta, **IA cloud** (100 créditos/mes) |

Claims permitidos en paywall (verificados por
`ios/Tests/PaywallFeatureTests/PaywallCommercialClaimsTests.swift`): **4 claims
Pepinillo+** (appleCloudSync, onDeviceAI, fullLocalApp, exportAccess) y **3
claims Everywhere** (pepinilloCloudSync, accountRecovery, pepinilloPlusIncluded).
Palabras prohibidas en copy de producción: "cloud ai", "server ai", "ai credit",
"cross-platform", "mac", "web", "windows", "vps".

Mapeo legacy (retrocompatibilidad): `premium`/`pro` → `.pepinilloPlus` (sin
expiración) o `.everywherePlus` (con expiración).

---

## 7. Plataformas

### Activas (paridad funcional obligatoria)
**iOS 17+ / iPadOS 17+**, **watchOS 10+**, **macOS 15+ (`PepinilloMac`)**,
**Android (minSdk 29)**, **Wear OS (minSdk 26)**, **Backend Go**.

### En pausa (no expandir sin autorización explícita)
- **Web (`web/`)**: companion Svelte 5/SvelteKit 2 con shell offline W1 y
  auth/sync W2 explorados; solo regresa con demanda clara de usuarios o
  justificación de negocio.
- **Windows (`windows/`)**: viabilidad técnica validada (W0–W15); solo regresa
  con tracción móvil probada.

Detalles: `docs/strategy/PLATFORM_DECISIONS.md`.

---

## 8. Posicionamiento y marca

- Nombre oficial: **Pepinillo** (sin nombres alternativos en docs, stores ni
  marketing). Publicado por **Creapolis**.
- Voz: premium pero no solemne; el contraste juguetón del nombre contra la
  seriedad del deep work. Calmado y claro, **no** somnoliento ni meditativo.
- Norte estético: como si Apple hubiera construido la app Apple y Google la
  Android. HIG-first / Material 3 Expressive (`docs/design.md`).
- Términos y privacidad publicados: `https://creapolis.dev/terms-of-use/` y
  `https://creapolis.dev/privacy-policy/`.

---

## 9. Qué no construir ahora (sin aprobación explícita)

Nuevas plataformas; grandes expansiones de IA (más allá de lo entregado);
features de colaboración; sistemas de productividad complejos (proyectos,
dependencias, Gantt); features enterprise.

Regla antes de cualquier feature mayor: ¿mejora activación, retención o
ingresos? Si la respuesta no es clara, se documenta y se espera.
