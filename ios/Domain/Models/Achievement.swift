// Achievement.swift
// Pepinillo — Deep Work Companion for Apple
//
// Achievement model — predefined badges with progress tracking.
// Mirrors Android's Achievement enum for cross-platform parity.

import Foundation

enum Achievement: String, CaseIterable, Equatable, Sendable {
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

struct UserAchievement: Equatable, Identifiable, Sendable {
    var id: String { achievement.rawValue }
    let achievement: Achievement
    let unlockedAt: Date?
    let progress: Int

    var isUnlocked: Bool { unlockedAt != nil }

    var progressFraction: Double {
        min(1.0, Double(progress) / Double(achievement.requiredCount))
    }
}
