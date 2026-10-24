// MacHelpView.swift
// Pepinillo — native macOS help window
//
// The Help menu surface required by the macOS design contract ("Menus: …
// Help"). Opened via Help ▸ Pepinillo Help (⇧⌘?) and from the menu bar
// popover. Renders the same FAQ catalog as the iOS Help & Support screen
// (`HelpContent.swift`) so both platforms answer the same questions, and
// stays compact on purpose: three matte cards — getting started, FAQ,
// contact — scannable in one screen, not a manual.

import SwiftUI

struct MacHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                intro
                gettingStartedCard
                faqCard
                privacyCard
                contactCard
            }
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(24)
        }
        .systemContentBackground(grouped: true)
        .navigationTitle(String(localized: "Pepinillo Help"))
    }

    // MARK: - Intro

    /// The window title bar already names the window; the content opens
    /// with one quiet line instead of a repeated hero title.
    private var intro: some View {
        Text(String(localized: "Short answers to common questions — and a quick way to reach us."))
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 2)
    }

    // MARK: - Getting Started

    private var gettingStartedCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "Getting Started"))
                .font(.headline)
                .padding(.bottom, 6)

            helpLink(HelpLinks.quickStartGuide, title: String(localized: "Quick Start Guide"), icon: "book")
            Divider()
            helpLink(HelpLinks.focusTips, title: String(localized: "Focus Tips & Techniques"), icon: "lightbulb")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pepinilloMatteCard()
    }

    // MARK: - FAQ

    private var faqCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "Frequently Asked Questions"))
                .font(.headline)
                .padding(.bottom, 6)

            ForEach(FAQItem.all) { item in
                DisclosureGroup {
                    Text(item.answer)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } label: {
                    Text(item.question)
                        .font(.subheadline.weight(.medium))
                        .padding(.vertical, 4)
                }
                // DisclosureGroup labels don't derive an accessibility label
                // in this context — without this VoiceOver announces seven
                // anonymous "collapsible" triangles.
                .accessibilityLabel(item.question)

                if item.id != FAQItem.all.last?.id {
                    Divider()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pepinilloMatteCard()
    }

    // MARK: - Privacy
    // Apple Podcasts pattern: a short honest summary ("…and privacy")
    // followed by the full policy link. Points live in HelpContent so iOS
    // shows the same summary.

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text(PrivacyContent.title)
                .font(.headline)

            Text(PrivacyContent.intro)
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(PrivacyContent.points, id: \.self) { point in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 5))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                        Text(point)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(.top, 2)

            helpLink(HelpLinks.privacyPolicy, title: PrivacyContent.policyLinkTitle, icon: "hand.raised")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pepinilloMatteCard()
    }

    // MARK: - Contact

    private var contactCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "Contact Us"))
                .font(.headline)
                .padding(.bottom, 6)

            helpLink(HelpLinks.emailSupport, title: String(localized: "Email Support"), icon: "envelope")
            Divider()
            helpLink(HelpLinks.feedback, title: String(localized: "Send Feedback"), icon: "text.bubble")
            Divider()
            helpLink(HelpLinks.xProfile, title: String(localized: "Follow on X"), icon: "bubble.left.and.bubble.right")

            Text(String(localized: "We typically respond within 24 hours."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 10)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pepinilloMatteCard()
    }

    // MARK: - Row

    private func helpLink(_ url: URL, title: String, icon: String) -> some View {
        Link(destination: url) {
            HStack(spacing: 10) {
                Label(title, systemImage: icon)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
        // Plain-styled links don't derive their label either; without this
        // VoiceOver announces a bare "link" for every row.
        .accessibilityLabel(title)
    }
}
