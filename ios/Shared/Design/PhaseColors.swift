// PhaseColors.swift
// Pepinillo — Deep Work Companion for Apple
//
// Derives calmer break-phase colors from the base mode color.
// Works on iOS, watchOS, and widget extensions.

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

extension Color {
    /// Derives a calmer break color by shifting hue toward teal, reducing saturation, and increasing lightness.
    func breakVariant(for phase: FocusPhase) -> Color {
        guard phase.isBreak else { return self }

        #if canImport(UIKit) && !os(watchOS)
        let uiColor = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        #else
        // Fallback: extract components via resolved color in a standard color space
        let components = extractHSB()
        let h = components.hue
        let s = components.saturation
        let b = components.brightness
        let a = components.alpha
        #endif

        // Convert HSB to HSL
        let l = b * (1 - s / 2)
        let sl: CGFloat
        if l == 0 || l == 1 {
            sl = 0
        } else {
            sl = (b - l) / min(l, 1 - l)
        }

        let hDegrees = h * 360

        let newH: CGFloat
        let newS: CGFloat
        let newL: CGFloat

        switch phase {
        case .shortBreak, .flowBreak:
            newH = (hDegrees + 30).truncatingRemainder(dividingBy: 360) / 360
            newS = sl * 0.75
            newL = min(l + 0.15, 0.85)
        case .longBreak:
            newH = (hDegrees + 50).truncatingRemainder(dividingBy: 360) / 360
            newS = sl * 0.60
            newL = min(l + 0.20, 0.85)
        default:
            return self
        }

        // Convert HSL back to HSB
        let newB = newL + newS * min(newL, 1 - newL)
        let newSB: CGFloat
        if newB == 0 {
            newSB = 0
        } else {
            newSB = 2 * (1 - newL / newB)
        }

        return Color(hue: Double(newH), saturation: Double(newSB), brightness: Double(newB), opacity: Double(a))
    }

    func shortBreakVariant() -> Color {
        breakVariant(for: .shortBreak)
    }

    func longBreakVariant() -> Color {
        breakVariant(for: .longBreak)
    }

    #if !canImport(UIKit) || os(watchOS)
    /// Extract HSB components where UIColor is unavailable.
    private func extractHSB() -> (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        // Resolve the color in the sRGB color space
        let resolved = self.resolve(in: EnvironmentValues())
        let r = CGFloat(resolved.red)
        let g = CGFloat(resolved.green)
        let b = CGFloat(resolved.blue)
        let a = CGFloat(resolved.opacity)

        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC

        // Hue
        var hue: CGFloat = 0
        if delta > 0 {
            if maxC == r {
                hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
                if hue < 0 { hue += 6 }
            } else if maxC == g {
                hue = (b - r) / delta + 2
            } else {
                hue = (r - g) / delta + 4
            }
            hue /= 6
        }

        // Saturation (HSB)
        let saturation: CGFloat = maxC == 0 ? 0 : delta / maxC

        return (hue, saturation, maxC, a)
    }
    #endif
}
