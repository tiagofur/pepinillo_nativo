# Icon Composer layers for Pepinillo app icon

## Context

iOS 26 / Xcode 26 introduced **Icon Composer**, a new asset format (`.icon` bundle
inside the asset catalog) that lets you supply separated layers so the OS can apply
its own specular highlight, parallax depth, and per-layer glass treatment.

A flat 1024 × 1024 PNG still works — iOS applies a generic glass tint — but the
full specular/parallax depth requires explicit layers.

The `.icon` format is produced **only through Xcode's GUI** (no public CLI or
documented file schema). You cannot write a valid `.icon` bundle by hand and have
xcodebuild accept it. Therefore this folder contains the reference layer PNGs for a
designer or developer to drag into Xcode's Icon Composer.

## Current icon composition

The icon is a "cucumber clock" face:

| Element | Color | Notes |
|---------|-------|-------|
| Outer ring | Charcoal `#2b2b2b` | ~20 px stroke, clips corners |
| Body fill | Lime green `#8dc63f` | Radial gradient: lighter top-left |
| Seeds / spines | Dark `#2b2b2b` | 6 almond shapes at clock positions |
| Clock hands | Light blue `#29b5e8` | Two lines forming a `<` |

## Files in this folder

| File | Contents |
|------|----------|
| `background.png` | Green body + dark ring; blue hands replaced with matching green (reference only — contains color bleed artefacts) |
| `foreground_approx.png` | Dark seeds + blue clock hands on near-white background (green region punched transparent — some fringing expected) |

These were produced with ImageMagick fuzz-based color substitution. They are
**reference art**, not production-ready layers. A proper separation requires
re-drawing each layer in the original design tool (Figma/Illustrator) with full
transparency.

## Recommended layer stack for Icon Composer (3 layers)

```
Layer 3 — Specular (optional): subtle white radial gradient oval, top-left
Layer 2 — Foreground: seeds (dark almonds) + clock hands (blue) on transparent PNG
Layer 1 — Background: solid lime-green circle + dark outer ring on opaque PNG
```

## Steps to create the `.icon` asset in Xcode 26

1. Open `ios/Shared/Resources/Assets.xcassets` in Xcode 26.
2. Right-click the asset catalog → **New App Icon**.
3. Xcode creates an `AppIcon.icon` bundle. Select it.
4. In the Icon Composer editor, add **3 layers** (+ button at bottom-left).
5. Drag the production `background.png` onto **Layer 1** (Background).
6. Drag the production `foreground.png` (seeds + hands, transparent) onto **Layer 2**.
7. (Optional) drag a soft white radial gradient PNG onto **Layer 3** for specular pop.
8. Preview the parallax and glass effects in the canvas — adjust layer opacity as needed.
9. In `project.yml`, the `ASSETCATALOG_COMPILER_APPICON_NAME` already points to `AppIcon`.
   No change needed as long as the `.icon` asset is named `AppIcon` inside the catalog.
10. Run `xcodegen generate && xcodebuild` to confirm 0 errors.

## What to update after composing

- Delete or archive `AppIcon.png` (the flat fallback) once the `.icon` bundle is live.
- Test on a real iOS 26 device to confirm specular and parallax depth.
- The widget/watch icon can share the same background layer; add a separate `.icon`
  for `AppIcon-Watch` if watchOS parallax is also desired.

## Why the programmatic path was not taken

The `.icon` bundle is an opaque Xcode artifact. Its internal `icon.json` manifest
schema is not publicly documented; attempts to write one by hand result in
xcodebuild rejecting the asset catalog or silently falling back to the flat PNG.
Layer separation via ImageMagick produces fringing artefacts on the gradient-filled
body. A clean separation requires the original vector source (Figma/Illustrator).
