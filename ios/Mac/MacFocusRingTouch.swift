// MacFocusRingTouch.swift
// Pepinillo — direct-touch gestures on the Mac focus ring (issue #797)
//
// Touch on Mac (macOS 27+, guide R3): the ring answers a finger without
// growing any chrome. At rest on Time Block it is a rotary dial (turn the
// ring like a kitchen timer, 5 min detents); during a session a tap inside
// it pauses/resumes. Both gestures are restricted to `.directTouch`, so
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

    /// Same bounds as the ±5 steppers and `FocusFeature.customDurationChanged`.
    private static let timeBlockRange = 5...480

    @State private var turn: DialTurn?

    private var size: CGSize { CGSize(width: ringSize, height: ringSize) }

    /// The dial lives exactly where the duration steppers do: Time Block,
    /// idle, not waiting for the next phase.
    private var isDialEnabled: Bool {
        store.selectedMode == .timeBlock && !store.isRunning && !store.isWaitingForNextPhase
    }

    var body: some View {
        Group {
            if isDialEnabled {
                // Only the ring band is hit-testable, so a finger landing in
                // the interior still scrolls the stage.
                Color.clear
                    .contentShape(RingBandShape(), eoFill: true)
                    .gesture(dialGesture)
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

    private var dialGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local, inputKinds: .directTouch)
            .onChanged { value in
                let angle = FocusRingDial.angle(at: value.location, in: size)
                guard var current = turn else {
                    guard FocusRingDial.isOnRingBand(value.startLocation, in: size) else { return }
                    turn = DialTurn(
                        baseMinutes: store.customDurationMinutes,
                        lastAngle: FocusRingDial.angle(at: value.startLocation, in: size),
                        rotation: 0
                    )
                    return
                }
                current.rotation += FocusRingDial.delta(from: current.lastAngle, to: angle)
                current.lastAngle = angle
                turn = current

                let target = FocusRingDial.minutes(
                    base: current.baseMinutes,
                    rotation: current.rotation,
                    range: Self.timeBlockRange
                )
                // Only cross the reducer on a detent, never per touch sample.
                if target != store.customDurationMinutes {
                    store.send(.customDurationChanged(target))
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
