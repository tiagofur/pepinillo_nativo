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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PlanFilter.allCases) { filter in
                    pillButton(for: filter)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
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
                    .symbolEffect(.bounce, value: isSelected)
                Text(filter.title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isSelected ? filter.color : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                ZStack {
                    // Always-visible glass base so pills read clearly over any gradient
                    Capsule().fill(.regularMaterial)

                    // Selected: add colored tint on top of the glass
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
                        isSelected ? filter.color.opacity(0.4) : Color.white.opacity(0.15),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(isSelected ? 0.12 : 0.06), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}
