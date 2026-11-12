// NotificationCopyTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Copy selection for the streak-aware daily reminder (#732). Assertions are
// language-agnostic (presence of the day number / generic-vs-personalized
// branch) so they hold on any test-host locale.

import Testing
@testable import Pepinillo

struct NotificationCopyTests {

    @Test func zeroStreakUsesGenericInvitation() {
        let zero = NotificationCopy.dailyReminderBody(streakDays: 0)
        let negative = NotificationCopy.dailyReminderBody(streakDays: -3)
        #expect(zero == negative)
        #expect(!zero.contains("0"))
    }

    @Test func positiveStreakIncludesTheDayNumber() {
        for days in [1, 2, 3, 5, 30, 365] {
            #expect(NotificationCopy.dailyReminderBody(streakDays: days).contains("\(days)"))
        }
    }

    @Test func personalizedBranchDiffersFromGenericBranch() {
        // The streak branch must not collapse into the generic pitch, or the
        // re-engagement personalization silently disappears.
        #expect(NotificationCopy.dailyReminderBody(streakDays: 5)
            != NotificationCopy.dailyReminderBody(streakDays: 0))
    }
}
