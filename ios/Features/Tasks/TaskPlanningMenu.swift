// TaskPlanningMenu.swift
// Pepinillo — Deep Work Companion for Apple
//
// «Planificar para…» — the shared menu that replaces the binary Today toggle
// (issue #991 S4, UX Brief): Hoy · Mañana · Este fin de semana · Elegir fecha…
// · Quitar fecha, with a checkmark on the option matching the current plan.
// The caller owns the native picker surface (`onPickDate`: inline DatePicker in
// the detail, sheet in the list containers).

import SwiftUI

struct TaskPlanningMenu<MenuLabel: View>: View {
    let plannedDate: Date?
    var onChange: (Date?) -> Void
    var onPickDate: (() -> Void)?
    @ViewBuilder var label: () -> MenuLabel

    private var calendar: Calendar { .current }

    private var isToday: Bool {
        plannedDate.map { calendar.isDateInToday($0) || $0 < calendar.startOfDay(for: .now) } == true
    }

    private var isTomorrow: Bool {
        plannedDate.map { calendar.isDateInTomorrow($0) } == true
    }

    private var isWeekend: Bool {
        guard let plannedDate, calendar.isDateInWeekend(plannedDate) else { return false }
        let nextWeekend = TaskPlanning.upcomingWeekend()
        return calendar.isDate(plannedDate, inSameDayAs: nextWeekend)
    }

    var body: some View {
        Menu {
            Button {
                onChange(TaskPlanning.plannedDay(.now))
            } label: {
                Label(
                    String(localized: "Today"),
                    systemImage: isToday ? "checkmark" : "sun.max"
                )
            }
            Button {
                onChange(TaskPlanning.tomorrow())
            } label: {
                Label(
                    String(localized: "Tomorrow"),
                    systemImage: isTomorrow ? "checkmark" : "sunrise"
                )
            }
            Button {
                onChange(TaskPlanning.upcomingWeekend())
            } label: {
                Label(
                    String(localized: "This Weekend"),
                    systemImage: isWeekend ? "checkmark" : "calendar"
                )
            }
            if let onPickDate {
                Button {
                    onPickDate()
                } label: {
                    Label(String(localized: "Choose Date…"), systemImage: "calendar.badge.plus")
                }
            }
            if plannedDate != nil {
                Divider()
                Button(role: .destructive) {
                    onChange(nil)
                } label: {
                    Label(String(localized: "Remove Date"), systemImage: "minus.circle")
                }
            }
        } label: {
            label()
        }
    }
}

/// Compact value text for a planned day: Today / Tomorrow / Sat, Nov 28.
func taskPlanningValueText(_ plannedDate: Date?, now: Date = .now) -> String {
    guard let plannedDate else { return "—" }
    let calendar = Calendar.current
    if calendar.isDateInToday(plannedDate) { return String(localized: "Today") }
    if calendar.isDateInTomorrow(plannedDate) { return String(localized: "Tomorrow") }
    return plannedDate.formatted(.dateTime.month(.abbreviated).day())
}

/// Native date picker for «Elegir fecha…» — sheet on iOS list containers,
/// also used inline-capable from detail contexts (issue #991 S4).
struct PlanDatePickerSheet: View {
    @Binding var draft: Date
    let onConfirm: (Date) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            DatePicker(
                String(localized: "Schedule for…"),
                selection: $draft,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle(String(localized: "Schedule for…"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) {
                        onConfirm(TaskPlanning.plannedDay(draft))
                    }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium])
        #endif
    }
}

/// Identifiable box so a plain UUID can drive `.sheet(item:)` (issue #991 S4).
struct PlanPickTarget: Identifiable, Equatable {
    let id: UUID
}
