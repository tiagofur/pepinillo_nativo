# 924 — feat(landing): rediseño con producto real y secciones completas
Objective: La home de `pepinillo.app` hoy es texto + emojis sin una sola captura del producto, con links de tienda que apuntan a búsquedas, pricing teaser sin features, FAQ de 4 preguntas y sin selector de idioma. Rediseñarla con capturas reales en device frames (escena ecosistema), secciones completas (showcase multiplataforma, pricing con matriz, FAQ ampliada) y fixes de i18n/meta/links.
Branch: `feat/landing-redesign-924` | Delivery: `complete` | Test runners: `pnpm check` + `pnpm build` (landing/)

## Specs

- **S1**: Hero "escena ecosistema" con capturas reales en device frames CSS (Mac centro + iPhone + Watch + Android), estilo product page Apple (sin glassmorphism ni gradient text). CTAs web + stores.
- **S2**: Links directos a fichas reales: App Store `id6760687424`, Google Play `dev.creapolis.pepinillo` (publicada como "Pikle") con aclaración "(Pikle en Google Play)".
- **S3**: Sección showcase multiplataforma: Mac, iPhone, Watch, Android, Wear, Web con captura real + link a su guía.
- **S4**: Pricing completo: matriz Free / Pepinillo+ (compra única) / Everywhere/AI+ reutilizando las claves `upgrade.*` ya existentes (verificadas contra la pantalla upgrade viva).
- **S5**: FAQ expandida (~8) y sección de cierre CTA.
- **S6**: Header sticky + selector de idioma ES/EN/PT (persiste `localStorage`).
- **S7**: `svelte:head` reactivo (title + og por locale); `sitemap.xml` con `/guides/web.html`.
- **S8**: Home partida en componentes bajo `landing/src/lib/components/landing/` (presupuesto ~500 líneas); i18n completo en/es/pt con `pnpm check` verde.
- **S9**: Critique antes/después documentado (baseline 17/40; objetivo ≥36).

## Allowed edit surfaces

- `landing/src/routes/+page.svelte`, `landing/src/routes/+layout.svelte`
- `landing/src/lib/components/landing/**` (nuevos)
- `landing/src/lib/i18n/messages.ts`, `landing/src/lib/i18n/i18n.svelte.ts`
- `landing/src/lib/design/components.css` (primitivos nuevos si hace falta)
- `landing/static/img/hero/**`, `landing/static/img/showcase/**`, `landing/static/sitemap.xml`
- `odd/tasks/924-landing-redesign.md`

## Execution notes

- Capturas reales ya generadas y commiteadas (13734316): iPhone dark focus-running + plan (es, set crudo apple_store), Android light focus-running con tarea "Comprar café de avena" + dashboard (captura fresca en emulador Pixel 10 Pro, locale del sistema cambiado a es vía Settings UI automation), Wear timer/tasks/stats (es, crudas). Mac y Web se referencian desde `/guides/img/` existentes (mismo dominio, sin duplicar ~500KB).
- Decisiones de Tiago (2026-11-19): hero escena ecosistema; aclarar "(Pikle en Google Play)"; esta sesión SOLO landing (guías macOS/Web review + guías nuevas → sesiones siguientes).
- Pricing: reutilizar bullets `upgrade.free.*` / `upgrade.plus.*` / `upgrade.everywhere.*` (coherencia con app.pepinillo.app/upgrade vivo). No listar IA on-device en Plus para no divergir de la pantalla upgrade.
- Sin prueba social: ambas stores sin ratings aún (verificado 2026-11-19); no se inventan testimonios.
- Gotchas Android: gestos lentos no abren shade/drawer (usar flicks <100ms); los árboles UI de Settings se resuelven mejor con ui_describe que con resolve por texto; el botón "Iniciar Enfoque" dispara diálogo de optimización de batería (confirmar con el botón del diálogo, no tocar "Desactivar restricción").

## Critique baseline (2026-11-19, home en producción)

| # | Heurística | Score | Key issue |
|---|---|---|---|
| 1 | Visibility of status | 1 | Sin selector de idioma; locale invisible e inmutable |
| 2 | Match system/world | 2 | "Everywhere/AI+" filtra inglés en ES/PT |
| 3 | User control | 2 | Sin volver-arriba / navegación por secciones |
| 4 | Consistency | 2 | Botones store inconsistentes; emojis vs nada |
| 5 | Error prevention | 1 | Links de store → búsqueda genérica (riesgo de aterrizar en apps competidoras) |
| 6 | Recognition | 1 | Cero capturas: el producto no se reconoce |
| 7 | Flexibility | 1 | Sin selector idioma, sin anchors, sin deep links |
| 8 | Aesthetic/minimalist | 2 | Tipografía limpia pero emojis como anclas + glow decorativo; hero desbalanceado (texto izq, vacío der) |
| 9 | Error recovery | 3 | N/A (estático) |
| 10 | Help/docs | 2 | FAQ de 4; guías solo macOS en home |
| **Total** | | **17/40** | Needs work |

P0: sin producto visible; links store de búsqueda. P1: pricing sin features; i18n inaccesible. P2: FAQ corta; og/title hardcodeados.

## Log

- **L1 (2026-11-19)**: Issue #924 creado (status:ready, type:feat, ux, priority:high). Worktree `/private/tmp/wt-924`, rama `feat/landing-redesign-924` desde main `53fbcb8b`. Assets reales commiteados.
- **L2 (2026-11-19)**: Batches 1-2 commiteados (7253bffd, a3939ca5). QA visual en vite preview con 2 rounds de fixes: bisel del watch (plata #9a9aa2 + corona digital CSS), sombra de asentamiento bajo la escena, showcase con zona de frame fija (500px) y anclaje inferior → captions/links alineados por fila (verificado por medición DOM: frameBottom idénticos por fila), scroll-margin 84px en anclas, padding inferior del footer, CTA del header oculto ≤559px, h1 del hero reducido en móvil. Gotcha: `vite preview` sirvió un build viejo porque un proceso previo retenía el puerto (`pkill -f "vite.js preview"` requerido — "vite preview" no matchea).
- **L3 (2026-11-19)**: Re-critique post-fix: **36/40** (vs baseline 17/40): status 4 (selector idioma persistido + header sticky), match 3, control 3 (anclas + FAQ colapsable), consistencia 4, prevención 4 (links directos), reconocimiento 4 (10+ capturas reales), flexibilidad 3, estética 3, recovery 4, ayuda 4 (FAQ 8 + guías por plataforma). QA: desktop 1440 dark/light ES/EN, móvil 390 ES, 0 imágenes rotas, svelte-check 0 errores/0 warnings, build verde.
