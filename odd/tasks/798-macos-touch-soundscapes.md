# 798 — macOS: multi-touch Soundscapes selector on the Focus stage
Objective: Bring the 8 existing soundscapes to `PepinilloMac` as a Liquid Glass pill beside `Link Task`, opening a popover where ambience and volume can be adjusted at the same time on touch Macs.
Branch: `feat/macos-touch-soundscapes` | Delivery: `complete` | Test runners: `xcodebuild test -scheme "Pepinillo Dev"`, `xcodebuild build -scheme "PepinilloMac Dev"`

## Specs

- **S1**: `MacFocusView` shows a Liquid Glass `Soundscapes` pill beside `linkedTaskChip` (min height ≥36 pt) that opens a popover with the 8 soundscapes (4 free + 4 Pepinillo+ behind the shared Pro gate).
- **S2**: Sliders in the popover are native SwiftUI `Slider`s, and the container turns off gesture exclusivity (`exclusiveGestureBehavior = .notExclusive` under `#available(macOS 27.0, *)`).
- **S3**: Full parity with `FocusFeature` (`soundscapeSelected`, `paywallTapped`); Soundscapes stay device-local (`docs/design.md` §4).

## UX Brief

- **Visitor mode / goal**: settling in before or during a session. "Put rain on, a bit quieter" without leaving the stage or opening Settings.
- **Composition thesis**: one more pill in the row that already holds `Link Task` — same glass capsule, same height, same type. It names the current ambience (icon + name; `Soundscape` when off), so the stage reads "task · ambience" under the ring. The popover hangs from the pill.
- **Popover**: volume first (it is the thing you touch repeatedly), then the list — None + 4 free, then the 4 Pepinillo+ under a `Pro` header with a lock. Rows show icon, name, a preview button and a checkmark on the current one. Choosing does **not** close the popover, so one hand can ride the volume while the other tries ambiences — the multi-touch moment the issue asks for. Outside click / Esc closes.
- **Locked rows**: tapping a Pro ambience without Pepinillo+ closes the popover and opens the shared paywall — same path as iOS.
- **States**: idle → choice is remembered and plays from Start; running → switches live. `None` silences. Volume slider is disabled while `None` is selected (nothing to adjust). Preview plays 3 s at the slider's volume.
- **Zen**: the pill hides with the link chip — Zen is "ring and controls only".
- **Accessibility**: pill label "Soundscape: Rain"; slider labelled "Volume"; rows keep the iOS labels (selected / requires Pro). Every target ≥36 pt (guide R2). Nothing depends on hover.
- **Memorable moment**: sliding the volume with one finger while tapping through ambiences with the other.

### Assumptions

- A1: Keeping the popover open on selection (unlike the iOS sheet) is the intended multi-touch behaviour.
- A2: One volume slider is enough; the engine has a single soundscape channel (`FocusFeature.soundscapeVolume`), so "sliders" in S2 reduces to one.
- A3: Hiding the pill in Zen is desirable.
- A4: `exclusiveGestureBehavior` on the popover window's content view is the right container; not verifiable without touch hardware.

## Allowed edit surfaces

- `ios/Mac/MacFocusView.swift`
- `ios/Features/Focus/SoundscapePickerView.swift`
- `ios/Shared/Resources/Localizable.xcstrings`
- `ios/Tests/FocusFeatureTests/FocusFeatureReducerTests.swift`
- `odd/tasks/798-macos-touch-soundscapes.md`

## Log

- **L1 (2026-11-16)**: User request verbatim: `Sí, sigue con #798`.
