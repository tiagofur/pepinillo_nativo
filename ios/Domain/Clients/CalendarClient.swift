// CalendarClient.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Dependency Client wrapping EventKit.
// Creates calendar events when a Time Block session starts,
// so the user's schedule reflects their focus blocks.

import Foundation
import EventKit
import ComposableArchitecture

struct CalendarClient: Sendable {
    /// Request calendar access.
    var requestAccess: @Sendable () async throws -> Bool = { false }

    /// Check whether calendar access has been granted.
    var isAuthorized: @Sendable () -> Bool = { false }

    /// Create a calendar event for a focus session. Returns its identifier (S2).
    var createFocusEvent: @Sendable (
        _ title: String,
        _ startDate: Date,
        _ durationMinutes: Int,
        _ mode: String
    ) async throws -> String = { _, _, _, _ in "" }

    /// Remove a previously created focus event by its identifier.
    var removeFocusEvent: @Sendable (_ eventIdentifier: String) async throws -> Void = { _ in }
}

extension CalendarClient: DependencyKey {
    static let liveValue: CalendarClient = {
        nonisolated(unsafe) let store = EKEventStore()

        return CalendarClient(
            requestAccess: {
                if #available(iOS 17.0, macOS 14.0, *) {
                    return try await store.requestFullAccessToEvents()
                } else {
                    return try await store.requestAccess(to: .event)
                }
            },
            isAuthorized: {
                let status = EKEventStore.authorizationStatus(for: .event)
                if #available(iOS 17.0, macOS 14.0, *) {
                    return status == .fullAccess
                } else {
                    return status == .authorized
                }
            },
            createFocusEvent: { title, startDate, durationMinutes, mode in
                let event = EKEvent(eventStore: store)
                event.title = "🎯 \(title)"
                event.startDate = startDate
                event.endDate = startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
                event.notes = "Focus session (\(mode)) created by Pepinillo"
                event.calendar = store.defaultCalendarForNewEvents
                event.availability = .busy
                try store.save(event, span: .thisEvent)
                return event.eventIdentifier ?? ""
            },
            removeFocusEvent: { identifier in
                guard let event = store.event(withIdentifier: identifier) else { return }
                try store.remove(event, span: .thisEvent)
            }
        )
    }()

    static let testValue = CalendarClient()
}

extension DependencyValues {
    var calendarClient: CalendarClient {
        get { self[CalendarClient.self] }
        set { self[CalendarClient.self] = newValue }
    }
}
