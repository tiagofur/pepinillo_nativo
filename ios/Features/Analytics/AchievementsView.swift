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
                Text(String(localized: "Complete sessions to unlock achievements"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .pepinilloGlass(cornerRadius: 16)
    }
}

// MARK: - Achievement Card

private struct AchievementCard: View {
    let userAchievement: UserAchievement

    var body: some View {
        VStack(spacing: 6) {
            Text(userAchievement.isUnlocked ? userAchievement.achievement.emoji : "🔒")
                .font(.largeTitle)
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
                : Color(.tertiarySystemBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            userAchievement.isUnlocked
                ? "\(userAchievement.achievement.title): unlocked"
                : "\(userAchievement.achievement.title): \(userAchievement.progress) of \(userAchievement.achievement.requiredCount)"
        )
    }
}
