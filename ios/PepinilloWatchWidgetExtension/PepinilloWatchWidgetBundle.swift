// PepinilloWatchWidgetBundle.swift
// Pepinillo — Deep Work Companion for Apple
//
// Registers watchOS complications (#237).

import WidgetKit
import SwiftUI

@main
struct PepinilloWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        PepinilloWatchComplication()
        PepinilloTasksComplication()
    }
}