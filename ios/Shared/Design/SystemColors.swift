// SystemColors.swift
// Pepinillo — Deep Work Companion for Apple
//
// Cross-platform system color extensions for iOS and macOS.

import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

#if !os(watchOS)
extension Color {
    static var pepinilloSystemBackground: Color {
        #if os(iOS)
        Color(uiColor: .systemBackground)
        #elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(.systemBackground)
        #endif
    }

    static var pepinilloSecondarySystemBackground: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemBackground)
        #elseif os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(.secondarySystemBackground)
        #endif
    }

    static var pepinilloSystemGroupedBackground: Color {
        #if os(iOS)
        Color(uiColor: .systemGroupedBackground)
        #elseif os(macOS)
        Color(nsColor: .underPageBackgroundColor)
        #else
        Color(.systemGroupedBackground)
        #endif
    }

    static var pepinilloTertiarySystemBackground: Color {
        #if os(iOS)
        Color(uiColor: .tertiarySystemBackground)
        #elseif os(macOS)
        Color(nsColor: .textBackgroundColor)
        #else
        Color(.tertiarySystemBackground)
        #endif
    }

    static var pepinilloSystemFill: Color {
        #if os(iOS)
        Color(uiColor: .systemFill)
        #elseif os(macOS)
        Color(nsColor: .separatorColor).opacity(0.22)
        #else
        Color(.systemFill)
        #endif
    }

    static var pepinilloTertiaryLabel: Color {
        #if os(iOS)
        Color(uiColor: .tertiaryLabel)
        #elseif os(macOS)
        Color(nsColor: .tertiaryLabelColor)
        #else
        Color(.tertiaryLabel)
        #endif
    }
}
#endif
