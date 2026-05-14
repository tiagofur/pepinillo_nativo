// AppStoreFocusedValue.swift
// Pepinillo — shared FocusedValue key for keyboard shortcut access.

import SwiftUI
import ComposableArchitecture

private struct AppStoreKey: FocusedValueKey {
    typealias Value = StoreOf<AppFeature>
}

extension FocusedValues {
    var appStore: StoreOf<AppFeature>? {
        get { self[AppStoreKey.self] }
        set { self[AppStoreKey.self] = newValue }
    }
}
