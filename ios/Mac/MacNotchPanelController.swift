// MacNotchPanelController.swift
// Pepinillo — Dynamic-Island-style notch notification
//
// The notch stays untouched while a session runs (the menu bar item carries
// the countdown). When a phase completes and the engine holds for the next
// one, a compact pill materializes directly UNDER the notch gap — never over
// the camera housing (the system's notch cover always wins there). Clicking
// the pill expands it downward into a Liquid Glass panel with the phase
// options, mirroring the tray popover's model. Acting on any option ends the
// hold and the island dissolves back into the notch.

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
    private let gap: CGRect

    /// Tallest the island can grow; the panel is pre-sized so the expansion
    /// never re-anchors the window.
    private static let expandedHeight: CGFloat = 240

    private init(gap: CGRect) {
        self.gap = gap
        let frame = CGRect(
            x: gap.minX,
            y: gap.minY - Self.expandedHeight,
            width: gap.width,
            height: Self.expandedHeight
        )
        panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [
            .canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle
        ]
        panel.setFrame(frame, display: false)
    }

    func install(store: StoreOf<AppFeature>, pulse: MacPresencePulse) {
        panel.contentView = NSHostingView(rootView: MacNotchIslandView(
            store: store,
            pulse: pulse,
            notchWidth: gap.width
        ))

        cancellable = pulse.$pulse
            .receive(on: RunLoop.main)
            .sink { [weak self] pulse in
                // Visible exactly while the engine holds for the next phase —
                // the "timer finished" moment. Every action that advances the
                // hold flips this flag and the island dissolves on its own.
                self?.setVisible(pulse.isWaitingForNextPhase)
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

// MARK: - Island content

private struct MacNotchIslandView: View {
    let store: StoreOf<AppFeature>
    @ObservedObject var pulse: MacPresencePulse
    let notchWidth: CGFloat

    @State private var expanded = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var focus: FocusFeature.State { store.focus }
    private var p: MacSessionPulse { pulse.pulse }

    /// The phase waiting behind the hold ("Short Break", "Focus 2/4", …).
    private var pending: FocusPhase? { focus.pendingNextPhase }

    var body: some View {
        VStack(spacing: 0) {
            if expanded {
                expandedPanel
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.9, anchor: .top)),
                        removal: .opacity
                    ))
            } else {
                collapsedPill
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Reset when the hold ends (an action ran elsewhere: notch, tray,
        // hotkey — every path must collapse the island).
        .onChange(of: p.isWaitingForNextPhase) { _, waiting in
            if !waiting { expanded = false }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: expanded)
    }

    // MARK: Collapsed — the notification itself

    private var collapsedPill: some View {
        Button {
            expanded = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: p.modeIcon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Text(pending?.displayName ?? String(localized: "Next phase"))
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)

                Text(p.displayTime)
                    .font(.system(size: 11, design: .rounded).monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .frame(maxWidth: notchWidth)
            .islandBackground(cornerRadius: 14, tint: .accentColor, interactive: false)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(String(localized: "Show phase options"))
        .accessibilityLabel(String(localized: "Phase complete. Show options."))
    }

    // MARK: Expanded — the options panel

    private var expandedPanel: some View {
        VStack(spacing: 12) {
            // Header: what finished, what's next.
            HStack(spacing: 6) {
                Image(systemName: p.modeIcon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(pending?.displayName ?? String(localized: "Next phase"))
                    .font(.headline)
                Spacer(minLength: 0)
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { expanded = false }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(String(localized: "Collapse"))
                .accessibilityLabel(String(localized: "Collapse"))
            }

            // The pending phase's countdown, seeded by the engine hold.
            Text(p.displayTime)
                .font(.system(size: 34, weight: .medium, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            // Primary: start whatever is pending.
            Button {
                store.send(.focus(.startNextPhaseTapped))
            } label: {
                Label(
                    String(localized: "focus.notch.startnext", defaultValue: "Start"),
                    systemImage: "play.fill"
                )
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 30)
            }
            .buttonStyle(.plain)
            .islandBackground(cornerRadius: 15, tint: .accentColor, interactive: true)
            .accessibilityLabel(String(localized: "Start next phase"))

            HStack(spacing: 8) {
                // "+5 min" only after a work phase (the engine guard matches).
                if pending?.isBreak == true {
                    islandButton(
                        String(localized: "+5 min"),
                        systemImage: "plus",
                        isDestructive: false
                    ) {
                        store.send(.focus(.extendSessionTapped))
                    }
                }

                islandButton(
                    String(localized: "focus.endsession.button", defaultValue: "End Session"),
                    systemImage: "stop.fill",
                    isDestructive: true
                ) {
                    MacSessionCommand.stop(store: store)
                }
            }
        }
        .padding(14)
        .frame(width: notchWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .islandBackground(cornerRadius: 22, tint: .accentColor, interactive: false)
    }

    private func islandButton(
        _ title: String,
        systemImage: String,
        isDestructive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isDestructive ? Color.red : Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .islandBackground(cornerRadius: 13, tint: .accentColor, interactive: false)
        .accessibilityLabel(title)
    }
}

// MARK: - Island material

private extension View {
    /// System Liquid Glass on macOS 26+, tinted like the tray surfaces;
    /// ultraThinMaterial fallback on macOS 15. Opaque under reduceTransparency.
    @ViewBuilder
    func islandBackground(cornerRadius: CGFloat, tint: Color, interactive: Bool) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(
                .regular
                    .interactive(interactive)
                    .tint(tint.opacity(0.14)),
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            self.background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }
}
