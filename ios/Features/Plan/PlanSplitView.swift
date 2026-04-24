// PlanSplitView.swift
// Pepinillo — Deep Work Companion for Apple
//
// 3-column NavigationSplitView wrapper for the Plan tab.
// Sidebar → task list → task detail (Apple Reminders pattern).
//
// iPad portrait:  sidebar overlays on demand; content + detail visible.
// iPad landscape: all 3 columns visible simultaneously.
// iPhone:         collapses to a single push-navigation stack automatically.
//                 Task detail opens as a sheet (existing UX preserved).

import SwiftUI
import ComposableArchitecture

struct PlanSplitView: View {
    @Bindable var store: StoreOf<TaskListFeature>

    var body: some View {
        NavigationSplitView {
            PlanSidebar(
                selection: Binding(
                    get: { store.selectedPlanFilter },
                    set: { store.send(.planFilterSelected($0)) }
                )
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } content: {
            PlanTaskList(
                store: store,
                filter: store.selectedPlanFilter
            )
            // On iPhone (compact), NavigationSplitView collapses and the sheet is the detail.
            // On iPad (regular), the detail column renders inline — no sheet needed.
            .modifier(CompactOnlyDetailSheetModifier(store: store))
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.automatic)
    }

    // MARK: - Detail Column (iPad only — iPhone uses the sheet modifier above)

    @ViewBuilder
    private var detailColumn: some View {
        // scope(state:action:) on @Presents returns
        // Store<TaskDetailFeature.State, PresentationAction<TaskDetailFeature.Action>>?.
        // We strip PresentationAction by scoping to \.presented so TaskDetailView receives
        // the plain StoreOf<TaskDetailFeature> it expects.
        if let presentedStore = store.scope(state: \.detail, action: \.detail) {
            let childStore = presentedStore.scope(state: \.self, action: \.presented)
            ZStack {
                PepinilloLiquidBackground()
                    .ignoresSafeArea()
                TaskDetailView(store: childStore, isSheet: false)
            }
        } else {
            ContentUnavailableView(
                String(localized: "No Task Selected"),
                systemImage: "checklist",
                description: Text(String(localized: "Pick a task from the list to view its details."))
            )
        }
    }
}

// MARK: - Compact-Only Sheet Modifier
//
// Shows the TaskDetailView as a sheet only on compact (iPhone) width.
// On regular (iPad), the detail column renders inline so no sheet is needed.

private struct CompactOnlyDetailSheetModifier: ViewModifier {
    @Bindable var store: StoreOf<TaskListFeature>
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        if horizontalSizeClass == .compact {
            content.sheet(
                item: $store.scope(state: \.detail, action: \.detail)
            ) { detailStore in
                TaskDetailView(store: detailStore)
            }
        } else {
            content
        }
    }
}
