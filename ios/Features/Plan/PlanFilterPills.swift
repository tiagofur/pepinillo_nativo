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
                Text(filter.title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isSelected ? filter.color : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(pillBackground(isSelected: isSelected, color: filter.color))
            .clipShape(Capsule())
            .overlay(pillBorder(isSelected: isSelected, color: filter.color))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func pillBackground(isSelected: Bool, color: Color) -> some View {
        if isSelected {
            Capsule()
                .fill(color.opacity(0.12))
                .matchedGeometryEffect(id: "pill_bg", in: namespace)
        }
    }

    @ViewBuilder
    private func pillBorder(isSelected: Bool, color: Color) -> some View {
        if isSelected {
            Capsule().stroke(color.opacity(0.3), lineWidth: 1)
        } else {
            Capsule().stroke(.quaternary, lineWidth: 1)
        }
    }
}
