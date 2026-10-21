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

    /// Cards and list rows sitting on top of a grouped page background.
    /// In dark mode: ~rgb(28,28,30) — visually separated from systemGroupedBackground (pure black).
    static var pepinilloSecondarySystemGroupedBackground: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemGroupedBackground)
        #elseif os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(.secondarySystemGroupedBackground)
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

    static var pepinilloSeparator: Color {
        #if os(iOS)
        Color(uiColor: .separator)
        #elseif os(macOS)
        Color(nsColor: .separatorColor)
        #else
        Color(.separator)
        #endif
    }
}
#endif
