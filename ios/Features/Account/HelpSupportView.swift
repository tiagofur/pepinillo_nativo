// HelpSupportView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Full-screen help & support destination pushed from Account tab.
// Provides FAQ, contact options, and links to documentation.

import SwiftUI

struct HelpSupportView: View {
    @State private var expandedFAQ: FAQItem.ID?

    var body: some View {
        Form {
            // MARK: - Getting Started
            Section(String(localized: "Getting Started")) {
                Link(destination: URL(string: "https://creapolis.dev/proyectos/pepinillo/guide")!) {
                    Label(String(localized: "Quick Start Guide"), systemImage: "book")
                }
                Link(destination: URL(string: "https://creapolis.dev/proyectos/pepinillo/tips")!) {
                    Label(String(localized: "Focus Tips & Techniques"), systemImage: "lightbulb")
                }
            }

            // MARK: - FAQ
            Section(String(localized: "Frequently Asked Questions")) {
                ForEach(FAQItem.all) { item in
                    FAQRow(item: item, isExpanded: expandedFAQ == item.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedFAQ = expandedFAQ == item.id ? nil : item.id
                            }
                        }
                }
            }

            // MARK: - Contact
            Section {
                Link(destination: URL(string: "mailto:hola@creapolis.dev")!) {
                    Label(String(localized: "Email Support"), systemImage: "envelope")
                }
                Link(destination: URL(string: "https://creapolis.dev/proyectos/pepinillo/feedback")!) {
                    Label(String(localized: "Send Feedback"), systemImage: "text.bubble")
                }
                Link(destination: URL(string: "https://x.com/creapolisdev")!) {
                    Label(String(localized: "Follow on X"), systemImage: "bubble.left.and.bubble.right")
                }
            } header: {
                Text(String(localized: "Contact Us"))
            } footer: {
                Text(String(localized: "We typically respond within 24 hours."))
            }
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "Help & Support"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - FAQ Model

private struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String

    static let all: [FAQItem] = [
        FAQItem(
            question: String(localized: "How do focus modes work?"),
            answer: String(localized: "Pepinillo offers four focus modes: Pomodoro (25/5 cycles), Flowtime (start when ready, stop when done), Time Blocks (fixed schedule), and Stopwatch (simple timer). Choose the mode that fits your work style from the Focus tab.")
        ),
        FAQItem(
            question: String(localized: "How do I sync across devices?"),
            answer: String(localized: "Pepinillo+ (one-time purchase) syncs tasks, sessions, settings, and analytics between iPhone and iPad using your iCloud account — no Pepinillo sign-in required. Everywhere/AI+ (subscription) syncs tasks, focus sessions, and settings through your Pepinillo account and can recover synced data after you sign in again. Check Settings → iCloud Sync for your current status.")
        ),
        FAQItem(
            question: String(localized: "Can I use Pepinillo without a subscription?"),
            answer: String(localized: "Yes! The free tier includes the Pomodoro timer, basic task management, and daily streaks. Pepinillo+ adds all focus modes, advanced analytics, and iCloud sync between iPhone and iPad. Everywhere/AI+ adds Pepinillo account sync and recovery.")
        ),
        FAQItem(
            question: String(localized: "How do I cancel my subscription?"),
            answer: String(localized: "Go to Settings → [Your Name] → Subscriptions, find Pepinillo, and tap Cancel Subscription. You can also manage this from the App Store.")
        ),
        FAQItem(
            question: String(localized: "Why didn't my streak update?"),
            answer: String(localized: "Streaks require at least one completed focus session per day. Make sure you complete a session (not just start one). Pepinillo+ and Everywhere/AI+ users get one free streak skip per week.")
        ),
    ]
}

// MARK: - FAQ Row

private struct FAQRow: View {
    let item: FAQItem
    let isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.question)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }

            if isExpanded {
                Text(item.answer)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }
}
