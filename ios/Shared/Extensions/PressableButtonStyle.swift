// PressableButtonStyle.swift
// Pepinillo — Deep Work Companion for Apple
//
// Alias of PepinilloButtonStyle for call sites that use `.buttonStyle(.pressable)`.
// Keep both names so Focus and other screens stay readable without dual press feels.

import SwiftUI

typealias PressableButtonStyle = PepinilloButtonStyle

extension ButtonStyle where Self == PepinilloButtonStyle {
    static var pressable: PepinilloButtonStyle { PepinilloButtonStyle() }
}
