// PlanFilter.swift
// Pepinillo — Deep Work Companion for Apple
//
// Smart-list filter enum used by PlanSidebar and PlanTaskList.
// Maps to the 4 sections in PlanView (Today / Inbox / Upcoming / Completed).

import SwiftUI

enum PlanFilter: String, Hashable, CaseIterable, Identifiable {
    case today
    case inbox
    case upcoming
    case completed

    var id: Self { self }

    var title: String {
        switch self {
        case .today:     return String(localized: "Today")
        case .inbox:     return String(localized: "Inbox")
        case .upcoming:  return String(localized: "Upcoming")
        case .completed: return String(localized: "Completed")
        }
    }

    var systemImage: String {
        switch self {
        case .today:     return "flame.fill"
        case .inbox:     return "tray"
        case .upcoming:  return "calendar"
        case .completed: return "checkmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .today:     return .orange
        case .inbox:     return .blue
        case .upcoming:  return .purple
        case .completed: return .green
        }
    }
}
