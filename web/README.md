# Pepinillo Web (Companion)

Browser companion for large-screen Focus / Plan / Dashboard. **W1 Free shell** is offline-first (IndexedDB). It is **not** a fourth native OS client and does **not** claim widgets, tray, watch, or Live Activity parity.

## Stack

- SvelteKit 2 + TypeScript (strict) + Svelte 5 runes
- `@sveltejs/adapter-static` (SPA fallback)
- IndexedDB via `idb`
- Vitest for unit tests
- Playwright for e2e smoke
- Package manager: **pnpm**

## Free limits (PRD/04 §3.1)

| Feature | Free |
|---------|------|
| Modes | Pomodoro + Stopwatch |
| Active tasks | ≤ 3 |
| Analytics | Today + last 7 days |
| Themes | System / light / dark only |
| Sync | Off (browser-local only) |

## Timer honesty

Best experience: **keep this tab open** during a session. Browsers may throttle background timers. The engine uses wall-clock recompute on `visibilitychange`, but closing the tab is not guaranteed to continue timing. We do **not** claim OS-level foreground-service reliability.

## Scripts

```bash
cd web
pnpm install
pnpm dev          # http://localhost:5173
pnpm test         # Vitest unit suite
pnpm test:e2e     # Playwright smoke (builds + preview)
pnpm check        # svelte-check
pnpm build        # static output in build/
pnpm preview
```

npm works too (`npm i && npm run dev`) if you prefer; lockfile is pnpm.

## Layout

```
src/lib/domain/     pure TS (gates, focus engine, dashboard summary)
src/lib/data/local/ IndexedDB repositories
src/lib/i18n/       EN / ES / PT strings
src/routes/         Focus | Plan | Dashboard | Account
tests/unit/         Vitest
tests/e2e/          Playwright smoke
```

## Env

See `env.example`. W1 leaves `PUBLIC_API_BASE_URL` empty. Everywhere auth/sync is **W2+**.

## Performance notes

- No heavy UI kits or chart libraries on Free path
- Critical shell budget target: ≤ 120 KB gzip (measure with rollup visualizer if regressing)
- `robots.txt` + meta robots `noindex` until marketing NG6 lift

## Out of scope (W1)

Auth, sync, WebSocket, Flowtime/Time Block unlock, PWA, soundscapes, export, AI, Electron/Tauri.
