// Typography.swift
// Pepinillo — Deep Work Companion for Apple
//
// Typography tokens for numeric HUD displays.
// SF Pro Rounded + monospacedDigit gives the Apple Clock / Fitness / Timer feel
// where digits don't jitter as they update.
//
// All tokens scale with Dynamic Type by default (issue #82). Callers may pass
// an explicit `size` to opt out of scaling for layouts that require a fixed
// size (e.g. a number that must fit inside a fixed circle). Most callers should
// omit `size` so the text respects the user's accessibility text size.

import SwiftUI

enum NumericFont {
    /// Timer ring — large HUD like Apple Clock.
    /// Defaults to `.largeTitle` (scales with Dynamic Type). Pass `size` only
    /// when the text must fit a fixed container; pair with `.minimumScaleFactor`
    /// at the call site so it still shrinks if needed.
    static func timer(size: CGFloat? = nil) -> Font {
        if let size {
            return .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
        }
        return .system(.largeTitle, design: .rounded, weight: .semibold).monospacedDigit()
    }

    /// Hero stat value (e.g., streak count, session count).
    /// Defaults to `.title2`. Pass `size` to force a fixed size.
    static func heroStat(size: CGFloat? = nil) -> Font {
        if let size {
            return .system(size: size, weight: .bold, design: .rounded).monospacedDigit()
        }
        return .system(.title2, design: .rounded, weight: .bold).monospacedDigit()
    }

    /// KPI card value (e.g., SummaryCard, PatternCard values).
    /// Defaults to `.title3`. Pass `size` to force a fixed size.
    static func kpi(size: CGFloat? = nil) -> Font {
        if let size {
            return .system(size: size, weight: .bold, design: .rounded).monospacedDigit()
        }
        return .system(.title3, design: .rounded, weight: .bold).monospacedDigit()
    }

    /// Inline numeric (small — e.g., "2/4 pomos", mode share percentages).
    /// Defaults to `.subheadline`. Pass `size` to force a fixed size.
    static func inline(size: CGFloat? = nil) -> Font {
        if let size {
            return .system(size: size, weight: .medium, design: .rounded).monospacedDigit()
        }
        return .system(.subheadline, design: .rounded, weight: .medium).monospacedDigit()
    }
}
