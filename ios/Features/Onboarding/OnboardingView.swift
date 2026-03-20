// OnboardingView.swift
// Pepinillo — Deep Work Companion for Apple
//
// First-launch onboarding: explains the 4 focus modes, lets the user pick
// their default, and requests notification permissions.
// 4 pages + final "Get Started" page.

import SwiftUI
import ComposableArchitecture

// MARK: - Onboarding View

struct OnboardingView: View {
    let onComplete: (FocusMode) -> Void

    @AppStorage("onboarding_current_page") private var currentPage: Int = 0
    @State private var selectedDefaultMode: FocusMode = .pomodoro

    private let pages: [OnboardingPage] = OnboardingPage.all

    var body: some View {
        ZStack {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }

                // Final page: mode picker + get started
                getStartedPage
                    .tag(pages.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // Skip button (top-right) — skips to final page
            VStack {
                HStack {
                    Spacer()
                    if currentPage < pages.count {
                        Button(String(localized: "Skip")) {
                            withAnimation { currentPage = pages.count }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 24)
                        .padding(.top, 56)
                        .accessibilityLabel(String(localized: "Skip onboarding"))
                        .accessibilityHint(String(localized: "Jump to mode selection"))
                    }
                }
                Spacer()
            }

            // Continue button (bottom)
            VStack {
                Spacer()
                continueButton
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
            }
        }
        .conditionalAnimation(.easeInOut(duration: 0.3), value: currentPage)
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button {
            if currentPage < pages.count {
                withAnimation { currentPage += 1 }
            } else {
                currentPage = 0
                onComplete(selectedDefaultMode)
            }
        } label: {
            Text(currentPage < pages.count ? String(localized: "Continue") : String(localized: "Get Started"))
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    currentPage < pages.count
                        ? Color.accentColor
                        : Color(red: 0.18, green: 0.55, blue: 0.23)  // forest green for final CTA
                )
                .clipShape(Capsule())
        }
        .accessibilityLabel(currentPage < pages.count
            ? String(localized: "Continue to next page")
            : String(localized: "Get started with Pepinillo"))
    }

    // MARK: - Get Started Page

    private var getStartedPage: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("🥒")
                    .font(.system(size: 64))
                    .accessibilityHidden(true)
                Text(String(localized: "Your default mode"))
                    .font(.title2)
                    .fontWeight(.bold)
                Text(String(localized: "You can always change this in Settings."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 80)

            // Mode selector cards
            VStack(spacing: 12) {
                ForEach(FocusMode.allCases) { mode in
                    DefaultModeCard(
                        mode: mode,
                        isSelected: selectedDefaultMode == mode
                    ) {
                        selectedDefaultMode = mode
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let emoji: String
    let title: String
    let subtitle: String
    let description: String
    let accentColor: Color

    static let all: [OnboardingPage] = [
        OnboardingPage(
            emoji: "🍅",
            title: String(localized: "Pomodoro"),
            subtitle: String(localized: "The classic method"),
            description: String(localized: "Work 25 minutes, rest 5. After 4 cycles, take a longer break. Proven for over 30 years to beat procrastination."),
            accentColor: Color(red: 0.91, green: 0.30, blue: 0.24)
        ),
        OnboardingPage(
            emoji: "🌊",
            title: String(localized: "Flowtime"),
            subtitle: String(localized: "Follow your flow"),
            description: String(localized: "Work as long as you're in the zone. Pepinillo tracks your flow and suggests the perfect break length based on how long you focused."),
            accentColor: Color(red: 0.20, green: 0.53, blue: 0.92)
        ),
        OnboardingPage(
            emoji: "📦",
            title: String(localized: "Time Block"),
            subtitle: String(localized: "Own your calendar"),
            description: String(localized: "Commit to a fixed block — 1 hour, 2 hours, whatever you need. One task, no interruptions. The way Cal Newport works."),
            accentColor: Color(red: 0.56, green: 0.27, blue: 0.87)
        ),
        OnboardingPage(
            emoji: "⏱️",
            title: String(localized: "Stopwatch"),
            subtitle: String(localized: "Zero pressure"),
            description: String(localized: "Just start the timer and see how long you focus. No targets, no breaks. Perfect for creative work or when you just need to begin."),
            accentColor: Color(red: 0.18, green: 0.72, blue: 0.44)
        ),
    ]
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 80)

            // Emoji in a colored circle
            ZStack {
                Circle()
                    .fill(page.accentColor.opacity(0.12))
                    .frame(width: 120, height: 120)
                Text(page.emoji)
                    .font(.system(size: 56))
            }
            .scaleEffect(appeared ? 1 : 0.6)
            .opacity(appeared ? 1 : 0)
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(page.accentColor)
                    .accessibilityAddTraits(.isHeader)

                Text(page.subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .offset(y: appeared ? 0 : 20)
            .opacity(appeared ? 1 : 0)

            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary.opacity(0.8))
                .padding(.horizontal, 32)
                .lineSpacing(4)
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)

            Spacer()
            Spacer()
        }
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    appeared = true
                }
            }
        }
        .onDisappear { appeared = false }
    }
}

// MARK: - Default Mode Card

struct DefaultModeCard: View {
    let mode: FocusMode
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(modeColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Text(mode.icon)
                        .font(.title2)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(modeTagline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? modeColor : .secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? modeColor.opacity(0.08) : Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? modeColor : Color.clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            .accessibilityLabel("\(mode.displayName), \(modeTagline)")
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    private var modeColor: Color {
        theme.color(for: mode)
    }

    private var modeTagline: String {
        switch mode {
        case .pomodoro:  return String(localized: "Classic 25/5 cycles — free")
        case .flowtime:  return String(localized: "Follow your natural flow — pro")
        case .timeBlock: return String(localized: "Commit to a fixed block — pro")
        case .stopwatch: return String(localized: "Zero pressure tracking — free")
        }
    }
}
