// PlanFilterPills.swift
// Pepinillo — Deep Work Companion for Apple
//
// Horizontal scrollable filter picker for the Plan screen in portrait iPad.
// Replaces the sidebar column with compact pill-style tabs.

import SwiftUI

struct PlanFilterPills: View {
    @Binding var selection: PlanFilter
    @Namespace private var namespace
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Group {
            if #available(iOS 26.0, macOS 26.0, *) {
                GlassEffectContainer(spacing: SpacingTokens.sm) {
                    scrollContent
                }
            } else {
                scrollContent
            }
        }
        .padding(.vertical, SpacingTokens.sm)
    }

    private var scrollContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PlanFilter.allCases) { filter in
                    pillButton(for: filter)
                }
            }
            .padding(.horizontal, SpacingTokens.md)
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
            .padding(.vertical, SpacingTokens.sm)
            .planFilterGlass(
                filter: filter,
                isSelected: isSelected,
                namespace: namespace,
                reduceTransparency: reduceTransparency
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(filter.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension View {
    @ViewBuilder
    func planFilterGlass(
        filter: PlanFilter,
        isSelected: Bool,
        namespace: Namespace.ID,
        reduceTransparency: Bool
    ) -> some View {
        if reduceTransparency {
            self
                .background {
                    ZStack {
                        Capsule().fill(Color.pepinilloSecondarySystemGroupedBackground)
                        if isSelected {
                            Capsule()
                                .fill(filter.color.opacity(0.22))
                                .matchedGeometryEffect(id: "pill_bg", in: namespace)
                        }
                    }
                }
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(
                            isSelected ? filter.color.opacity(0.5) : Color.primary.opacity(0.15),
                            lineWidth: 1
                        )
                }
                .shadow(color: isSelected ? filter.color.opacity(0.28) : .clear, radius: 8, y: 2)
        } else if #available(iOS 26.0, macOS 26.0, *) {
            self
                .glassEffect(
                    .regular
                        .interactive(true)
                        .tint(isSelected ? filter.color.opacity(0.12) : nil),
                    in: .capsule
                )
                .glassEffectID("plan-filter-\(filter.rawValue)", in: namespace)
                .shadow(color: isSelected ? filter.color.opacity(0.35) : .clear, radius: 10, y: 3)
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
                .shadow(color: isSelected ? filter.color.opacity(0.28) : .black.opacity(0.06), radius: isSelected ? 8 : 6, y: 2)
        }
    }
}