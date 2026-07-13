// WidgetSurfaceReload.swift
// Pepinillo — Deep Work Companion for Apple
//
// Reloads Home/Lock Screen focus widgets and the Control Center toggle when
// session state changes in the main app process (#231).

import WidgetKit

enum WidgetSurfaceReload {
    static let focusHomeKind = "FocusHomeScreenWidget"
    static let focusLockKind = "FocusLockScreenWidget"
    static let tasksHomeKind = "TasksHomeScreenWidget"
    static let controlCenterKind = "com.pepinillo.control-center.focus-toggle"

    /// Reload focus widgets and the Control Center toggle.
    static func reloadFocusAndControlCenter() {
        WidgetCenter.shared.reloadTimelines(ofKind: focusHomeKind)
        WidgetCenter.shared.reloadTimelines(ofKind: focusLockKind)
        if #available(iOS 18.0, *) {
            ControlCenter.shared.reloadControls(ofKind: controlCenterKind)
        }
    }

    /// Reload focus widgets, tasks widget, and Control Center toggle.
    static func reloadFocusTasksAndControlCenter() {
        reloadFocusAndControlCenter()
        WidgetCenter.shared.reloadTimelines(ofKind: tasksHomeKind)
    }
}