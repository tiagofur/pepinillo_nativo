// SoundscapePickerView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Bottom sheet for selecting ambient soundscapes during a focus session.
// Free tiers show a lock icon; tapping a Pro soundscape shows the paywall.

import SwiftUI
import ComposableArchitecture

// MARK: - SoundscapePickerView

struct SoundscapePickerView: View {
    let currentSoundscape: Soundscape
    let isProUser: Bool
    let onSelect: (Soundscape) -> Void
    let onNeedsPro: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var previewingSoundscape: Soundscape?
    @State private var previewTask: Task<Void, Never>?
    @State private var soundscapeWasSelected = false

    // Group soundscapes
    private let free: [Soundscape] = [.none, .rain, .forest, .cafe, .whiteNoise]
    private let pro:  [Soundscape] = [.ocean, .fireplace, .binaural, .lofi]

    var body: some View {
        NavigationStack {
            List {
                Section(String(localized: "Free")) {
                    ForEach(free) { soundscape in
                        SoundscapeRow(
                            soundscape: soundscape,
                            isSelected: currentSoundscape == soundscape,
                            isPreviewing: previewingSoundscape == soundscape,
                            isLocked: false,
                            onTap: {
                                HapticManager.selection()
                                soundscapeWasSelected = true
                                onSelect(soundscape)
                                dismiss()
                            },
                            onPreview: soundscape == .none ? nil : {
                                togglePreview(soundscape)
                            }
                        )
                    }
                }

                Section {
                    ForEach(pro) { soundscape in
                        SoundscapeRow(
                            soundscape: soundscape,
                            isSelected: currentSoundscape == soundscape,
                            isPreviewing: previewingSoundscape == soundscape,
                            isLocked: !isProUser,
                            onTap: {
                                HapticManager.selection()
                                soundscapeWasSelected = true
                                if isProUser {
                                    onSelect(soundscape)
                                    dismiss()
                                } else {
                                    onNeedsPro()
                                    dismiss()
                                }
                            },
                            onPreview: isProUser ? {
                                togglePreview(soundscape)
                            } : nil
                        )
                    }
                } header: {
                    HStack(spacing: 4) {
                        Text(String(localized: "Pro"))
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                    }
                    .accessibilityLabel(String(localized: "Pro soundscapes, subscription required"))
                }
            }
            #if os(macOS)
            .listStyle(.inset)
            #else
            .listStyle(.insetGrouped)
            #endif
            .navigationTitle(String(localized: "Soundscape"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
            .onDisappear {
                previewTask?.cancel()
                previewTask = nil
                previewingSoundscape = nil
                if !soundscapeWasSelected {
                    // Dismissed without selecting — stop preview audio
                    Task { await SoundscapeManager.shared.stop() }
                }
                // When soundscapeWasSelected, TCA's .soundscapeSelected effect will
                // call soundscapeClient.play() if the session is running, which stops
                // the preview internally. If not running, we leave audio silent until Start.
            }
        }
    }

    private func togglePreview(_ soundscape: Soundscape) {
        HapticManager.impact(.light)
        if previewingSoundscape == soundscape {
            stopPreview()
        } else {
            previewingSoundscape = soundscape
            previewTask = Task {
                await SoundscapeManager.shared.play(soundscape, volume: 0.5)
                try? await Task.sleep(for: .seconds(3))
                // Guard against cancellation to avoid fading out a soundscape
                // that was already started by the session after task cancellation.
                guard !Task.isCancelled else { return }
                if previewingSoundscape == soundscape {
                    await SoundscapeManager.shared.fadeOut()
                    await MainActor.run { previewingSoundscape = nil }
                }
            }
        }
    }

    private func stopPreview() {
        previewTask?.cancel()
        previewTask = nil
        previewingSoundscape = nil
        Task { await SoundscapeManager.shared.stop() }
    }
}

// MARK: - SoundscapeRow

private struct SoundscapeRow: View {
    let soundscape: Soundscape
    let isSelected: Bool
    let isPreviewing: Bool
    let isLocked: Bool
    let onTap: () -> Void
    let onPreview: (() -> Void)?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: soundscape.systemImage)
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isLocked ? .secondary : .primary)
                    .frame(width: 32)

                Text(soundscape.displayName)
                    .foregroundStyle(isLocked ? .secondary : .primary)

                Spacer()

                if let onPreview {
                    Button {
                        onPreview()
                    } label: {
                        Image(systemName: isPreviewing ? "speaker.wave.2.fill" : "play.circle")
                            .font(.body)
                            .foregroundStyle(isPreviewing ? Color.accentColor : .secondary)
                            #if os(macOS)
                            .macTouchTarget()
                            #endif
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isPreviewing ? String(localized: "Stop preview") : String(localized: "Preview \(soundscape.displayName)"))
                }

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            #if os(macOS)
            // Touch on Mac (guide R2): 36 pt rows, whole row tappable.
            .frame(minHeight: TouchTargets.macMinimum)
            .contentShape(Rectangle())
            #endif
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(soundscape.displayName)\(isSelected ? String(localized: ", selected") : "")\(isLocked ? String(localized: ", requires Pro") : "")")
    }
}

// MARK: - Mac popover (issue #798)

#if os(macOS)
import AppKit

/// Soundscapes popover for the Mac focus stage: volume first, then the same
/// free / Pro list as the iOS sheet. Unlike the sheet it stays open on
/// selection, so on a touch Mac one finger can ride the volume while another
/// tries ambiences — the container opts out of exclusive gestures for that.
struct MacSoundscapePopover: View {
    let currentSoundscape: Soundscape
    let volume: Float
    let isProUser: Bool
    let onSelect: (Soundscape) -> Void
    let onVolumeChange: (Float) -> Void
    let onNeedsPro: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var previewingSoundscape: Soundscape?
    @State private var previewTask: Task<Void, Never>?

    private let free: [Soundscape] = [.none, .rain, .forest, .cafe, .whiteNoise]
    private let pro: [Soundscape] = [.ocean, .fireplace, .binaural, .lofi]

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { Double(volume) },
            set: { newValue in
                onVolumeChange(Float(newValue))
                // A running preview follows the slider; session audio is
                // driven by the reducer.
                if previewingSoundscape != nil {
                    Task { await SoundscapeManager.shared.setVolume(Float(newValue)) }
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Soundscape"))
                .font(.headline)

            Slider(value: volumeBinding, in: 0...1) {
                Text(String(localized: "Volume"))
            } minimumValueLabel: {
                Image(systemName: "speaker.fill").foregroundStyle(.secondary)
            } maximumValueLabel: {
                Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
            }
            .labelsHidden()
            .frame(minHeight: TouchTargets.macMinimum)
            .disabled(currentSoundscape == .none && previewingSoundscape == nil)
            .accessibilityLabel(String(localized: "Volume"))

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                ForEach(free) { soundscape in
                    row(soundscape, isLocked: false)
                }

                HStack(spacing: 4) {
                    Text(String(localized: "Pro"))
                    Image(systemName: "lock.fill").font(.caption2)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
                .padding(.bottom, 2)
                .accessibilityLabel(String(localized: "Pro soundscapes, subscription required"))

                ForEach(pro) { soundscape in
                    row(soundscape, isLocked: !isProUser)
                }
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(NonExclusiveGestureContainer())
        .onDisappear {
            previewTask?.cancel()
            previewTask = nil
            if previewingSoundscape != nil {
                previewingSoundscape = nil
                Task { await SoundscapeManager.shared.stop() }
            }
        }
    }

    private func row(_ soundscape: Soundscape, isLocked: Bool) -> some View {
        SoundscapeRow(
            soundscape: soundscape,
            isSelected: currentSoundscape == soundscape,
            isPreviewing: previewingSoundscape == soundscape,
            isLocked: isLocked,
            onTap: {
                if isLocked {
                    onNeedsPro()
                    dismiss()
                } else {
                    stopPreview()
                    onSelect(soundscape)
                }
            },
            onPreview: (soundscape == .none || isLocked) ? nil : { togglePreview(soundscape) }
        )
    }

    private func togglePreview(_ soundscape: Soundscape) {
        if previewingSoundscape == soundscape {
            stopPreview()
            return
        }
        previewTask?.cancel()
        previewingSoundscape = soundscape
        let level = volume
        previewTask = Task {
            await SoundscapeManager.shared.play(soundscape, volume: level)
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await SoundscapeManager.shared.fadeOut()
            previewingSoundscape = nil
        }
    }

    private func stopPreview() {
        guard previewingSoundscape != nil else { return }
        previewTask?.cancel()
        previewTask = nil
        previewingSoundscape = nil
        Task { await SoundscapeManager.shared.stop() }
    }
}

/// Opts the popover's window content out of exclusive gestures on touch
/// Macs (macOS 27+), so the slider and the rows can be operated at once.
/// A no-op on earlier releases.
private struct NonExclusiveGestureContainer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ProbeView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ProbeView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if #available(macOS 27.0, *) {
                window?.contentView?.exclusiveGestureBehavior = .notExclusive
            }
        }
    }
}
#endif

// MARK: - Preview

#Preview {
    SoundscapePickerView(
        currentSoundscape: .rain,
        isProUser: false,
        onSelect: { _ in },
        onNeedsPro: {}
    )
}
