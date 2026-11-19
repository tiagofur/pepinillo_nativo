# 934 — feat(guides): manuales iPhone + watchOS con capturas reales (+ fix Wear-as-AppleWatch)
Objective: Primera tanda de guías nuevas sobre la plantilla de #927: manual de iPhone (10 secciones) y de Apple Watch (7 secciones) con capturas reales en español (seeder -seedDemoData -esDemo -proMode). Incluye la corrección de contenido del showcase/hero de la landing, que mostraba capturas de Wear OS etiquetadas como Apple Watch, y scrollbars temáticos heredados del fix de #931 (ya en main).
Branch: `feat/guides-iphone-watch-934` desde main `797a1a20` | Delivery: `complete` | Test runners: `pnpm check` + `pnpm build` (landing/); `xcodebuild test -scheme "Pepinillo UI Capture"` (iOS) y `-scheme "PepinilloWatch UI Capture"` (watchOS)

## Specs

- **S1** — `landing/static/guides/iphone.html` (10 secciones: instalación, flujo, modos, sesión, plan, panel, widgets/Live Activity, Siri, cuenta/ajustes, tips/FAQ) con plantilla compartida (manual.css/manual.js, chip, cross-nav, TOC drawer).
- **S2** — `landing/static/guides/watchos.html` (7 secciones: instalación, foco, tareas, complications/Smart Stack, sync iPhone, notificaciones, tips/FAQ).
- **S3** — Capturas reales ES en `landing/static/guides/img/`: iphone-01..07 (foco idle, modos, corriendo, plan, panel, estadísticas, ajustes) + watchos-01..03 (timer, tareas, tercera página), ≤300KB c/u.
- **S4** — Índice `/guides`: iPhone y watchOS ready:true con mini-captura y bodies específicos es/en/pt; sitemap con ambas URLs.
- **S5** — Showcase landing: iPhone y Apple Watch ahora con capturas reales de sus manuales y links a sus guías; hero: iPhone corriendo + watchOS timer reales (elimina el Wear-as-AppleWatch).
- **S6** — Cross-nav completa: macOS → iPhone → watchOS → Web; solo Android y Wear OS "próximamente".
- **S7** — Regresión cero: svelte-check 0/0, build verde, anclas/images de manuales existentes intactas.

## Allowed edit surfaces

- `landing/static/guides/iphone.html`, `watchos.html` (nuevos), `macos.html`/`web.html` (solo cross-nav)
- `landing/static/guides/img/iphone-*.jpg`, `img/watchos-*.jpg` (nuevos)
- `landing/src/routes/guides/+page.svelte`, `landing/src/lib/i18n/messages.ts` (bodies de índice)
- `landing/src/lib/components/landing/PlatformShowcase.svelte`, `Hero.svelte` (fuentes de capturas + guías)
- `landing/static/sitemap.xml`
- `ios/App/DemoDataSeeder.swift` (flag `-esDemo`, DEBUG-only)
- `ios/project.yml`, `ios/UITests/**`, `ios/WatchUITests/**` (targets de captura)
- `odd/tasks/934-guides-iphone-watch.md`

## Execution notes

- **Captura vía XCUITest tour** (sin idb): targets `PepinilloUITests` (iOS) y `PepinilloWatchUITests` (watchOS) + schemes `Pepinillo UI Capture` / `PepinilloWatch UI Capture`; cada paso adjunta XCTAttachment; export con `xcresulttool export attachments`. Descartado idb (plugin lo busca en PATH del cliente pip; companion solo no alcanza).
- **`-esDemo` en DemoDataSeeder** (decisión autónoma): el seeder tenia títulos/notes/subtareas EN hardcodeados — para manuales ES y futuras capturas de store ES, flag DEBUG que los traduce. Cero riesgo de producción (#if DEBUG).
- **iPhone↔Watch sync demostrada en vivo**: la sesión iniciada por el UI test del iPhone aparece en la watch (Enfoque 3/4, 20:55) al capturar.
- Watch pairing: usar el par QA existente (iPhone 80547AB1 + Watch 82CB1A15); `simctl pair` con otro watch da 403.
- xcodegen debe correr DESPUÉS de crear los archivos de test (target con sources vacíos genera bundle sin ejecutable).
- Scheme completo para destination watchOS no compila (mezcla plataformas iOS/watchOS); usar `PepinilloWatch Dev` standalone.
- Descanso/hold del iPhone sin captura (requiere esperar una fase completa de 25 min): sección de sesión redactada sin figures de descanso.
- Complication de esfera sin captura directa (configurar esfera requiere UI automation de watchOS): manual redactado con capturas de la app.

## Log

- **L1 (2026-11-19 noche)**: Issue #934 + worktree + build iOS OK (app instalada en 80547AB1). Manuales escritos con cross-nav completa. Seed verificado en vivo (app ES). idb descartado → XCUITest tour. Seeder -esDemo aplicado (16 wrappers). Primer run: bundle sin ejecutable (xcodegen con dir vacío) → regenerado; error Swift 6 (property default XCUIApplication) → @MainActor. Run OK (62s) + watch build OK (PepinilloWatch Dev). svelte-check 0/0 tras reparar inserción de bodies (anclas multi-línea).
