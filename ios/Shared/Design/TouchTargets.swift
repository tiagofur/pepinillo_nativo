// TouchTargets.swift
// Pepinillo — minimum interactive hit areas for touch on Mac
//
// Touch on Mac expands hit rects to at least 36 pt per axis (tech talk
// "Bring Touch to your Mac app", 111468) while keeping the visual glyph
// unchanged: the growth is invisible tappable area, not bigger chrome.
// iOS keeps its own 44 pt HIG minimum, which the shared task rows already
// enforce. Canonical rules: ios/docs/touch-on-mac.md (R2).

import SwiftUI

enum TouchTargets {
    /// Minimum hit area per axis for touch on Mac.
    static let macMinimum: CGFloat = 36
}

extension View {
    /// Grows the tappable area to the Mac touch minimum (36×36) without
    /// changing the visual: the frame expands, any background already applied
    /// inside keeps its own bounds, and the whole expanded rect becomes
    /// tappable. Use for backgroundless icon buttons.
    func macTouchTarget() -> some View {
        frame(
            minWidth: TouchTargets.macMinimum,
            minHeight: TouchTargets.macMinimum
        )
        .contentShape(Rectangle())
    }
}
