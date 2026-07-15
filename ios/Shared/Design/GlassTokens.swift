// GlassTokens.swift
// Pepinillo — Deep Work Companion for Apple
//
// Single source of truth for corner radii. Use these instead of ad-hoc
// numeric literals so the visual language is consistent across screens.
//
// Scale (Apple-like continuous rounding):
//   • micro (8)  — chart ticks, tiny badges, dense chrome
//   • tile  (12) — chips, pills, small badges, filter bars, list rows
//   • control (16) — text fields, medium CTAs, segmented surfaces
//   • card  (20) — standard cards (KPIs, settings sections, task groups)
//   • hero  (28) — large hero cards, paywall tiers, sheet corners

import CoreGraphics

enum GlassCornerRadius {
    /// Chart ticks, compact badges, dense UI chrome.
    static let micro: CGFloat = 8
    /// Chips, filter bars, compact rows, small cards.
    static let tile: CGFloat = 12
    /// Text fields, medium buttons, control surfaces.
    static let control: CGFloat = 16
    /// Standard content cards and glass panels.
    static let card: CGFloat = 20
    /// Hero surfaces, large tier cards, sheet presentation.
    static let hero: CGFloat = 28
}
