// MacNotchPanelController.swift
// Pepinillo — Kofe-Flow-style notch presence
//
// A non-activating panel floating over the MacBook notch gap showing the
// live countdown and phase controls while a session runs. The gap between
// `auxiliaryTopLeftArea` and `auxiliaryTopRightArea` carries no system UI,
// so the pill never covers menu items. Screens without a notch install
// nothing (the menu bar status item already covers them).

import AppKit
import Combine
import ComposableArchitecture
import SwiftUI

@MainActor
final class MacNotchPanelController {
    /// Nil on machines/displays without a notch gap.
    static func create() -> MacNotchPanelController? {
        guard let gap = notchGapRect() else { return nil }
        return MacNotchPanelController(gap: gap)
    }

    private let panel: NSPanel
    private var cancellable: AnyCancellable?

    private init(gap: CGRect) {
        panel = NSPanel(
            contentRect: gap,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [
            .canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle
        ]
        panel.setFrame(gap, display: false)
    }

    func install(store: StoreOf<AppFeature>, pulse: MacPresencePulse) {
        panel.contentView = NSHostingView(rootView: MacNotchPillView(
            pulse: pulse,
            onToggle: { FocusToggleCommand.toggle(store: store) },
            onNextPhase: { MacSessionCommand.nextPhase(store: store) },
            onStop: { MacSessionCommand.stop(store: store) }
        ))

        cancellable = pulse.$pulse
            .receive(on: RunLoop.main)
            .sink { [weak self] pulse in
                self?.setVisible(pulse.isRunning)
            }
    }

    private func setVisible(_ visible: Bool) {
        guard visible != panel.isVisible else { return }
        if visible {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    /// The horizontal gap between the auxiliary (notch-side) areas of the
    /// first screen that has one — the camera-housing dead zone.
    private static func notchGapRect() -> CGRect? {
        for screen in NSScreen.screens {
            guard
                let left = screen.auxiliaryTopLeftArea,
                let right = screen.auxiliaryTopRightArea
            else { continue }
            let gap = CGRect(
                x: left.maxX,
                y: left.minY,
                width: right.minX - left.maxX,
                height: left.height
            )
            // Real notches are ~160-220pt wide; filter degenerate frames.
            guard gap.width >= 120, gap.height >= 20 else { continue }
            return gap
        }
        return nil
    }
}

// MARK: - Pill content

private struct MacNotchPillView: View {
    @ObservedObject var pulse: MacPresencePulse
    let onToggle: () -> Void
    let onNextPhase: () -> Void
    let onStop: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var p: MacSessionPulse { pulse.pulse }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: p.modeIcon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(p.displayTime)
                .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)

            controlsDivider()

            controlButton(
                p.isWaitingForNextPhase || p.isPaused ? "play.fill" : "pause.fill",
                label: p.isWaitingForNextPhase
                    ? String(localized: "Start next phase")
                    : (p.isPaused ? String(localized: "Resume") : String(localized: "Pause")),
                action: p.isWaitingForNextPhase ? onNextPhase : onToggle
            )

            if !p.isWaitingForNextPhase {
                controlButton("forward.end.fill", label: String(localized: "Skip phase"), action: onNextPhase)
                controlsDivider()
                controlButton("stop.fill", label: String(localized: "End session"), action: onStop, destructive: true)
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(reduceTransparency ? Color.black : Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func controlsDivider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.18))
            .frame(width: 1, height: 12)
            .accessibilityHidden(true)
    }

    private func controlButton(
        _ symbol: String,
        label: String,
        action: @escaping () -> Void,
        destructive: Bool = false
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(destructive ? Color.red.opacity(0.9) : Color.primary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}
