// Achievement.swift
// Pepinillo — Deep Work Companion for Apple
//
// Achievement model — predefined badges with progress tracking.
// Mirrors Android's Achievement enum for cross-platform parity.

import Foundation
import SwiftData

public enum Achievement: String, CaseIterable, Equatable, Sendable {
    case firstSession
    case weekStreak
    case pomodoroMaster
    case deepDiver
    case centuryClub
    case earlyBird

    var title: String {
        switch self {
        case .firstSession:   return String(localized: "First Focus")
        case .weekStreak:     return String(localized: "Week Warrior")
        case .pomodoroMaster: return String(localized: "Pomodoro Master")
        case .deepDiver:      return String(localized: "Deep Diver")
        case .centuryClub:    return String(localized: "Century Club")
        case .earlyBird:      return String(localized: "Early Bird")
        }
    }

    var description: String {
        switch self {
        case .firstSession:   return String(localized: "Complete your first session")
        case .weekStreak:     return String(localized: "7-day focus streak")
        case .pomodoroMaster: return String(localized: "Complete 100 pomodoros")
        case .deepDiver:      return String(localized: "Complete 10 deep work sessions")
        case .centuryClub:    return String(localized: "100 total focus sessions")
        case .earlyBird:      return String(localized: "Start 10 sessions before 8am")
        }
    }

    var emoji: String {
        switch self {
        case .firstSession:   return "🎯"
        case .weekStreak:     return "🔥"
        case .pomodoroMaster: return "🌶️"
        case .deepDiver:      return "🤿"
        case .centuryClub:    return "💯"
        case .earlyBird:      return "🐦"
        }
    }

    var systemImage: String {
        switch self {
        case .firstSession:   return "target"
        case .weekStreak:     return "flame.fill"
        case .pomodoroMaster: return "timer"
        case .deepDiver:      return "figure.water.fitness"
        case .centuryClub:    return "100.circle.fill"
        case .earlyBird:      return "bird.fill"
        }
    }

    var requiredCount: Int {
        switch self {
        case .firstSession:   return 1
        case .weekStreak:     return 7
        case .pomodoroMaster: return 100
        case .deepDiver:      return 10
        case .centuryClub:    return 100
        case .earlyBird:      return 10
        }
    }
}

public struct UserAchievement: Equatable, Identifiable, Sendable {
    public var id: String { achievement.rawValue }
    let achievement: Achievement
    let unlockedAt: Date?
    let progress: Int

    var isUnlocked: Bool { unlockedAt != nil }

    var progressFraction: Double {
        min(1.0, Double(progress) / Double(achievement.requiredCount))
    }
}

// MARK: - Persistence (S1-S2)

/// SwiftData-backed achievement record. Progress continues to be derived from
/// live counters (single source of truth); unlockedAt is persisted on first
/// unlock because recomputation can only ever stamp now.
@Model
public final class AchievementRecord {
    @Attribute(.unique) public var id: String
    public var progress: Int
    public var unlockedAt: Date?

    public init(achievementID: String, progress: Int, unlockedAt: Date? = nil) {
        self.id = achievementID
        self.progress = progress
        self.unlockedAt = unlockedAt
    }
}

/// One-shot import of in-memory achievements into the store. Idempotent:
/// existing records are never duplicated and an existing unlockedAt is never
/// overwritten (first unlock wins). Migrated unlocks stamp now — historical
/// unlock dates were never recorded (see feature doc L3).
/// Internal like UserAchievement: the engine-facing migration API is not public surface.
func migrateAchievementsIfNeeded(_ achieved: [UserAchievement], into context: ModelContext) throws {
    var byID: [String: AchievementRecord] = [:]
    for record in try context.fetch(FetchDescriptor<AchievementRecord>()) {
        byID[record.id] = record
    }
    for item in achieved {
        let id = item.achievement.rawValue
        if let record = byID[id] {
            if record.unlockedAt == nil, let unlocked = item.unlockedAt {
                record.unlockedAt = unlocked
                record.progress = item.progress
            }
            continue
        }
        let record = AchievementRecord(achievementID: id, progress: item.progress, unlockedAt: item.unlockedAt)
        context.insert(record)
        byID[id] = record
    }
    try context.save()
}
