# Microsoft Store certification checklist — Pepinillo

Use before submitting a package flight or public release. Mark items only after verification on a clean Windows 10 19041+ or Windows 11 machine (x64 and ideally ARM64).

## 1. Launch & stability

- [ ] Cold start completes without crash (first run + subsequent runs)
- [ ] No unhandled exceptions on main navigation (Focus, Tasks, Analytics, Soundscapes, Settings, Account, Paywall)
- [ ] App survives minimize / restore / close-to-tray (if tray enabled)
- [ ] Uninstall via Settings → Apps leaves no blocking error

## 2. Offline free tier

- [ ] Airplane mode / no network: Focus sessions start, pause, complete
- [ ] Tasks CRUD works offline
- [ ] Settings persist after restart offline
- [ ] Analytics shows local data without backend
- [ ] No forced login wall for free features

## 3. Privacy & legal

- [ ] Privacy policy reachable: https://creapolis.dev/privacy-policy/ (in-app link + Store listing)
- [ ] Terms reachable: https://creapolis.dev/terms-of-use/
- [ ] App does not collect unexpected personal data beyond documented privacy policy
- [ ] Support contact present on Store listing

## 4. In-app purchases (honesty)

- [ ] Free vs paid features clearly distinguished
- [ ] Paywall prices match Store (or show honest placeholder disclaimer until D1 + live SKUs)
- [ ] No “dark patterns” (fake countdown, pre-checked purchases)
- [ ] Purchase cancel path returns to app without crash
- [ ] Product IDs match Partner Center (`PARTNER_CENTER_IAP.md`)

## 5. Capabilities & fullTrust

| Capability | Required? | Justification |
| ---------- | --------- | ------------- |
| `internetClient` | Yes | Auth, sync, optional Store catalog |
| `runFullTrust` | Yes | WinUI 3 desktop / Windows App SDK full-trust host; system tray (`H.NotifyIcon`); global hotkeys (`RegisterHotKey`); Compact Overlay mini-timer; desktop shell integration |

- [ ] No extra capabilities beyond the two above without a written reason
- [ ] Certification notes / submission notes document fullTrust justification (copy table above)

## 6. Tray, toasts, hotkeys

- [ ] Tray icon appears and remains usable after main window close (expected product behavior)
- [ ] Tray menu actions work (show window / focus controls as implemented)
- [ ] Toast notifications display for session phase changes (when enabled)
- [ ] Global hotkeys do not hard-crash if registration fails; conflicts documented or rebindable when settings exist
- [ ] Uninstall / exit removes tray icon

## 7. Accessibility basics

- [ ] Keyboard: Tab order reaches primary controls on Focus and Tasks
- [ ] High contrast / text scale 125%: UI remains usable (no critical clipped CTAs)
- [ ] Meaningful names on primary buttons (Start / Pause / Complete)
- [ ] Color is not the only indicator of session state (text/icons also)

## 8. Performance & battery

- [ ] Idle focus timer does not pin a full CPU core (timer tick reasonable)
- [ ] No continuous disk thrash when idle
- [ ] Soundscapes stop when session ends or user stops audio
- [ ] App size / startup acceptable for productivity category (self-contained WASDK noted)

## 9. Package identity

- [ ] Version four-part (`Major.Minor.Build.Revision`) incremented for this submission
- [ ] Publisher CN matches Partner Center certificate (**not** `CN=PepinilloDev` for Store)
- [ ] Display name and logos correct; splash/tiles load
- [ ] x64 package tested; ARM64 package tested if submitted

## 10. Localization & content

- [ ] Primary EN strings free of placeholder “TODO” / “lorem”
- [ ] ES/PT partial localization does not show broken keys (fallback to EN OK)
- [ ] Age-appropriate productivity content only

## 11. Known non-blockers (document in submission notes if needed)

- Real soundscape mp3 assets may still be incomplete — silent/no-op tracks must not crash
- WinUI manual smoke backlog from P0–P2 should be zero for submitted build
- D1 pricing still open → do not mislabel temporary display prices as final

## Sign-off

| Role | Name | Date | Build / version |
| ---- | ---- | ---- | --------------- |
| Eng | | | |
| Product | | | |
