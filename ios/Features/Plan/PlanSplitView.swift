// PlanSplitView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Adaptive layout wrapper for the Plan tab.
//
// iPad landscape: VStack(pills) + HStack(list 40% | detail 60%). No sheet.
// iPad portrait:  VStack(pills) + HStack(list 50% | detail 50%). No sheet.
// iPhone:         NavigationStack + sheet for detail.
//
// IMPORTANT: size-class branching happens at THIS level. All sheet/inline decisions
// are made here — never inside child views.

import SwiftUI
import ComposableArchitecture

struct PlanSplitView: View {
    @Bindable var store: StoreOf<TaskListFeature>
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .regular {
            GeometryReader { geo in
                if geo.size.width > geo.size.height {
                    landscapeContent
                } else {
                    portraitContent
                }
            }
        } else {
            iPhoneContent
        }
    }

    // MARK: - iPad Landscape: pills top + HStack(list 40% | detail 60%)

    @ViewBuilder
    private var landscapeContent: some View {
        VStack(spacing: 0) {
            PlanFilterPills(
                selection: Binding(
                    get: { store.selectedPlanFilter },
                    set: { store.send(.planFilterSelected($0)) }
                )
            )
            Divider()
            HStack(spacing: 0) {
                NavigationStack {
                    PlanTaskList(
                        store: store,
                        filter: store.selectedPlanFilter,
                        showsTitle: false
                    )
                    .navigationTitle(store.selectedPlanFilter.title)
                    .navigationBarTitleDisplayMode(.inline)
                }
                .frame(minWidth: 360, maxWidth: 520)

                Divider()

                NavigationStack { detailPane }
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - iPad Portrait: 2-column HStack (pills top, list | detail bottom)

    @ViewBuilder
    private var portraitContent: some View {
        VStack(spacing: 0) {
            PlanFilterPills(
                selection: Binding(
                    get: { store.selectedPlanFilter },
                    set: { store.send(.planFilterSelected($0)) }
                )
            )
            Divider()
            HStack(spacing: 0) {
                NavigationStack {
                    PlanTaskList(
                        store: store,
                        filter: store.selectedPlanFilter,
                        showsTitle: false
                    )
                    .navigationTitle(String(localized: "Plan"))
                    .navigationBarTitleDisplayMode(.inline)
                }
                .frame(maxWidth: .infinity)

                Divider()

                NavigationStack {
                    detailPane
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - iPhone: NavigationStack + sheet for detail

    @ViewBuilder
    private var iPhoneContent: some View {
        NavigationStack {
            PlanTaskList(
                store: store,
                filter: store.selectedPlanFilter
            )
        }
        .sheet(
            item: $store.scope(state: \.detail, action: \.detail)
        ) { detailStore in
            NavigationStack {
                TaskDetailView(store: detailStore)
            }
            .presentationDetents([.large])
        }
    }

    // MARK: - Shared detail pane (landscape column + portrait right column)

    @ViewBuilder
    private var detailPane: some View {
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
