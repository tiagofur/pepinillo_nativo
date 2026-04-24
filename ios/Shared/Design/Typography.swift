// Typography.swift
// Pepinillo — Deep Work Companion for Apple
//
// Typography tokens for numeric HUD displays.
// SF Pro Rounded + monospacedDigit gives the Apple Clock / Fitness / Timer feel
// where digits don't jitter as they update.

import SwiftUI

enum NumericFont {
    /// Timer ring — large HUD like Apple Clock (64pt semibold rounded, monospaced).
    static func timer(size: CGFloat = 64) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
            .monospacedDigit()
    }

    /// Hero stat value (title2-level — e.g., streak count, session count).
    static func heroStat(size: CGFloat = 22) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
            .monospacedDigit()
    }

    /// KPI card value (title3-level — e.g., SummaryCard, PatternCard values).
    static func kpi(size: CGFloat = 20) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
            .monospacedDigit()
    }

    /// Inline numeric (small — e.g., "2/4 pomos", mode share percentages).
    static func inline(size: CGFloat = 15) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
            .monospacedDigit()
    }
}
