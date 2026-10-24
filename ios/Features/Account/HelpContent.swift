// HelpContent.swift
// Pepinillo — Deep Work Companion for Apple
//
// Shared help & support content: outbound links and the FAQ catalog.
// The iOS Help & Support screen (Account tab) and the native macOS Help
// window both render this catalog so the platforms answer the same
// questions. Keep it compact on purpose — help stays scannable, not a
// manual (competitors cluster between "almost none" and "full reference";
// a short task-oriented FAQ is the sweet spot).

import Foundation

// MARK: - Outbound Links

enum HelpLinks {
    /// Step-by-step guide on the product site.
    static let quickStartGuide = URL(string: "https://creapolis.dev/proyectos/pepinillo/guide")!
    /// Focus techniques article on the product site.
    static let focusTips = URL(string: "https://creapolis.dev/proyectos/pepinillo/tips")!
    /// Direct support inbox.
    static let emailSupport = URL(string: "mailto:hola@creapolis.dev")!
    /// Web feedback form.
    static let feedback = URL(string: "https://creapolis.dev/proyectos/pepinillo/feedback")!
    /// Official X profile.
    static let xProfile = URL(string: "https://x.com/creapolisdev")!
}

// MARK: - FAQ

struct FAQItem: Identifiable {
    /// Locale-independent topic tag. Lets tests pin the help contract
    /// (which topics must be covered) without matching localized strings.
    enum Topic: String, CaseIterable {
        case modes
        case sync
        case subscription
        case streak
        case notifications
        case widgets
    }

    let id = UUID()
    let topic: Topic
    let question: String
    let answer: String

    /// Ordered by how often users hit the topic: how the app works first,
    /// sync and billing next, troubleshooting last. Every `Topic` must be
    /// covered exactly once.
    static let all: [FAQItem] = [
        FAQItem(
            topic: .modes,
            question: String(localized: "How do focus modes work?"),
            answer: String(localized: "Pepinillo offers four focus modes: Pomodoro (25/5 cycles), Flowtime (start when ready, stop when done), Time Blocks (fixed schedule), and Stopwatch (simple timer). Choose the mode that fits your work style from the Focus tab.")
        ),
        FAQItem(
            topic: .sync,
            question: String(localized: "How do I sync across devices?"),
            answer: String(localized: "Pepinillo+ (one-time purchase) syncs tasks, sessions, settings, and analytics between iPhone and iPad using your iCloud account — no Pepinillo sign-in required. Everywhere/AI+ (subscription) syncs tasks, focus sessions, and settings through your Pepinillo account and can recover synced data after you sign in again. Check Settings → iCloud Sync for your current status.")
        ),
        FAQItem(
            topic: .subscription,
            question: String(localized: "Can I use Pepinillo without a subscription?"),
            answer: String(localized: "Yes! The free tier includes the Pomodoro timer, basic task management, and daily streaks. Pepinillo+ adds all focus modes, advanced analytics, and iCloud sync between iPhone and iPad. Everywhere/AI+ adds Pepinillo account sync and recovery.")
        ),
        FAQItem(
            topic: .subscription,
            question: String(localized: "How do I cancel my subscription?"),
            answer: String(localized: "Go to Settings → [Your Name] → Subscriptions, find Pepinillo, and tap Cancel Subscription. You can also manage this from the App Store.")
        ),
        FAQItem(
            topic: .streak,
            question: String(localized: "Why didn't my streak update?"),
            answer: String(localized: "Streaks require at least one completed focus session per day. Make sure you complete a session (not just start one). Pepinillo+ and Everywhere/AI+ users get one free streak skip per week.")
        ),
        FAQItem(
            topic: .notifications,
            question: String(localized: "Why don't I receive notifications?"),
            answer: String(localized: "Make sure notifications are allowed for Pepinillo in System Settings → Notifications (Mac) or Settings → Notifications (iPhone/iPad), and that session alerts or reminders are turned on inside Pepinillo. A Focus mode or Do Not Disturb can also silence alerts from the system side.")
        ),
        FAQItem(
            topic: .widgets,
            question: String(localized: "Why isn't my widget updating?"),
            answer: String(localized: "Widgets don't tick every second — the system refreshes them on a battery-friendly schedule. During a live session the ring advances about every 30 seconds, and data refreshes every time you open the app. If a widget looks frozen, remove it and add it again from the widget gallery.")
        ),
    ]
}
