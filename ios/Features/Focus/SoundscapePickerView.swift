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
                Text(soundscape.emoji)
                    .font(.title3)
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
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(soundscape.displayName)\(isSelected ? String(localized: ", selected") : "")\(isLocked ? String(localized: ", requires Pro") : "")")
    }
}

// MARK: - Preview

#Preview {
    SoundscapePickerView(
        currentSoundscape: .rain,
        isProUser: false,
        onSelect: { _ in },
        onNeedsPro: {}
    )
}
