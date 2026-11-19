# 927 — feat(guides): revivir manuales macOS y Web (CSS compartido, cross-nav, TOC móvil)
Objective: Los dos manuales publicados arrastraban CSS duplicado y divergente (macOS con tokens viejos), sin navegación cruzada, con TOC inaccesible bajo 759px y sin feedback de posición. Unificarlos sobre un stylesheet compartido con tokens canónicos y añadir progreso de lectura, scrollspy, drawer móvil y cross-nav; el índice /guides gana mini-capturas reales.
Branch: `feat/guides-revamp-927` (apilada sobre `feat/landing-redesign-924` / PR #928 — retarget a main al mergear) | Delivery: `complete` | Test runners: `pnpm check` + `pnpm build` (landing/)

## Specs

- **S1** — `landing/static/guides/manual.css` compartido (única fuente; base = stylesheet de web.html que ya usaba tokens canónicos + piezas exclusivas de macOS: touch-banner, badge-touch/cloud/new); ambos manuales lo referencian vía `<link>`; cero `<style>` embebido.
- **S2** — Cross-nav: `.guide-nav` al final (macOS → siguiente: Web; Web → anterior: macOS) + link central "Todas las guías".
- **S3** — TOC móvil: bajo 759px el sidebar se vuelve drawer (fixed, translateX) con botón flotante ☰, overlay con click-to-close y Escape; anclas del TOC cierran el drawer.
- **S4** — Scrollspy (sección activa en TOC, con fallback hacia atrás si la sección no está en el índice) + barra de progreso de lectura (3px, brand) — `manual.js` vanilla compartido, rAF-throttled, `prefers-reduced-motion` respetado.
- **S5** — Tokens alineados: macOS pasa de tokens viejos (#D9453A/#1E88A8/#7B52AB/#2E7D46/#D9822B) a los canónicos (#E84D3D/#3387EB/#8F45DE/#2EB870/#FF991A); light/dark intactos.
- **S6** — Índice `/guides`: tarjetas listas (macOS, Web) con mini-captura real (macos-dashboard.jpg, web-02-foco-corriendo.jpg); "próximamente" intactas; i18n intacto.
- **S7** — Regresión cero: 47 imágenes de guías cargan (lazy), 13+10 anclas de sección, svelte-check 0/0, build verde.

## Allowed edit surfaces

- `landing/static/guides/manual.css`, `landing/static/guides/manual.js` (nuevos)
- `landing/static/guides/macos.html`, `landing/static/guides/web.html`
- `landing/src/routes/guides/+page.svelte`
- `odd/tasks/927-guides-revamp.md`

## Execution notes

- La transformación de los HTML fue determinista por script python (replace de style block, inserciones tras `<body>`/`<nav>`/footer, script defer) — sin tocar contenido editorial.
- Drawer: `aside.open { transform: translateX(0) }` (no `none` — no interpola en transiciones).
- Gotcha QA: el webview del IAB pausa rAF y transiciones CSS en background → scrollspy/progreso/drawer parecen "congelados" en pestañas no activas; verificado funcionando en pestaña activa (scrollspy #modos a 2500px, progreso 16.8%, drawer rectLeft=0) y sin transición (transition:none → matrix exacta).
- El "Coming soon" visto en QA era el locale auto-detectado (en) del preview en otro puerto; con es dice "Próximamente".

## Log

- **L1 (2026-11-19)**: Issue #927 creada tras pedido de Tiago de mejorar las guías existentes. Worktree `/private/tmp/wt-927` apilado sobre 77b0293e. manual.css (457 líneas) + manual.js (88) + transformación de ambos manuales + índice con thumbs. QA: estructura verificada programáticamente (cssLink ✓, sin style inline ✓, chips ✓, crossNav ✓, progreso ✓, toggle ✓, drawer abierto rectLeft=0 ✓), visuales desktop 1280 revisados, svelte-check 0/0, build verde.
- **L2 (2026-11-19 noche, reporte de Tiago)**: **BUG GRAVE confirmado y REPARADO en web.html — PREEXISTENTE del manual original** (base 77b0293; el manual publicado en producción lo tiene): dos `<figure class="figure-row">` (secciones 4 y 5) cerraban con `</div>` — el parser HTML, al ver el cierre sin su apertura, cierra la pila hasta `.app-shell`: el contenido de las secciones 5-10 quedaba FUERA del grid, a ancho completo, debajo del sidebar (el Juez 1 midió main 4132px vs doc 10527px sin detectarlo — las capturas de scroll profundo de Tiago sí). Fix: `figure-row` → `<div class="figure-row">` ×2; verificado en navegador: 10/10 secciones dentro de main, docH=mainH=9891, aside sticky íntegro a y=4106 (donde antes se caía). macOS usa `<div>` ×5 y nunca lo sufrió.
- **L3 (2026-11-19 noche, pedido de Tiago)**: **Scrollbar temático**: `color-scheme: light/dark` en :root (scrollbar y controles nativos siguen el tema) + scrollbar fino con tokens (`scrollbar-width: thin; scrollbar-color: var(--border-strong) transparent` para Firefox; `::-webkit-scrollbar` con thumb `var(--border-strong)`, hover `--faint`). Pendiente follow-up: aplicar el mismo tratamiento de 2 líneas a la landing/PWA (fuera de superficies de este PR).
