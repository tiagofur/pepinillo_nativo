// MacSwiftUICompatibility.swift
// Pepinillo — no-op SwiftUI shims for iOS-first shared views on native macOS.

#if os(macOS)
import SwiftUI

enum UIKeyboardType {
    case emailAddress
    case numberPad
}

enum TextInputAutocapitalization {
    case never
}

enum PepinilloNavigationBarTitleDisplayMode {
    case inline
}

extension ToolbarItemPlacement {
    static var topBarTrailing: ToolbarItemPlacement { .automatic }
}

extension View {
    func keyboardType(_ type: UIKeyboardType) -> some View {
        self
    }

    func textInputAutocapitalization(_ autocapitalization: TextInputAutocapitalization) -> some View {
        self
    }

    func navigationBarTitleDisplayMode(_ displayMode: PepinilloNavigationBarTitleDisplayMode) -> some View {
        self
    }
}
#endif
