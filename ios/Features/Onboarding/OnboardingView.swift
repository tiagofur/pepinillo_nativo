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
            // Full-bleed background that cross-fades between page accent colors
            pageBackground
                .ignoresSafeArea()

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
            #if os(macOS)
            .tabViewStyle(.automatic)
            #else
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            #endif

            // Skip button (top-right) — skips to final page
            VStack {
                HStack {
                    Spacer()
                    if currentPage < pages.count {
                        Button(String(localized: "Skip")) {
                            withAnimation(.easeInOut(duration: 0.4)) { currentPage = pages.count }
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(.black.opacity(0.22), in: Capsule())
                        .contentShape(Capsule())
                        .padding(.horizontal, SpacingTokens.md)
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
                    .padding(.horizontal, SpacingTokens.xxl)
                    .padding(.bottom, 60) // Extra padding for the page index indicators
            }
        }
        .conditionalAnimation(.easeInOut(duration: 0.4), value: currentPage)
    }

    // MARK: - Background Scene

    private var pageBackground: some View {
        let accentColor: Color
        if currentPage < pages.count {
            accentColor = pages[currentPage].accentColor
        } else {
            // Mode picker page — use stopwatch emerald token
            accentColor = ModeColors.stopwatch
        }

        return GeometryReader { geo in
            ZStack(alignment: .top) {
                // Base color fill
                accentColor
                    .opacity(0.08)

                // Top gradient hero area (~58% height)
                LinearGradient(
                    stops: [
                        .init(color: accentColor.opacity(0.72), location: 0),
                        .init(color: accentColor.opacity(0.30), location: 0.55),
                        .init(color: accentColor.opacity(0.0),  location: 0.75)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: geo.size.height)

                // Soft radial glow behind the centerpiece
                RadialGradient(
                    colors: [accentColor.opacity(0.35), .clear],
                    center: .init(x: 0.5, y: 0.22),
                    startRadius: 0,
                    endRadius: geo.size.width * 0.65
                )
            }
        }
        .animation(.easeInOut(duration: 0.45), value: currentPage)
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button {
            if currentPage < pages.count {
                withAnimation(.easeInOut(duration: 0.35)) { currentPage += 1 }
            } else {
                currentPage = 0
                onComplete(selectedDefaultMode)
            }
        } label: {
            Text(currentPage < pages.count ? String(localized: "Continue") : String(localized: "Get Started"))
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)
                .background(
                    Capsule()
                        .fill(
                            (currentPage < pages.count
                             ? (currentPage < pages.count ? pages[currentPage].accentColor : Color.accentColor)
                             : ModeColors.stopwatch).gradient
                        )
                )
                .shadow(
                    color: (currentPage < pages.count ? pages[currentPage].accentColor : Color.accentColor).opacity(0.35),
                    radius: 12, y: 6
                )
        }
        .accessibilityLabel(currentPage < pages.count
            ? String(localized: "Continue to next page")
            : String(localized: "Get started with Pepinillo"))
    }

    // MARK: - Get Started Page

    private var getStartedPage: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.xl) {
                // Header: cucumber badge inline with title
                VStack(spacing: SpacingTokens.sm) {
                    HStack(spacing: 10) {
                        Text("🥒")
                            .font(.system(size: 36))
                            .accessibilityHidden(true)
                        Text(String(localized: "Ready to focus?"))
                            .font(.largeTitle.bold())
                    }

                    Text(String(localized: "Choose your default focus style. You can change this later in settings."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SpacingTokens.xxl)
                }
                .padding(.top, SpacingTokens.xl)
                .readableContent(maxWidth: 672)

                // Mode selector cards — adaptive grid: 1 col iPhone, 2+ cols iPad
                LazyVGrid(columns: adaptiveCardColumns, spacing: SpacingTokens.md) {
                    ForEach(FocusMode.allCases) { mode in
                        DefaultModeCard(
                            mode: mode,
                            isSelected: selectedDefaultMode == mode
                        ) {
                            withAnimation(MotionTokens.bouncy) {
                                selectedDefaultMode = mode
                            }
                        }
                    }
                }
                .contentMaxWidth(900)
                .padding(.horizontal, SpacingTokens.xl)

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
            accentColor: ModeColors.flowtime
        ),
        OnboardingPage(
            emoji: "✅",
            title: String(localized: "Organize Your Day"),
            subtitle: String(localized: "Integrated Task Manager"),
            description: String(localized: "Don't just track time; track progress. Plan your deep work sessions directly from your task list."),
            accentColor: ModeColors.streak
        ),
        OnboardingPage(
            emoji: "📈",
            title: String(localized: "Analyze Your Growth"),
            subtitle: String(localized: "Dashboard & Insights"),
            description: String(localized: "Visualize your productivity streaks and deep work trends. Knowledge is power to improve your focus."),
            accentColor: ModeColors.stopwatch
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
            // Hero area (~top 55%): large emoji with depth layering
            GeometryReader { geo in
                ZStack {
                    // Soft outer glow ring
                    Circle()
                        .fill(page.accentColor.opacity(0.18))
                        .frame(width: 220, height: 220)
                        .blur(radius: 30)

                    // Mid glow ring
                    Circle()
                        .fill(page.accentColor.opacity(0.22))
                        .frame(width: 160, height: 160)
                        .blur(radius: 12)

                    // Inner crisp circle
                    Circle()
                        .fill(page.accentColor.opacity(0.15))
                        .frame(width: 130, height: 130)

                    // Emoji — large, expressive
                    Text(page.emoji)
                        .font(.system(size: 88))
                        .offset(y: floatingOffset)
                        .shadow(color: page.accentColor.opacity(0.4), radius: 16, y: 8)
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                }
                .frame(maxWidth: .infinity)
                .frame(height: geo.size.height)
            }
            .frame(height: 240)
            .scaleEffect(emojiAppeared ? 1 : 0.3)
            .opacity(emojiAppeared ? 1 : 0)
            .rotationEffect(.degrees(emojiAppeared ? 0 : -20))
            .accessibilityHidden(true)
            .padding(.top, 80)
            .padding(.bottom, SpacingTokens.xxl)

            // Content card — glass bottom card
            VStack(spacing: SpacingTokens.xl) {
                VStack(spacing: SpacingTokens.sm) {
                    Text(page.title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .offset(x: titleAppeared ? 0 : -50)
                        .opacity(titleAppeared ? 1 : 0)
                        .accessibilityAddTraits(.isHeader)

                    Text(page.subtitle)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(page.accentColor)
                        .multilineTextAlignment(.center)
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
            .padding(SpacingTokens.xxl)
            .pepinilloGlass(cornerRadius: GlassCornerRadius.hero)
            .readableContent(maxWidth: 672)
            .padding(.horizontal, SpacingTokens.xl)
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
                withAnimation(MotionTokens.heroEntrance.delay(0.1)) {
                    emojiAppeared = true
                }
                withAnimation(MotionTokens.heroEntrance.delay(0.3)) {
                    titleAppeared = true
                }
                withAnimation(MotionTokens.heroEntrance.delay(0.5)) {
                    descAppeared = true
                }

                // Floating emoji effect — Reduce Motion safe
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
            HStack(spacing: SpacingTokens.md) {
                ZStack {
                    Circle()
                        .fill(isSelected ? modeColor : modeColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Text(mode.icon)
                        .font(.title)
                }

                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text(mode.displayName)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        Text(modeTagline)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if modeIsProOnly {
                            ProPillBadge(color: modeColor)
                        }
                    }
                }

                Spacer()

                // Selection indicator: filled accent circle with checkmark when selected;
                // accent-tinted border when unselected (satisfies WCAG 1.4.11 non-text contrast)
                ZStack {
                    Circle()
                        .strokeBorder(modeColor.opacity(isSelected ? 0 : 0.7), lineWidth: isSelected ? 0 : 2)
                        .background(Circle().fill(isSelected ? modeColor : Color.clear))
                        .frame(width: 28, height: 28)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.md)
            .padding(.vertical, SpacingTokens.md)
            .pepinilloGlass()
            .overlay(
                RoundedRectangle(cornerRadius: GlassCornerRadius.card, style: .continuous)
                    .stroke(isSelected ? modeColor : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: GlassCornerRadius.card, style: .continuous))
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            .accessibilityLabel("\(mode.displayName), \(modeTagline)")
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : MotionTokens.bouncy, value: isSelected)
    }

    private var modeColor: Color {
        theme.color(for: mode)
    }

    private var modeIsProOnly: Bool {
        !mode.isFreeTier
    }

    private var modeTagline: String {
        switch mode {
        case .pomodoro:  return String(localized: "Classic 25/5 cycles")
        case .flowtime:  return String(localized: "Follow your natural flow")
        case .timeBlock: return String(localized: "Commit to a fixed block")
        case .stopwatch: return String(localized: "Zero pressure tracking")
        }
    }
}

// MARK: - PRO Pill Badge

struct ProPillBadge: View {
    var color: Color = .accentColor

    var body: some View {
        Text("PRO")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
