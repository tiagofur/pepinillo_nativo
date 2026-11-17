// MacFocusRingTouch.swift
// Pepinillo — direct-touch gestures on the Mac focus ring (issue #797)
//
// Touch on Mac (macOS 27+, guide R3): the ring answers a finger without
// growing any chrome. At rest on a configurable-duration mode it is a rotary
// dial (turn the ring like a kitchen timer, 5 min detents — Time Block
// 5…480, Pomodoro 5…120, issue #848); during a session a tap inside it
// pauses/resumes. Both gestures are restricted to `.directTouch`, so
// mouse and trackpad behave exactly as before, and on macOS 15–26 this
// modifier is a no-op. Every gesture has a non-gesture twin: the ±5
// steppers and the primary button.

import SwiftUI
import ComposableArchitecture

struct MacFocusRingTouch: ViewModifier {
    let store: StoreOf<FocusFeature>
    let ringSize: CGFloat

    func body(content: Content) -> some View {
        if #available(macOS 27.0, *) {
            content.overlay {
                DirectTouchRingOverlay(store: store, ringSize: ringSize)
            }
        } else {
            content
        }
    }
}

@available(macOS 27.0, *)
private struct DirectTouchRingOverlay: View {
    let store: StoreOf<FocusFeature>
    let ringSize: CGFloat

    /// Live dial turn: the duration when the finger landed, the last sampled
    /// angle and the rotation accumulated since (wrap-safe).
    private struct DialTurn {
        let baseMinutes: Int
        var lastAngle: Double
        var rotation: Double
    }

    /// What the dial is armed for right now: the clamped range, the base
    /// minutes it starts from and the reducer action each 5-minute detent
    /// crosses. Time Block overrides `customDurationMinutes`; Pomodoro
    /// overrides `config.pomodoroDuration` (issue #848). Both are in-memory
    /// next-session overrides — the next `configUpdated` hydration from
    /// Settings overwrites them by design.
    private struct DialTarget {
        let range: ClosedRange<Int>
        let baseMinutes: Int
        let sendDuration: (Int) -> Void
    }

    @State private var turn: DialTurn?

    private var size: CGSize { CGSize(width: ringSize, height: ringSize) }

    /// The dial lives exactly where the duration steppers do: a
    /// configurable-duration mode (Time Block, Pomodoro), idle, not waiting
    /// for the next phase.
    private var dialTarget: DialTarget? {
        guard !store.isRunning, !store.isWaitingForNextPhase else { return nil }
        switch store.selectedMode {
        case .timeBlock:
            return DialTarget(
                range: 5...480,
                baseMinutes: store.customDurationMinutes,
                sendDuration: { store.send(.customDurationChanged($0)) }
            )
        case .pomodoro:
            return DialTarget(
                range: 5...120,
                baseMinutes: Int((store.config.pomodoroDuration / 60).rounded()),
                sendDuration: { store.send(.pomodoroDurationChanged($0)) }
            )
        default:
            return nil
        }
    }

    var body: some View {
        Group {
            if let target = dialTarget {
                // Only the ring band is hit-testable, so a finger landing in
                // the interior still scrolls the stage.
                Color.clear
                    .contentShape(RingBandShape(), eoFill: true)
                    .gesture(dialGesture(target))
            } else if store.isRunning {
                Color.clear
                    .contentShape(Circle())
                    .gesture(tapGesture)
            }
        }
        .frame(width: ringSize, height: ringSize)
        // The ring's own accessibility element already describes the timer;
        // the gestures' twins (steppers, primary button) carry the actions.
        .accessibilityHidden(true)
    }

    private func dialGesture(_ target: DialTarget) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local, inputKinds: .directTouch)
            .onChanged { value in
                let angle = FocusRingDial.angle(at: value.location, in: size)
                guard var current = turn else {
                    guard FocusRingDial.isOnRingBand(value.startLocation, in: size) else { return }
                    turn = DialTurn(
                        baseMinutes: target.baseMinutes,
                        lastAngle: FocusRingDial.angle(at: value.startLocation, in: size),
                        rotation: 0
                    )
                    return
                }
                current.rotation += FocusRingDial.delta(from: current.lastAngle, to: angle)
                current.lastAngle = angle
                turn = current

                let minutes = FocusRingDial.minutes(
                    base: current.baseMinutes,
                    rotation: current.rotation,
                    range: target.range
                )
                // Only cross the reducer on a detent, never per touch sample.
                if minutes != current.baseMinutes {
                    target.sendDuration(minutes)
                }
            }
            .onEnded { _ in turn = nil }
    }

    private var tapGesture: some Gesture {
        SpatialTapGesture(coordinateSpace: .local, inputKinds: .directTouch)
            .onEnded { value in
                guard FocusRingDial.isInsideRing(value.location, in: size) else { return }
                FocusToggleCommand.toggle(focusStore: store)
            }
    }
}

/// The ring band as an even-odd annulus: outer circle minus the interior
/// (inner radius = 70% of the ring radius, matching `FocusRingDial`).
private struct RingBandShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: rect)
        path.addEllipse(in: rect.insetBy(dx: rect.width * 0.15, dy: rect.height * 0.15))
        return path
    }
}
