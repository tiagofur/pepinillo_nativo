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
                Link(destination: HelpLinks.quickStartGuide) {
                    Label(String(localized: "Quick Start Guide"), systemImage: "book")
                }
                Link(destination: HelpLinks.focusTips) {
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
                Link(destination: HelpLinks.emailSupport) {
                    Label(String(localized: "Email Support"), systemImage: "envelope")
                }
                Link(destination: HelpLinks.feedback) {
                    Label(String(localized: "Send Feedback"), systemImage: "text.bubble")
                }
                Link(destination: HelpLinks.xProfile) {
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

// MARK: - FAQ Row
// The FAQ catalog lives in `HelpContent.swift` and is shared with the
// native macOS Help window.

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
