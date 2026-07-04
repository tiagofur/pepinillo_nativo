// PlanFilterPills.swift
// Pepinillo — Deep Work Companion for Apple
//
// Horizontal scrollable filter picker for the Plan screen in portrait iPad.
// Replaces the sidebar column with compact pill-style tabs.

import SwiftUI

struct PlanFilterPills: View {
    @Binding var selection: PlanFilter
    @Namespace private var namespace

    var body: some View {
        Group {
            if #available(iOS 26.0, macOS 26.0, *) {
                GlassEffectContainer(spacing: 8) {
                    scrollContent
                }
            } else {
                scrollContent
            }
        }
        .padding(.vertical, 8)
    }

    private var scrollContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PlanFilter.allCases) { filter in
                    pillButton(for: filter)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func pillButton(for filter: PlanFilter) -> some View {
        let isSelected = selection == filter

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selection = filter
            }
            HapticManager.selection()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: filter.systemImage)
                    .font(.caption)
                    .contentTransition(.symbolEffect(.replace))
                Text(filter.title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isSelected ? filter.color : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .planFilterGlass(filter: filter, isSelected: isSelected, namespace: namespace)
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    @ViewBuilder
    func planFilterGlass(filter: PlanFilter, isSelected: Bool, namespace: Namespace.ID) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self
                .glassEffect(
                    .regular
                        .interactive(true)
                        .tint(isSelected ? filter.color.opacity(0.12) : nil),
                    in: .capsule
                )
                .glassEffectID("plan-filter-\(filter.rawValue)", in: namespace)
        } else {
            self
                .background {
                    ZStack {
                        Capsule().fill(.regularMaterial)
                        if isSelected {
                            Capsule()
                                .fill(filter.color.opacity(0.18))
                                .matchedGeometryEffect(id: "pill_bg", in: namespace)
                        }
                    }
                }
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(
                            isSelected ? filter.color.opacity(0.4) : Color.primary.opacity(0.15),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(isSelected ? 0.12 : 0.06), radius: 6, y: 2)
        }
    }
}
