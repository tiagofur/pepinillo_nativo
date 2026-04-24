// GlassTokens.swift
// Pepinillo — Deep Work Companion for Apple
//
// Single source of truth for glass card corner radii. Three levels:
//   • tile (12) — chips, pills, small badges, filter bars
//   • card (20) — standard cards (dashboard KPIs, task rows, settings sections)
//   • hero (28) — large hero cards (timer ring wrapper, paywall tier cards)
//
// Use these instead of ad-hoc numeric literals so the visual language is
// consistent across screens.

import CoreGraphics

enum GlassCornerRadius {
    static let tile: CGFloat = 12
    static let card: CGFloat = 20
    static let hero: CGFloat = 28
}
