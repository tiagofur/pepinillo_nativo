# macOS Widget Reactivity — app ↔ widget bidirectional live bridge

Prompt (2026-10-23): "si inicio un timer desde la app no se refleja al widget, está siempre en los 25 minutos… hacer que el widget sea reactivo a la app y también la app al widget como está en iOS y en el watch… las tareas también tienen que cambiar en tiempo real en los dos sentidos".

- Branch: `feat/macos-widget-reactivity` (from `main` @ `d67e8667`)
- Surfaces: `ios/Shared/Persistence/AppGroupContainer.swift` (all targets), `ios/Mac/MacExternalCommandObserver.swift` (new, Mac only), `ios/Mac/PepinilloMacApp.swift` (install), `ios/Pepinillo.xcodeproj` (xcodegen).

## Diagnosis (evidence, 2026-10-23 morning)

Three stacked causes, all verified on this machine:

1. **The on-screen widget is not the Mac app's widget.** `pluginkit -mv -i com.pepinillo.app.widget` resolves to `/Applications/Pepinillo.app/Wrapper/Pepinillo.app/PlugIns/PepinilloWidgetExtension.appex` — the **App Store iPad app** ("Designed for iPad" on Apple Silicon, itemID 6760687424), registered 2026-10-23 07:34.
2. **That App Store widget crashes on every timeline render under macOS 27.0.1 (26A434).** Crash logs `PepinilloWidgetExtension-2026-10-23-07341{3,7}.ips` and `-080323.ips`: `EXC_BREAKPOINT (SIGTRAP)` → Swift `_assertionFailure` inside CoreData `NSManagedObjectContext` frames, faulting thread queue `NSManagedObjectContext …`, reached from the widget's async timeline build (`completeTaskWithClosure`). A fatal assertion cannot be caught by the provider's `catch`, so the extension dies and WidgetKit keeps the last snapshot — the frozen "25:00". Follow-up candidate for the shipped v1.0.0(5) build (affects App Store users running the iPad app on Mac), out of scope here.
3. **The daily unsigned CLI dev build writes the App Group suite to the wrong domain.** Adhoc-signed (entitlement-less) processes resolve `UserDefaults(suiteName: "group.com.pepinillo.app")` to `~/Library/Preferences/group.com.pepinillo.app.plist` (user domain), while entitled processes (any signed widget) read/write `~/Library/Group Containers/group.com.pepinillo.app/Library/Preferences/group.com.pepinillo.app.plist`. Verified live: Tiago's 07:33 unsigned-app session wrote `isSessionActive=true`, phase "Enfoque 1/4" to the **user-domain** plist; the group-container plist kept stale September values. Group-container plist writes from the shell are denied (`com.apple.macl`), so the two domains can't be bridged externally.

4. **Real code gap (even fully signed): widget → app commands were only consumed on window activation.** `AppFeature.consumeExternalCommands` runs on `appBecameActive`; on macOS the app regularly lives in the background (menu bar, closed window) for a whole session, so widget Start/Pause/Stop/Complete-Task sat unconsumed until someone focused the window. App → widget was already complete (FocusFeature writes anchors + `WidgetSurfaceReload`/`WidgetCenter` reloads on start/pause/resume/phase/waiting/stop; TaskListFeature reloads `TasksHomeScreenWidget` on every task mutation).

## Fix

- `AppGroupDefaults` now posts the Darwin notification **`com.pepinillo.app.externalCommand`** whenever an external surface raises a command: the setters for `externalStartRequested`, `externalStopRequested`, `externalPauseRequested`, `externalResumeRequested`, `externalCompleteTaskRequested` (on `true`) and `widgetSelectedMode` (on change). Every writer — widget intents, Siri intents, Control Center — notifies automatically; no per-intent edits. Also adds `refreshFromOtherProcesses()` (suite `synchronize()` re-read) for the receiving side.
- New `MacExternalCommandObserver` (Mac shell, installed in `MacAppBootstrap` beside the other surfaces): observes the Darwin name with `CFNotificationCenterAddObserver(.deliverImmediately)`, hops to the main actor, refreshes the suite cache, and sends `AppFeature.consumeExternalCommands`. One signal path covers focus commands, widget mode mirroring, and task completion (`takeExternalCompleteTask`), because they all drain through that action.

## Dev-workflow fix (environment, no code)

Signed CLI builds work with automatic signing (verified `BUILD SUCCEEDED`, Team `T5SKULSP2M`, app-group entitlements embedded in app + `PepinilloWidgetMacExtension.appex`):

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -scheme "PepinilloMac Dev" -configuration Debug -derivedDataPath ios/build/macos-dev \
  CODE_SIGN_STYLE=Automatic DEVELOPER_TEAM=T5SKULSP2M build
```

Unsigned builds remain fine for everything except widget/App-Group work (their suite writes land in the user domain). Widget testing also requires the widget on screen to come from the **Mac** app: remove the iPad-app widget from the desktop first (both bundle the same extension id `com.pepinillo.app.widget`; `pluginkit` currently resolves it to `/Applications/Pepinillo.app`).

## Log

- L1 (2026-10-23): Implemented and verified, committed as `a001c589`. Diagnosis per section above (plutil dumps of both suite plists, `pluginkit -mv`, three crash logs, entitlement dumps of signed/unsigned bundles). Code: Darwin-signal setters + `MacExternalCommandObserver` + install in `PepinilloMacApp`. Builds: Mac signed `PepinilloMac Dev` BUILD SUCCEEDED; iOS `Pepinillo Dev` (iPhone 17 Pro sim) BUILD SUCCEEDED; `PepinilloControlCenter` and `PepinilloWatchWidgetExtension` targets BUILD SUCCEEDED (`PepinilloWatch` app target fails from CLI on a pre-existing swift-syntax `-I` plugin quirk, unrelated — it does not compile the changed file); `AppGroupContainerTests` suite green (28 cases, includes the intent/setter paths that now post the signal). Runtime verification (signed build launched hidden, `notifyutil -p com.pepinillo.app.externalCommand`): unified log shows `PepinilloMac[…] mac-external-commands External command signal received` for each post (2/2 delivered, sub-second), proving signal → main-actor hop → consume dispatch with the app in the background. Real-world corroboration the same morning: Tiago's 08:05:47 tap on the (old, App Store) widget Start wrote a full optimistic snapshot into the group container — the write side works; only the signal and the consuming app build were missing. Not verifiable headless: the widget's visual re-render (needs the new widget binary pinned on the desktop; GUI) and the App Store iPad-widget crash fix (separate task candidate). Known residual: Darwin delivery latency observed < 1 s; consumption is idempotent so repeat signals are safe.
