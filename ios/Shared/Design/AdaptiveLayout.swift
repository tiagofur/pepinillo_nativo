// AdaptiveLayout.swift
// Pepinillo — Deep Work Companion for Apple
//
// Shared layout helpers for iPad-class design (iPadOS 18+ patterns).
// These modifiers enforce readable widths and adaptive grids so content
// never stretches across a 13" display the way an iPhone layout would.
// iPhone behaviour is unaffected — constraints only kick in at wider sizes.

import SwiftUI

extension View {
    /// Readable max-width for prose-heavy content (Onboarding, Paywall copy, About, Help).
    /// 672pt is the readable width recommended by Apple HIG.
    func readableContent(maxWidth: CGFloat = 672) -> some View {
        self.frame(maxWidth: maxWidth).frame(maxWidth: .infinity)
    }

    /// Cap for centered card/form content on iPad so it doesn't stretch on 13" displays.
    func contentMaxWidth(_ width: CGFloat = 1_200) -> some View {
        self.frame(maxWidth: width).frame(maxWidth: .infinity)
    }
}

/// Adaptive grid columns: 1 col iPhone, 2 cols iPad portrait, 3 cols iPad landscape / 13".
let adaptiveCardColumns: [GridItem] = [
    GridItem(.adaptive(minimum: 320, maximum: 480), spacing: 16)
]
