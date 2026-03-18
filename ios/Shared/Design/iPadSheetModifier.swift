// iPadSheetModifier.swift
// Pepinillo — Deep Work Companion for Apple
//
// Applies page-sized presentation on iPad (iOS 18+).
// Falls back to default form-sheet on older versions.

import SwiftUI

extension View {
    @ViewBuilder
    func iPadSheetSizing() -> some View {
        if #available(iOS 18.0, watchOS 11.0, macOS 15.0, *) {
            self.presentationSizing(.page)
        } else {
            self
        }
    }
}
