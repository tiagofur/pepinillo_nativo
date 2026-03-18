// FocusWidget.swift
// Pepinillo — Deep Work Companion for Apple
//
// WidgetBundle that registers all Pepinillo widgets.
// Sizes: Small (2x2), Medium (4x2), Large (4x4), Lock Screen (Circular + Rectangular)

import WidgetKit
import SwiftUI

// MARK: - Widget Definitions

/// Home Screen widget: small, medium, and large.
struct FocusHomeScreenWidget: Widget {
    let kind: String = "FocusHomeScreenWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigureFocusWidgetIntent.self,
            provider: FocusWidgetProvider()
        ) { entry in
            FocusWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Focus Timer")
        .description("See your daily focus progress and active timer.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Lock Screen accessory widget.
struct FocusLockScreenWidget: Widget {
    let kind: String = "FocusLockScreenWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigureFocusWidgetIntent.self,
            provider: FocusWidgetProvider()
        ) { entry in
            FocusAccessoryEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Focus")
        .description("Quick glance at your focus session.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Entry View Routers

struct FocusWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FocusWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            FocusWidgetSmall(entry: entry)
        case .systemMedium:
            FocusWidgetMedium(entry: entry)
        case .systemLarge:
            FocusWidgetLarge(entry: entry)
        default:
            FocusWidgetSmall(entry: entry)
        }
    }
}

struct FocusAccessoryEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FocusWidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            FocusWidgetAccessoryCircular(entry: entry)
        case .accessoryRectangular:
            FocusWidgetAccessoryRectangular(entry: entry)
        default:
            FocusWidgetAccessoryCircular(entry: entry)
        }
    }
}

// MARK: - Widget Bundle

@main
struct PepinilloWidgetBundle: WidgetBundle {
    var body: some Widget {
        FocusHomeScreenWidget()
        FocusLockScreenWidget()
    }
}
