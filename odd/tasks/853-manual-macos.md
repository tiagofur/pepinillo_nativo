# 853 — docs(web): manual de usuario macOS supercompleto con capturas reales
Objective: Rewrite `web/static/guides/macos.html` as the exhaustive macOS user manual with real screenshots of the app running on seeded demo data (`-seedDemoData -proMode` + Spanish tasks via Quick Capture), covering all 16 inventoried surfaces and the full shortcut table.
Branch: `docs/manual-macos` | Delivery: `complete` | Test runners: `pnpm check` + `pnpm test` in `web/`

## Specs

- **S1**: Manual covers all inventoried surfaces (main window Focus/Plan/Dashboard/Account, Statistics ⌘4, menu bar + 3 styles, notch panel, Dock, Quick Capture, Spotlight + deep links, Focus scene 4 modes/ring/journal/celebrations, Plan table + inspector + drags, Settings 4 tabs, Help, global hotkeys ⌃⌥*, Services, Siri/Shortcuts, widgets, notifications, Handoff) with a basic→advanced structure and the complete shortcut table (global + menus + touch gestures noted as hardware-gated).
- **S2**: ≥18 real screenshots in `web/static/guides/img/macos-*.png`, each ≤300KB, visibly rich demo data (charts, streak, sessions).
- **S3**: Spanish task titles visible in screenshots (added via Quick Capture UI automation; NO changes to `ios/`).
- **S4**: Mixed appearance — mostly light + 4-6 key dark shots; menu bar shots anonymized/tightly cropped (no personal status icons).
- **S5**: prd-v2 §claims forbidden words respected in tier/sync sections (scan).
- **S6**: `pnpm check` + `pnpm test` + build green; `check_secrets.py` clean; `sw.js` reviewed if it precaches statics.
- **S7**: "Cómo probar" recipe (serve manual locally, light/dark, 390px, anchors, /guides link).

## Allowed edit surfaces

- `web/static/guides/macos.html`
- `web/static/guides/img/**` (new)
- `web/static/sw.js` (only if precache list requires it)
- `web/src/routes/guides/+page.svelte` + `web/src/lib/i18n/**` (only if the index copy for macOS needs updating)
- `odd/tasks/853-manual-macos.md`

## Execution notes

- Signed Debug build required (unsigned builds can't persist SwiftData into the App Group): `xcodegen generate` → `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -scheme "PepinilloMac Dev" -configuration Debug -destination 'platform=macOS' CODE_SIGN_STYLE=Automatic DEVELOPER_TEAM=T5SKULSP2M build`.
- Launch: `open …/PepinilloMac.app --args -seedDemoData -proMode -AppleLanguages (es)`; `-proMode` is sticky.
- Onboarding caveat: seeder writes the flag to SwiftData but bootstrap reads UserDefaults — complete onboarding once manually if it appears.
- Captures: `screencapture -l<windowID>` / `-x` + `sips` crop (retina 2x → downscale ~1600px). Raw 2x captures stay out of the repo.
- Touch-only gestures (ring dial, pinch Zen, touch soundscapes) are documented text-only with a "requires touch MacBook Pro" note (hardware: notch, no touch).

## Log

- **L1 (2026-11-17)**: User request verbatim: `hagamos un manual de usuario super completo y increible con imagenes reales de la app`. Decisions via Q&A: Spanish demo tasks, mixed light/dark captures, hardware = notch only.

- **L2 (2026-11-17, ejecución completa)**: Build firmado Xcode-beta OK; app corrida con `-seedDemoData -proMode -AppleLanguages (es)`; 8 tareas ES añadidas vía Quick Capture con clipboard (keystroke pierde espacios/tilas — key code 49 tampoco); CachedUser de Tiago borrado en BD (app quit) para anonimizar sidebar; capturas por `screencapture -l<CGWindowID>` (SÓLO ventana — un full-screen pilló WhatsApp y se descartó de inmediato); System Events `click at` NO mueve selección SwiftUI → CGEvent real vía `mouse.swift` (click/rightclick/move); journal = ventana separada (no sheet) y solo tras finalización natural (sesión <60s se descarta; hotkey aborta; interrupciones pausan); pill del notch requiere auto-inicios OFF en Ajustes + fin natural de fase. 30 capturas finales (light mayormente + 4 dark) → JPEG ≤300KB en `web/static/guides/img/` (3.9MB total). Manual 1208 líneas/28 figuras; 121/121 tests, svelte-check 0/0, build OK; claims-scan limpio; secrets OK; QA navegador: 28/28 imgs cargan, sin overflow a 390px.

- **L3 (2026-11-17, post-push QA)**: judgment-day dual lanzado pero ambos jueces cayeron por cuota de uso (resetea 2026-11-18 05:31). El barrido parcial del juez B confirmó la píldora del notch EN BLANCO (crop de región transparente aplanada a blanco) y mi re-verificación visual completa de las 30 imágenes encontró además que macos-dock-menu.jpg era el menú de un STACK DE ARCHIVOS del Dock (no el menú de Pepinillo) con nombres de archivo personales visibles — fuga. Ambas retomadas: píldora recortada con precisión (420×72) y menú del Dock real (tile 23 corriendo debug, verificado con analyze). Caption del Dock ajustado al estado real. Todas las demás imágenes verificadas visualmente una a una (context menu, composer, search, stats 7D, dashboard claro, popover menú bar, quick capture).
