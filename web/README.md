<<<<<<< HEAD
# Pepinillo Web — `pepinillo.app`

App web completa (PWA) + landing + guías para el dominio **pepinillo.app**.
Epic #809 · Reconstrucción total a partir de W1.
=======
# React + TypeScript + Vite

This template provides a minimal setup to get React working in Vite with HMR and some Oxlint rules.
>>>>>>> feat/web-ipad-parity

Currently, two official plugins are available:

<<<<<<< HEAD
- SvelteKit 2 + Svelte 5 (runes) + TypeScript strict
- `adapter-static` (landing/guías prerender + SPA fallback para la app)
- IndexedDB (`idb`) offline-first; sync LWW rescatada del núcleo probado
- Vitest (unit) + Playwright (e2e) + pnpm

## Desarrollo

```bash
pnpm install
pnpm dev        # http://localhost:5173
pnpm test       # suite unit (núcleo domain + gates + sync)
pnpm build      # build estático en build/
pnpm check      # svelte-check
```

Env (opcional, para W5 auth/sync): copiar `env.example` → `.env` y apuntar
`PUBLIC_API_BASE_URL` al API Go (prod: `https://api.ppn.creapolis.dev`).

## Estructura

```
src/lib/design/     → tokens de diseño (color/tipo/espacio/motion) + primitivos + Icon
src/lib/domain/     → lógica pura (motor de foco, gates, inteligencia) — testeable, sin UI
src/lib/data/       → IndexedDB (idb.ts), apiClient, sync LWW
src/lib/i18n/       → catálogos es/en/pt + wrapper reactivo
src/lib/stores/     → AppStore (runes): prefs, sesión, ticker, título
src/routes/         → / landing · (app)/focus|plan|dashboard|account
static/             → manifest, sw.js (offline shell), iconos, robots
```

## Decisiones de diseño

- **Híbrido familiar**: system-ui (SF en Apple, Roboto en Android); sidebar estilo
  macOS ≥1024px, nav rail tablet, bottom tab bar móvil.
- **Touch-first**: targets ≥44px, sin hover-only, `safe-area`, `viewport-fit=cover`.
- **Glass solo en la escena Focus** (invariante de marca); motion calm + UN spring
  reservado para celebraciones; `prefers-reduced-motion` respetado.
- Honestidad del timer: wall-clock + recompute al volver a la pestaña; nunca
  prometemos foreground con pestaña cerrada.

## Batches (epic #809)

W1 scaffold → W2 Focus completo → W3 Plan → W4 Dashboard → W5 Auth+Sync →
W6 Stripe → W7 IA → W8 Landing+Guías → W9 Deploy.
=======
- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react) uses [Oxc](https://oxc.rs)
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react-swc) uses [SWC](https://swc.rs/)

## React Compiler

The React Compiler is not enabled on this template because of its impact on dev & build performances. To add it, see [this documentation](https://react.dev/learn/react-compiler/installation).

## Expanding the Oxlint configuration

If you are developing a production application, we recommend enabling type-aware lint rules by installing `oxlint-tsgolint` and editing `.oxlintrc.json`:

```json
{
  "$schema": "./node_modules/oxlint/configuration_schema.json",
  "plugins": ["react", "typescript", "oxc"],
  "options": {
    "typeAware": true
  },
  "rules": {
    "react/rules-of-hooks": "error",
    "react/only-export-components": ["warn", { "allowConstantExport": true }]
  }
}
```

See the [Oxlint rules documentation](https://oxc.rs/docs/guide/usage/linter/rules) for the full list of rules and categories.
>>>>>>> feat/web-ipad-parity
