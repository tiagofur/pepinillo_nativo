# web-ipad-parity — Web igual al iPad (igual al iPhone en pequeño), rebuild desde cero
Objective: web/ nueva con Vite + pnpm + React-TS + CSS propio estilo Liquid Glass que replique al iPad en grande (sidebar) y al iPhone en pequeño (tabs abajo), con las funciones del iPad que se puedan portar. Commits por partes, sin PR.
Branch: `feat/web-ipad-parity` | Delivery: `single-branch slices, no PR (user decision)` | Test runner: `cd web && pnpm build` (greenfield: sin suite previa; verificación = build + smoke del dev server)
Forecast: ~6 slices (T0 retiro+spec, T1 scaffold, T2 shell, T3 foco, T4 tareas, T5 dashboard/ajustes/onboarding). Mirror Engram: pending (sin herramienta Engram en esta sesión; el archivo es la fuente).

## Specs

- **S1**: "quiero que la app web sea igual a la app para iPad, porque tenemos mucho espacio en pantalla" — en ancho grande la web replica el iPad: `TabView(.sidebarAdaptable)` → sidebar (`ios/App/AppView.swift:326`), tabs Focus/Plan/Dashboard/More (`ios/App/AppFeature.swift:178-201`).
- **S2**: "si acaso el usuario quiera hacerla pequeña que sera igual a la app iOS" — en estrecho/pequeño la web replica el iPhone: bottom tabs (`ios/App/AppView.swift:338-355`); en retrato angosto iPad usa barra superior compacta (`ios/App/AppView.swift:271-281`): web usa top-bar < 768px o retrato, bottom-tabs en ancho teléfono.
- **S3**: "quiero todo lo mas igual posible... con las funciones que puedas poner de la app a la web" — paridad funcional best-effort: motor de foco 4 modos (Pomodoro/Flowtime/Block/Stopwatch, `ios/Features/Focus/FocusModels.swift:13-63`), defaults 25/5/15 ×4 (`FocusModels.swift:131-136`), bloque 60 min, flowtime mín 5 min; gating free (pomodoro+stopwatch gratis, flowtime+block bloqueados, `FocusModels.swift:57-62`); tareas/plan; dashboard; ajustes con 3 apariencias (light/dark/system, `.impeccable.md`); onboarding.
- **S4**: "hagas todo de una vez solo haciendo commits por partes sin PR de momento, quiero probarla" — todo el alcance en esta misión, un commit por slice en la rama, sin push ni PR; el usuario prueba con `pnpm dev`.
- **S5**: "crea una carpeta nueva web dentro del repo" — todo el código nuevo vive en `web/`.
- **S6**: "no escribas archivos de json o que sea para crear la app o dependencias las creas mediante vite, mediante pnpm" — `package.json`, lockfile y scaffolding SOLO vía `pnpm create vite` + `pnpm install`; nunca escritos a mano.
- **S7**: "si no crees necesario tailwind podemos crear nuestro propio CSS para tener mas control o aprovechas alguna plantilla de macos 27 en CSS con liquid glass" — decisión: CSS propio (sin Tailwind) con vocabulario Liquid Glass iOS 26 (`.glassEffect`, siempre activo, `.impeccable.md`); superficies quietas, acento verde de marca en la navegación (`ios/App/AppView.swift:328-331`).

## Allowed edit surfaces

- `web/` (todo lo nuevo)
- `odd/tasks/web-ipad-parity.md` (este documento)
- Retiro en T0: deletions ya existentes en worktree de `web/` legacy (SvelteKit) — autorizadas por decisión L2; el historial las conserva.

## Tasks

- [x] **T0** (`S4, S5`, route: `inline`, commit: `d7e7545c`, checks: `git status` limpio PASS, recovery `refs/tbh/recovery/before-discard/20261115T175547Z-95083`): rama + retirar web legacy + este documento con commit.
- [x] **T1** (`S5, S6`, route: `inline`, commit: `0dcaf803`, checks: `cd web && pnpm install && pnpm build` PASS — 20 módulos, dist OK): scaffold `pnpm create vite web --template react-ts`, install, build verde.
- [x] **T2** (`S1, S2, S7`, route: `inline`, commit: `f65e1a26`, checks: `pnpm build` PASS (tsc + vite, 16 módulos), smoke visual pendiente de T5: shell con sidebar ≥1024px apaisado, pill superior en retrato/angosto, tabs abajo en teléfono + temas light/dark/system + CSS Liquid Glass propio. Nota: T2 ≈470 líneas (un solo comportamiento coherente: sistema CSS + nav + 4 vistas).
- [x] **T3** (`S3`, route: `inline`, commit: `(este commit)`, checks: `pnpm vitest run` 10/10 PASS + `pnpm build` PASS): motor de foco 4 modos con defaults y gating free de S3 (engine puro + hook con reloj por timestamps, pausa, saltar descanso, journal en localStorage con aviso visible y reintento).
- [ ] **T4** (`S3`, route: `inline`, status: `todo`, commit: `-`, checks: `pnpm build` PASS): tareas y plan básico con persistencia local.
- [ ] **T5** (`S3, S4`, route: `inline`, status: `todo`, commit: `-`, checks: `pnpm build` PASS + `pnpm dev` smoke): dashboard, ajustes (3 apariencias), onboarding; cierre y reporte.

## Log

- **L1 (2026-11-15)**: User request verbatim:
  `amigo, algo MUY IMPORTANTE, tenemos que hacer al app Web... pero es una mision MUY ESPECIAL... quiero que la app web sea igual a la app para iPad, porque tenemos mucho espacio en pantalla, y si acaso el usuario quiera hacerla pequeña que sera igual a la app iOS... quiero todo lo mas igual posible... hagas lo mas igual posible, con las funciones que puedas poner de la app a la web... hagas todo de una vez solo haciendo commits por partes sin PR de momento, quiero probarla.. si las haces a la perfeccion comprare el dominio de pepinillo.app todo depende de ti, tambien a futuro podemos hacer una extension para chrome porque ya tengo el registro de developer para extensiondes de chrome, asi que el futuro del entorno web de pepinillo depende solo de ti, asi que hazlo a la perfeccion. cre una carpeta nueva web dentro del repo y manos a la obra... ojo no escribas archivos de json o que sea para crear la app o dependencias las cres mediante vite, mediante pnpm... etc... si no crees necesario tailwind podemos crear nuestro propio CSS para tener mas control o aprovechas alguna plantilla de macos 27 en CSS con liquid glass y todo lo mas chico de apple adelante`
- **L2 (2026-11-15)**: Decisión del usuario (pregunta única ODD, respondida `Rehacer desde cero`): NO restaurar la web legacy; rebuild desde cero. La web legacy existe en HEAD (SvelteKit 2 + Vite 8 + pnpm, commits `313813ec` W1 shell, `2d651f65` e2e/smoke, `59980cfd` W2 auth/entitlements/sync, `22bab820` sync bidireccional) y queda retirada del worktree; el historial la conserva.
- **L3 (2026-11-15)**: Evidencia de paridad iPad (fija S1–S3): tabs Focus(`brain.head.profile`)/Plan(`checklist`)/Dashboard(`chart.bar.fill`)/More(`ellipsis.circle`); breakpoint iPad retrato `width < 768 || width <= height` → top-bar; iPhone → bottom tabs; acento verde en navegación; modos con nombres/iconos/dirección/free-tier según `FocusModels.swift`.
- **L4 (2026-11-15)**: Trabajo movido a worktree nuevo `/tmp/pepinillo-web-ipad-parity`, rama `feat/web-ipad-parity` (base `f31abfff`), a petición del usuario. El doc vive solo aquí.
