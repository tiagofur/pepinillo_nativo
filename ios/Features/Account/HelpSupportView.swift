// HelpSupportView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Full-screen help & support destination pushed from Account tab.
// Provides FAQ, contact options, and links to documentation.

import SwiftUI

struct HelpSupportView: View {
    @State private var expandedFAQ: FAQItem.ID?

    var body: some View {
        List {
            quickActionsSection
            faqSection
            contactSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "Help & Support"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        Section {
            Link(destination: URL(string: "https://pepinillo.app/guide")!) {
                Label(String(localized: "Quick Start Guide"), systemImage: "book")
            }

            Link(destination: URL(string: "https://pepinillo.app/tips")!) {
                Label(String(localized: "Focus Tips & Techniques"), systemImage: "lightbulb")
            }
        } header: {
            Text(String(localized: "Getting Started"))
        }
    }

    // MARK: - FAQ

    private var faqSection: some View {
        Section {
            ForEach(FAQItem.all) { item in
                FAQRow(item: item, isExpanded: expandedFAQ == item.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedFAQ = expandedFAQ == item.id ? nil : item.id
                        }
                    }
            }
        } header: {
            Text(String(localized: "Frequently Asked Questions"))
        }
    }

    // MARK: - Contact

    private var contactSection: some View {
        Section {
            Link(destination: URL(string: "mailto:support@pepinillo.app")!) {
                Label(String(localized: "Email Support"), systemImage: "envelope")
            }

            Link(destination: URL(string: "https://pepinillo.app/feedback")!) {
                Label(String(localized: "Send Feedback"), systemImage: "text.bubble")
            }

            Link(destination: URL(string: "https://twitter.com/pepinilloapp")!) {
                Label(String(localized: "Follow on X/Twitter"), systemImage: "bubble.left.and.bubble.right")
            }
        } header: {
            Text(String(localized: "Contact Us"))
        } footer: {
            Text(String(localized: "We typically respond within 24 hours."))
                .font(.caption)
        }
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
            answer: String(localized: "Sign in with your Apple ID or create an account. Pro subscribers get iCloud sync across all Apple devices automatically.")
        ),
        FAQItem(
            question: String(localized: "Can I use Pepinillo without a subscription?"),
            answer: String(localized: "Yes! The free tier includes the Pomodoro timer, basic task management, and daily streaks. Upgrade to Pro for all focus modes, advanced analytics, and cross-device sync.")
        ),
        FAQItem(
            question: String(localized: "How do I cancel my subscription?"),
            answer: String(localized: "Go to Settings → [Your Name] → Subscriptions, find Pepinillo, and tap Cancel Subscription. You can also manage this from the App Store.")
        ),
        FAQItem(
            question: String(localized: "Why didn't my streak update?"),
            answer: String(localized: "Streaks require at least one completed focus session per day. Make sure you complete a session (not just start one). Pro users get one free streak skip per week.")
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
