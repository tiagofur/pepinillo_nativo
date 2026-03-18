// CelebrationView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Full-screen celebration overlay displayed when a streak milestone is reached.
// Uses Canvas + TimelineView for particle confetti — no external dependencies.

import SwiftUI

// MARK: - Celebration Milestone

enum CelebrationMilestone: Equatable {
    case streakDay(Int)          // e.g. 3, 7, 14, 30
    case sessionCount(Int)       // e.g. 10, 50, 100
    case firstSession
    case personalBest(Int)       // minutes

    var emoji: String {
        switch self {
        case .streakDay(let d) where d >= 30: return "🏆"
        case .streakDay(let d) where d >= 14: return "🔥"
        case .streakDay:                       return "⚡"
        case .sessionCount(let n) where n >= 100: return "💎"
        case .sessionCount(let n) where n >= 50:  return "🌟"
        case .sessionCount:                        return "✨"
        case .firstSession:                        return "🎯"
        case .personalBest:                        return "🚀"
        }
    }

    var title: String {
        switch self {
        case .streakDay(let d):      return String(localized: "\(d)-Day Streak!")
        case .sessionCount(let n):   return String(localized: "\(n) Sessions!")
        case .firstSession:          return String(localized: "First Session!")
        case .personalBest(let m):   return String(localized: "Personal Best: \(m)m")
        }
    }

    var subtitle: String {
        switch self {
        case .streakDay(let d) where d >= 30:
            return String(localized: "A full month of deep work. You're unstoppable.")
        case .streakDay(let d) where d >= 14:
            return String(localized: "Two weeks strong. Your focus muscle is growing.")
        case .streakDay(let d) where d >= 7:
            return String(localized: "A full week! Consistency is your superpower.")
        case .streakDay:
            return String(localized: "Keep the momentum going!")
        case .sessionCount(let n) where n >= 100:
            return String(localized: "100 sessions — you're a deep work master.")
        case .sessionCount(let n) where n >= 50:
            return String(localized: "\(n) sessions. Half a century of focus!")
        case .sessionCount:
            return String(localized: "Every session counts. Keep stacking them.")
        case .firstSession:
            return String(localized: "The hardest part is starting. You did it!")
        case .personalBest(let m):
            return String(localized: "\(m) minutes of uninterrupted focus. Impressive!")
        }
    }
}

// MARK: - CelebrationView

struct CelebrationView: View {
    let milestone: CelebrationMilestone
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showContent = false
    @State private var particles: [ConfettiParticle] = []
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimming backdrop
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture { onDismiss() }

                // Confetti canvas
                if !reduceMotion {
                    TimelineView(.animation) { timeline in
                        Canvas { context, size in
                        let now = timeline.date.timeIntervalSinceReferenceDate
                        for particle in particles {
                            let elapsed = now - particle.birthDate
                            let t = elapsed / particle.lifetime
                            guard t < 1 else { continue }

                            let x = particle.startX + particle.velocityX * elapsed
                            let y = particle.startY + particle.velocityY * elapsed
                                  + 0.5 * 200 * elapsed * elapsed

                            let opacity = t < 0.8 ? 1.0 : (1.0 - t) / 0.2

                            context.opacity = opacity
                            context.fill(
                                Path(ellipseIn: CGRect(
                                    x: x - particle.size / 2,
                                    y: y - particle.size / 2,
                                    width: particle.size,
                                    height: particle.size * 0.6
                                )),
                                with: .color(particle.color)
                            )
                        }
                    }
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)
                }

            // Milestone card
            VStack(spacing: 16) {
                Text(milestone.emoji)
                    .font(.system(size: 64))
                    .scaleEffect(showContent ? 1 : 0.3)
                    .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6), value: showContent)

                Text(milestone.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.4).delay(0.15), value: showContent)

                Text(milestone.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.4).delay(0.25), value: showContent)

                Button {
                    onDismiss()
                } label: {
                    Text(String(localized: "Keep Going!"))
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(.white, in: Capsule())
                        .foregroundStyle(.black)
                }
                .opacity(showContent ? 1 : 0)
                .scaleEffect(showContent ? 1 : 0.8)
                .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7).delay(0.35), value: showContent)
                }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(milestone.title). \(milestone.subtitle)")
            }
            .onAppear {
                showContent = true
                HapticManager.notification(.success)
                if !reduceMotion {
                    spawnParticles(screenWidth: geometry.size.width)
                }
            }
        }
    }

    // MARK: - Particle Spawning

    private func spawnParticles(screenWidth: CGFloat) {
        let count = 80
        let now = Date.timeIntervalSinceReferenceDate
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]

        particles = (0..<count).map { _ in
            ConfettiParticle(
                startX: CGFloat.random(in: 0...screenWidth),
                startY: CGFloat.random(in: -20...100),
                velocityX: CGFloat.random(in: -80...80),
                velocityY: CGFloat.random(in: -200...(-60)),
                size: CGFloat.random(in: 6...14),
                color: colors.randomElement()!,
                lifetime: Double.random(in: 1.5...3.0),
                birthDate: now
            )
        }
    }
}

// MARK: - ConfettiParticle

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let startX: CGFloat
    let startY: CGFloat
    let velocityX: CGFloat
    let velocityY: CGFloat
    let size: CGFloat
    let color: Color
    let lifetime: Double
    let birthDate: Double
}

// MARK: - Preview

#Preview {
    CelebrationView(milestone: .streakDay(7)) {}
}
