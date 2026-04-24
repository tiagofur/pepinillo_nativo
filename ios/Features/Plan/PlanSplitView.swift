// PlanSplitView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Adaptive layout wrapper for the Plan tab.
//
// iPad landscape: VStack(pills) + HStack(list 40% | detail 60%). No sheet.
// iPad portrait:  VStack(pills) + HStack(list 50% | detail 50%). No sheet.
// iPhone:         pills top + NavigationStack + sheet for detail.
//
// IMPORTANT: size-class branching happens at THIS level. All sheet/inline decisions
// are made here — never inside child views.

import SwiftUI
import ComposableArchitecture

struct PlanSplitView: View {
    @Bindable var store: StoreOf<TaskListFeature>
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Namespace private var heroNS

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

    // MARK: - iPhone: pills top + NavigationStack + sheet for detail

    @ViewBuilder
    private var iPhoneContent: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PlanFilterPills(
                    selection: Binding(
                        get: { store.selectedPlanFilter },
                        set: { store.send(.planFilterSelected($0)) }
                    )
                )
                Divider()
                PlanTaskList(
                    store: store,
                    filter: store.selectedPlanFilter,
                    showsTitle: false,
                    heroNamespace: heroNS
                )
                .navigationTitle(store.selectedPlanFilter.title)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(
            item: $store.scope(state: \.detail, action: \.detail)
        ) { detailStore in
            NavigationStack {
                TaskDetailView(store: detailStore)
            }
            .modifier(OptionalZoomTransition(sourceID: detailStore.taskID, namespace: heroNS))
            .presentationDetents([.large])
            .pepinilloSheetStyle()
        }
    }

    // MARK: - Shared detail pane (landscape column + portrait right column)

    @ViewBuilder
    private var detailPane: some View {
        if let presentedStore = store.scope(state: \.detail, action: \.detail) {
            let childStore = presentedStore.scope(state: \.self, action: \.presented)
            TaskDetailView(store: childStore, isSheet: false)
        } else {
            ContentUnavailableView(
                String(localized: "No Task Selected"),
                systemImage: "checklist",
                description: Text(String(localized: "Pick a task from the list to view its details."))
            )
        }
    }
}

// MARK: - Hero zoom transition helper (iOS 18+)

/// Applies .navigationTransition(.zoom(sourceID:in:)) on iOS 18+.
/// On iOS 17 falls back to no-op so the system modal animation is used.
private struct OptionalZoomTransition: ViewModifier {
    let sourceID: AnyHashable
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, watchOS 11.0, *) {
            content.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            content
        }
    }
}
