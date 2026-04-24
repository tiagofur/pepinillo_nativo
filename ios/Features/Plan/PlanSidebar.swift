// PlanSidebar.swift
// Pepinillo — Deep Work Companion for Apple
//
// Sidebar column of the Plan NavigationSplitView.
// Shows smart list filters (Today / Inbox / Upcoming / Completed).
// On iPad portrait: collapses behind a toggle button.
// On iPhone: collapses entirely — NavigationSplitView shows the content column directly.
//
// List(selection:) in iOS requires an optional Binding with ForEach + .tag() inside.

import SwiftUI

struct PlanSidebar: View {
    /// Wraps the non-optional state as optional for List selection compatibility.
    @Binding var selection: PlanFilter

    private var optionalBinding: Binding<PlanFilter?> {
        Binding(
            get: { selection },
            set: { newValue in
                // Prevent deselection — a filter is always active.
                if let newValue { selection = newValue }
            }
        )
    }

    var body: some View {
        List(selection: optionalBinding) {
            Section {
                ForEach(PlanFilter.allCases) { filter in
                    Label(filter.title, systemImage: filter.systemImage)
                        .foregroundStyle(filter.color)
                        .tag(filter)
                }
            } header: {
                Text(String(localized: "Smart Lists"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(String(localized: "Plan"))
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}
