# Widget registration + live ring — sandbox entitlements and staggered timeline

Prompts (2026-10-23 afternoon): after uninstalling the iPad App Store app, no
Pepinillo widgets appeared anywhere; once the Mac widget appeared, its progress
ring stayed frozen while the digits ticked (a pause forced a one-frame update).

- Branch: `fix/widget-registration-ring` (stacked on `feat/pause-keeps-break-color` / PR #680)

## Root cause 1 — pkd rejected the Mac appex: "plug-ins must be sandboxed"

`pluginkit` never listed `com.pepinillo.app.widget.mac` despite valid signatures,
correct `NSExtensionPointIdentifier`, and a live LaunchServices record. The pkd log
gave it verbatim:

```
rejecting; Ignoring mis-configured plugin at
[…/PepinilloWidgetMacExtension.appex]: plug-ins must be sandboxed
```

The effective appex entitlements had app-groups but **no `app-sandbox`**. Chain:

- Both widget targets (iOS + Mac) shared one generated file,
  `PepinilloWidget/PepinilloWidget.entitlements`, with different `properties` —
  last writer wins, silently.
- The per-config `CODE_SIGN_ENTITLEMENTS` overrides
  (`PepinilloWidgetMacDebug.entitlements`, which DOES declare sandbox) never
  applied: xcodegen's generated file takes precedence and the pbxproj pointed
  all three configs at the shared file.
- The shared file only declared app-groups (iOS sandbox is implicit; macOS pkd
  requires the key explicitly).

Fix: the Mac target now generates its own `PepinilloWidgetMac.entitlements` with
`app-sandbox: true` + app-groups; the iOS file keeps app-groups only. Verified:
built appex carries `app-sandbox`, `pluginkit -mv -i com.pepinillo.app.widget.mac`
lists it from /Applications, sandbox container created.

Environment fallout cleaned on the dev Mac (not code): LaunchServices held ~30
stale records for the same bundle id (deleted worktrees, /tmp builds, the removed
unsigned `ios/build/macos-dev` tree) — all unregistered, leaving only
/Applications; duplicate standalone `.appex` copies deleted. pkd's `-10814`
"could not resolve URL" noise came from those dead records.

## Root cause 2 — frozen ring: TimelineView(.periodic) never re-renders in widgets

The provider emitted ONE entry per phase and the ring relied on
`TimelineView(.periodic(from:by: 1))` to animate between reloads. That view does
not re-render inside WidgetKit views on macOS, so digits (system-driven
`Text(timerInterval:)`) ticked while the ring sat frozen until the next reload
(exactly Tiago's symptom, including the pause-forced update).

Fix: the provider emits staggered snapshots every 30 s across the live phase
(capped at 50 entries, one SwiftData pass + pure math per entry), each carrying
the progress computed for its own date; `WidgetProgressRing` now prefers the
entry snapshot over the dead TimelineView (kept as fallback where no snapshot
exists). New `FocusWidgetEntry.with(date:progress:)` copy helper. Paused/waiting/
idle timelines keep the single-entry policy (nothing moves there).

## Log

- L1 (2026-10-23): Implemented both fixes. Signed `PepinilloMac Dev` BUILD
  SUCCEEDED; appex verified carrying `app-sandbox`; pluginkit registration
  confirmed from /Applications. Reinstall + live ring check on the desktop next.
