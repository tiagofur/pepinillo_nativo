// MilestoneDetectionTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Pure detection tests for the celebration milestones unlock: priority
// order, once-ever latches, thresholds, and the guards that protect
// existing users from false celebrations.

import Testing
@testable import Pepinillo

@Suite
struct MilestoneDetectionTests {

    // MARK: - First session

    @Test func firstSessionFiresOnlyOnTheLiteralFirstSession() {
        #expect(
            CelebrationMilestone.detect(
                allTimeSessions: 1, streakDays: 1, longestTodayMinutes: 5,
                bestMinutesLatch: 0, sessionCountLatch: 0, firstSessionLatch: false
            ) == .firstSession
        )
        // Existing user completing session 412: their overdue session-count
        // celebration fires exactly once (the 100th was never celebrated),
        // never the first-session overlay.
        #expect(
            CelebrationMilestone.detect(
                allTimeSessions: 412, streakDays: 1, longestTodayMinutes: 5,
                bestMinutesLatch: 0, sessionCountLatch: 0, firstSessionLatch: false
            ) == .sessionCount(412)
        )
        // Latch already consumed.
        #expect(
            CelebrationMilestone.detect(
                allTimeSessions: 1, streakDays: 1, longestTodayMinutes: 5,
                bestMinutesLatch: 0, sessionCountLatch: 0, firstSessionLatch: true
            ) == nil
        )
    }

    // MARK: - Priority

    @Test func streakBeatsSessionCountAndPersonalBest() {
        let milestone = CelebrationMilestone.detect(
            allTimeSessions: 50, streakDays: 7, longestTodayMinutes: 95,
            bestMinutesLatch: 30, sessionCountLatch: 10, firstSessionLatch: true
        )
        #expect(milestone == .streakDay(7))
    }

    @Test func sessionCountBeatsPersonalBest() {
        let milestone = CelebrationMilestone.detect(
            allTimeSessions: 52, streakDays: 2, longestTodayMinutes: 95,
            bestMinutesLatch: 30, sessionCountLatch: 10, firstSessionLatch: true
        )
        #expect(milestone == .sessionCount(52))
    }

    // MARK: - Session count thresholds

    @Test func sessionCountCrossesOnlyNewThresholds() {
        #expect(
            CelebrationMilestone.detect(
                allTimeSessions: 11, streakDays: 1, longestTodayMinutes: 0,
                bestMinutesLatch: 0, sessionCountLatch: 10, firstSessionLatch: true
            ) == nil,
            "10 was already celebrated; 11 is not a threshold"
        )
        #expect(
            CelebrationMilestone.detect(
                allTimeSessions: 50, streakDays: 1, longestTodayMinutes: 0,
                bestMinutesLatch: 0, sessionCountLatch: 10, firstSessionLatch: true
            ) == .sessionCount(50)
        )
    }

    // MARK: - Personal best

    @Test func personalBestRequiresFloorAndImprovement() {
        // Below the 30-minute floor — no crown for a 5-minute session.
        #expect(
            CelebrationMilestone.detect(
                allTimeSessions: 12, streakDays: 1, longestTodayMinutes: 5,
                bestMinutesLatch: 0, sessionCountLatch: 12, firstSessionLatch: true
            ) == nil
        )
        // Does not beat the latched best.
        #expect(
            CelebrationMilestone.detect(
                allTimeSessions: 12, streakDays: 1, longestTodayMinutes: 31,
                bestMinutesLatch: 45, sessionCountLatch: 12, firstSessionLatch: true
            ) == nil
        )
        // Genuine improvement.
        #expect(
            CelebrationMilestone.detect(
                allTimeSessions: 12, streakDays: 1, longestTodayMinutes: 52,
                bestMinutesLatch: 45, sessionCountLatch: 12, firstSessionLatch: true
            ) == .personalBest(52)
        )
    }

    @Test func nothingToFiresReturnsNil() {
        #expect(
            CelebrationMilestone.detect(
                allTimeSessions: 7, streakDays: 2, longestTodayMinutes: 20,
                bestMinutesLatch: 60, sessionCountLatch: 0, firstSessionLatch: true
            ) == nil
        )
    }
}
