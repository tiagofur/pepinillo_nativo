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
                .pepinilloWidgetBackground(mode: entry.focusMode ?? entry.preferredModeID)
                .widgetURL(URL(string: "pepinillo://focus"))
        }
        .configurationDisplayName(String(localized: LocalizedStringResource("widget.focus.home.displayname", defaultValue: "Focus Timer")))
        .description(String(localized: LocalizedStringResource("widget.focus.home.description", defaultValue: "See your daily focus progress and active timer.")))
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
                .widgetURL(URL(string: "pepinillo://focus"))
        }
        .configurationDisplayName(String(localized: LocalizedStringResource("widget.focus.lockscreen.displayname", defaultValue: "Focus")))
        .description(String(localized: LocalizedStringResource("widget.focus.lockscreen.description", defaultValue: "Quick glance at your focus session.")))
        #if os(iOS)
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
        #else
        .supportedFamilies([])
        #endif
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
        case .systemMedium, .systemLarge:
            // Tier split (PRD/04): free keeps the small timer; the full
            // live-timer layouts are Pepinillo+.
            if entry.isProUser {
                familyView
            } else {
                WidgetProRequiredView(title: String(localized: LocalizedStringResource(
                    "widget.focus.pro.title",
                    defaultValue: "Medium and large focus widgets"
                )))
            }
        default:
            FocusWidgetSmall(entry: entry)
        }
    }

    @ViewBuilder
    private var familyView: some View {
        switch family {
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
        #if os(iOS)
        switch family {
        case .accessoryCircular:
            FocusWidgetAccessoryCircular(entry: entry)
        case .accessoryRectangular:
            FocusWidgetAccessoryRectangular(entry: entry)
        default:
            FocusWidgetAccessoryCircular(entry: entry)
        }
        #else
        EmptyView()
        #endif
    }
}

// MARK: - Widget Bundle

@main
struct PepinilloWidgetBundle: WidgetBundle {
    var body: some Widget {
        FocusHomeScreenWidget()
        #if os(iOS)
        FocusLockScreenWidget()
        #endif
        TasksHomeScreenWidget()
        DashboardHomeScreenWidget()
    }
}
