# Widget free-tier basics — small timer + daily task count

Prompt (2026-10-23, after the widget-reactivity session): the desktop Tasks widget showed "All done!" instead of the Pepinillo+ gate or the task list. Request: "podemos dejar algún widget básico para free? como cantidad de tareas para el día … y el más chiquito de temporizados? uno para cada uno de los dos".

- Branch: `feat/widget-free-tier` (stacked on `feat/macos-widget-reactivity` / PR #672 — Tiago's Xcode builds from that branch)
- Product truth: `PRD/04_MONETIZATION.md` free row updated.

## Diagnosis of the screenshot (why "All done!" and not the gate)

1. `pluginkit` resolves `com.pepinillo.app.widget` to the **App Store iPad app's** extension (`/Applications/Pepinillo.app/Wrapper/…`) — re-registered 11:49, matching the screenshot. The Mac widget extension had the **same bundle id** and loses registration to the store-signed one.
2. The iPad-app widget's focus path reads AppGroupDefaults (schema-independent) → renders the live timer fine. Its tasks path reads SwiftData with the shipped (older) model against the store the new app writes → fetch yields nothing → catch/empty → "All done!" ghost snapshot. Same incompatibility behind its `EXC_BREAKPOINT` crashes (issue #674).
3. The Mac extension not registering at all was compounded by a project.yml quirk: `settings.base.PRODUCT_BUNDLE_IDENTIFIER` (line ~356) overrides the target's `bundleId:` key — xcodegen silently ignored the `bundleId:` change until the explicit setting was edited too.

## Changes

- `ios/project.yml`: `PepinilloWidgetMacExtension` → bundle id **`com.pepinillo.app.widget.mac`** (both `bundleId:` and `settings.base`). With distinct ids both extensions register; the Mac picker can finally offer the Mac app's widgets.
- **Tasks widget tier split**: free → `TasksWidgetFreeCountView` (header "Tasks (N)", big count or "All done!", Pepinillo+ hint, no interactive controls); Pro → the existing interactive list (all families). `TasksWidgetEntry` gains `isProUser` + `todayTaskCount`; `isLocked`/`TasksWidgetLockedView`/`.locked` removed (dead concept). Provider does one authorized SwiftData pass and branches.
- **Focus widget tier split**: free → `systemSmall` renders; `systemMedium`/`systemLarge` render `WidgetProRequiredView` ("Medium and large focus widgets"). Pro unchanged. (FocusWidgetEntry already carried `isProUser`.)
- Localization: `widget.tasks.free.hint`, `widget.focus.pro.title`, `task for today`, `tasks for today` in en/es/pt; dead `widget.tasks.locked.message` removed from the catalog.
- `PRD/04_MONETIZATION.md`: free "Widgets" row → "Small timer widget + daily task-count widget".
- Deliberately unchanged: Lock-screen accessory widgets (iOS-only, out of the named scope), Dashboard widget (already proRequired per WidgetProGatingTests), widget completion/focus-start intents (already entitlement-gated).

Consequence to flag: free users currently using a **medium/large** timer widget (including Tiago's desktop) will see the Pro gate there after this lands — the small widget is the free surface.

## Log

- L1 (2026-10-23): Implemented. Builds: signed `PepinilloMac Dev` BUILD SUCCEEDED (after clearing a stale Sentry explicit-module pcm in the scratch DerivedData — `-rm Intermediates.noindex`); iOS `Pepinillo Dev` + `AppGroupContainerTests` + `WidgetProGatingTests` TEST SUCCEEDED. Verified built appex carries `com.pepinillo.app.widget.mac`. Not done here: XcodeGen `bundleId:` vs `settings.base` precedence documented above (the silent override cost a debugging cycle — the grep-able marker trick found it). Manual widget verification pending on Tiago's desktop: remove the iPad-app widgets, re-add from the Mac app (picker entry with bundle `widget.mac`), free tier should show small timer + task count.
