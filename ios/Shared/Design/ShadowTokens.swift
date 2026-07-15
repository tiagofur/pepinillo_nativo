// ShadowTokens.swift
// Pepinillo — Deep Work Companion for Apple
//
// Canonical elevation shadows. Prefer `.pepinilloShadow(...)` over ad-hoc
// `.shadow(color:radius:y:)` so depth is consistent and Liquid Glass can win.
//
// Levels:
//   • resting — subtle lift for cards / list rows sitting on a flat surface
//   • raised  — banners, floating chrome, app icon tiles
//   • glow    — accent-tinted solid primary CTAs (pre-glass fills)
//   • hero    — strong emphasis (paywall / onboarding primary)
//   • ink     — tiny text/emoji legibility (always apply; not elevation)
//
// Liquid Glass (iOS/macOS/watchOS 26+):
// By default (`respectsLiquidGlass: true`) drop shadows are omitted — native
// glass provides depth. Pass `respectsLiquidGlass: false` for solid CTAs,
// widgets, text ink, or non-glass surfaces that still need elevation.

import SwiftUI

enum PepinilloShadow: Sendable {
    /// Subtle lift for resting cards and list rows.
    case resting
    /// Noticeable elevation for banners and floating chrome.
    case raised
    /// Accent glow for solid primary CTAs.
    case glow
    /// Stronger hero emphasis (paywall / onboarding).
    case hero
    /// Tiny ink shadow for text/emoji legibility (not surface elevation).
    case ink

    func color(tint: Color) -> Color {
        switch self {
        case .resting: return .black.opacity(0.08)
        case .raised:  return .black.opacity(0.10)
        case .glow:    return tint.opacity(0.30)
        case .hero:    return tint.opacity(0.22)
        case .ink:     return .black.opacity(0.28)
        }
    }

    var radius: CGFloat {
        switch self {
        case .resting: return 4
        case .raised:  return 8
        case .glow:    return 12
        case .hero:    return 16
        case .ink:     return 2
        }
    }

    var y: CGFloat {
        switch self {
        case .resting: return 2
        case .raised:  return 4
        case .glow:    return 6
        case .hero:    return 8
        case .ink:     return 1
        }
    }
}

extension View {
    /// Tokenized elevation shadow with optional Liquid Glass awareness.
    ///
    /// - Parameters:
    ///   - style: Shadow level from `PepinilloShadow`.
    ///   - tint: Accent used by `.glow` / `.hero` (ignored for neutral styles).
    ///   - enabled: When `false`, no shadow is applied.
    ///   - respectsLiquidGlass: When `true` (default), skips drop shadows on
    ///     iOS/macOS/watchOS 26+ so native glass provides depth.
    @ViewBuilder
    func pepinilloShadow(
        _ style: PepinilloShadow,
        tint: Color = .accentColor,
        enabled: Bool = true,
        respectsLiquidGlass: Bool = true
    ) -> some View {
        if !enabled {
            self
        } else if respectsLiquidGlass {
            if #available(iOS 26.0, macOS 26.0, watchOS 26.0, *) {
                self
            } else {
                shadow(color: style.color(tint: tint), radius: style.radius, x: 0, y: style.y)
            }
        } else {
            shadow(color: style.color(tint: tint), radius: style.radius, x: 0, y: style.y)
        }
    }
}
