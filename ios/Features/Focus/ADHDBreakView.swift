// ADHDBreakView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Guided break activities for ADHD-friendly mode.
// Shows structured, sensory-friendly break suggestions to help
// neurodivergent users transition back to focus after a break.

import SwiftUI

struct ADHDBreakView: View {
    let breakDurationMinutes: Int
    let onDismiss: () -> Void

    @State private var selectedActivity: BreakActivity?

    var body: some View {
        NavigationStack {
            VStack(spacing: SpacingTokens.xl) {
                Text(String(localized: "adhdbreak.title", defaultValue: "Break Time"))
                    .font(.title.bold())

                Text(String(format: String(localized: "adhdbreak.instruction", defaultValue: "Pick a guided activity for your %lld-minute break"), breakDurationMinutes))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: SpacingTokens.md) {
                    ForEach(BreakActivity.allCases) { activity in
                        BreakActivityButton(
                            activity: activity,
                            isSelected: selectedActivity == activity
                        ) {
                            selectedActivity = activity
                        }
                    }
                }
                .padding(.horizontal)

                if let activity = selectedActivity {
                    Text(activity.instructions)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SpacingTokens.xxl)
                        .transition(.opacity)
                }

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Text(String(localized: "adhdbreak.backtofocus.button", defaultValue: "Back to Focus"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpacingTokens.base)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 40)
                .padding(.bottom, SpacingTokens.xl)
            }
            .padding(.top, SpacingTokens.md)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

private struct BreakActivityButton: View {
    let activity: BreakActivity
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.sm) {
                Text(activity.emoji)
                    .font(.system(size: 36))
                Text(activity.title)
                    .font(.subheadline.bold())
                Text(activity.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.md)
            .background(cardBackground)
            .overlay(cardBorder)
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: GlassCornerRadius.control, style: .continuous)
            .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.pepinilloSecondarySystemBackground)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: GlassCornerRadius.control, style: .continuous)
            .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
    }
}

// MARK: - Break Activities

enum BreakActivity: String, CaseIterable, Identifiable {
    case breathe
    case stretch
    case hydrate
    case movement

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .breathe:  return "🫁"
        case .stretch:  return "🧘"
        case .hydrate:  return "💧"
        case .movement: return "🚶"
        }
    }

    var title: String {
        switch self {
        case .breathe:  return String(localized: "Breathe")
        case .stretch:  return String(localized: "Stretch")
        case .hydrate:  return String(localized: "Hydrate")
        case .movement: return String(localized: "Move")
        }
    }

    var subtitle: String {
        switch self {
        case .breathe:  return String(localized: "Box breathing")
        case .stretch:  return String(localized: "Neck & shoulders")
        case .hydrate:  return String(localized: "Drink water")
        case .movement: return String(localized: "Walk around")
        }
    }

    var instructions: String {
        switch self {
        case .breathe:
            return String(localized: "Breathe in for 4 counts, hold for 4, breathe out for 4, hold for 4. Repeat until your break ends.")
        case .stretch:
            return String(localized: "Roll your shoulders back 5 times. Tilt your head side to side. Stretch your arms overhead.")
        case .hydrate:
            return String(localized: "Get up and drink a full glass of water. Staying hydrated helps maintain focus.")
        case .movement:
            return String(localized: "Stand up and walk around your space. Look at something far away to rest your eyes.")
        }
    }
}
