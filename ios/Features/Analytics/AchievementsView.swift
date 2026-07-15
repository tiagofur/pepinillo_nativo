// AchievementsView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Horizontal scrollable achievements section for the Analytics dashboard.
// Shows unlocked badges and locked ones with progress bars.

import SwiftUI

struct AchievementsSection: View {
    let achievements: [UserAchievement]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Achievements"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if achievements.isEmpty {
                PepinilloEmptyState(
                    title: String(localized: "achievements.empty.title", defaultValue: "No Achievements Yet"),
                    description: String(localized: "achievements.empty.description",
                                         defaultValue: "Complete focus sessions to unlock your first badge."),
                    systemImage: "trophy",
                    tint: .accentColor,
                    cornerRadius: GlassCornerRadius.card
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(achievements) { userAchievement in
                            AchievementCard(userAchievement: userAchievement)
                        }
                    }
                }
            }
        }
        .padding(16)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
    }
}

// MARK: - Achievement Card

private struct AchievementCard: View {
    let userAchievement: UserAchievement

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: userAchievement.isUnlocked
                  ? userAchievement.achievement.systemImage
                  : "lock.fill")
                .font(.largeTitle)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(userAchievement.isUnlocked ? Color.accentColor : .secondary)
                .accessibilityHidden(true)

            Text(userAchievement.achievement.title)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(1)

            if !userAchievement.isUnlocked {
                ProgressView(value: userAchievement.progressFraction)
                    .tint(.accentColor)
                    .accessibilityHidden(true)

                Text("\(userAchievement.progress)/\(userAchievement.achievement.requiredCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 100)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            userAchievement.isUnlocked
                ? Color.accentColor.opacity(0.12)
                : Color.pepinilloTertiarySystemBackground
        )
        .clipShape(RoundedRectangle(cornerRadius: GlassCornerRadius.tile, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            userAchievement.isUnlocked
                ? "\(userAchievement.achievement.title): unlocked"
                : "\(userAchievement.achievement.title): \(userAchievement.progress) of \(userAchievement.achievement.requiredCount)"
        )
    }
}
