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
                        .font(.subheadline.bold())
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
                    .frame(maxWidth: 480)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 60) // Extra padding for the page index indicators
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
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(
                            (currentPage < pages.count
                             ? Color.accentColor
                             : Color(red: 0.18, green: 0.55, blue: 0.23)).gradient
                        )
                )
                .shadow(color: (currentPage < pages.count ? Color.accentColor : Color.green).opacity(0.3), radius: 10, y: 5)
        }
        .accessibilityLabel(currentPage < pages.count
            ? String(localized: "Continue to next page")
            : String(localized: "Get started with Pepinillo"))
    }

    // MARK: - Get Started Page

    private var getStartedPage: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Text("🥒")
                        .font(.system(size: 80))
                        .accessibilityHidden(true)
                        .shadow(radius: 10)

                    Text(String(localized: "Ready to focus?"))
                        .font(.largeTitle.bold())

                    Text(String(localized: "Choose your default focus style. You can change this later in settings."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 60)
                .readableContent(maxWidth: 672)

                // Mode selector cards — adaptive grid: 1 col iPhone, 2+ cols iPad
                LazyVGrid(columns: adaptiveCardColumns, spacing: 16) {
                    ForEach(FocusMode.allCases) { mode in
                        DefaultModeCard(
                            mode: mode,
                            isSelected: selectedDefaultMode == mode
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedDefaultMode = mode
                            }
                        }
                    }
                }
                .contentMaxWidth(900)
                .padding(.horizontal, 24)

                Spacer(minLength: 120)
            }
        }
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
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
            emoji: "🎯",
            title: String(localized: "Choose Your Focus"),
            subtitle: String(localized: "4 modes, 1 goal"),
            description: String(localized: "Whether it's Pomodoro, Flowtime, or Time Blocks, we have the perfect scientific method to keep you in the zone."),
            accentColor: Color.blue
        ),
        OnboardingPage(
            emoji: "✅",
            title: String(localized: "Organize Your Day"),
            subtitle: String(localized: "Integrated Task Manager"),
            description: String(localized: "Don't just track time; track progress. Plan your deep work sessions directly from your task list."),
            accentColor: Color.orange
        ),
        OnboardingPage(
            emoji: "📈",
            title: String(localized: "Analyze Your Growth"),
            subtitle: String(localized: "Dashboard & Insights"),
            description: String(localized: "Visualize your productivity streaks and deep work trends. Knowledge is power to improve your focus."),
            accentColor: Color.accentColor
        )
    ]
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var emojiAppeared = false
    @State private var titleAppeared = false
    @State private var descAppeared = false
    @State private var floatingOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 60)

            // Emoji in a colored circle
            ZStack {
                Circle()
                    .fill(page.accentColor.opacity(0.12))
                    .frame(width: 140, height: 140)
                    .blur(radius: emojiAppeared ? 0 : 20)
                
                Text(page.emoji)
                    .font(.system(size: 72))
                    .offset(y: floatingOffset)
            }
            .scaleEffect(emojiAppeared ? 1 : 0.4)
            .opacity(emojiAppeared ? 1 : 0)
            .rotationEffect(.degrees(emojiAppeared ? 0 : -15))
            .accessibilityHidden(true)
            .padding(.bottom, 40)

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(page.title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)
                        .offset(x: titleAppeared ? 0 : -50)
                        .opacity(titleAppeared ? 1 : 0)
                        .accessibilityAddTraits(.isHeader)

                    Text(page.subtitle)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(page.accentColor)
                        .offset(x: titleAppeared ? 0 : 50)
                        .opacity(titleAppeared ? 1 : 0)
                }

                Text(page.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary.opacity(0.8))
                    .lineSpacing(4)
                    .scaleEffect(descAppeared ? 1 : 0.9)
                    .opacity(descAppeared ? 1 : 0)
            }
            .padding(32)
            .pepinilloGlass()
            .readableContent(maxWidth: 672)
            .padding(.horizontal, 24)
            .offset(y: descAppeared ? 0 : 30)

            Spacer()
        }
        .onAppear {
            if reduceMotion {
                emojiAppeared = true
                titleAppeared = true
                descAppeared = true
            } else {
                // Staggered entrance
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                    emojiAppeared = true
                }
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                    titleAppeared = true
                }
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.5)) {
                    descAppeared = true
                }
                
                // Floating emoji effect
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    floatingOffset = -10
                }
            }
        }
        .onDisappear {
            emojiAppeared = false
            titleAppeared = false
            descAppeared = false
            floatingOffset = 0
        }
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
                        .frame(width: 48, height: 48)
                    Text(mode.icon)
                        .font(.title)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(modeTagline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? modeColor : .secondary.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .pepinilloGlass()
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? modeColor : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
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
