// SoundscapeClient.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA dependency for ambient soundscapes during focus sessions.
// Free: Rain, Forest, Café, White Noise.
// Pro: Binaural Beats, Lo-fi, Ocean, Fireplace.

import Foundation
import ComposableArchitecture

// MARK: - Soundscape

enum Soundscape: String, CaseIterable, Equatable, Sendable, Identifiable {
    case none       = "none"
    case rain       = "rain"
    case forest     = "forest"
    case cafe       = "cafe"
    case whiteNoise = "white_noise"
    case ocean      = "ocean"
    case fireplace  = "fireplace"
    case binaural   = "binaural"
    case lofi       = "lofi"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:       return String(localized: "None")
        case .rain:       return String(localized: "Rain")
        case .forest:     return String(localized: "Forest")
        case .cafe:       return String(localized: "Café")
        case .whiteNoise: return String(localized: "White Noise")
        case .ocean:      return String(localized: "Ocean")
        case .fireplace:  return String(localized: "Fireplace")
        case .binaural:   return String(localized: "Binaural Beats")
        case .lofi:       return String(localized: "Lo-fi")
        }
    }

    var emoji: String {
        switch self {
        case .none:       return "🔇"
        case .rain:       return "🌧️"
        case .forest:     return "🌲"
        case .cafe:       return "☕"
        case .whiteNoise: return "📻"
        case .ocean:      return "🌊"
        case .fireplace:  return "🔥"
        case .binaural:   return "🎧"
        case .lofi:       return "🎵"
        }
    }

    var systemImage: String {
        switch self {
        case .none:       return "speaker.slash"
        case .rain:       return "cloud.rain"
        case .forest:     return "tree"
        case .cafe:       return "cup.and.saucer.fill"
        case .whiteNoise: return "waveform"
        case .ocean:      return "water.waves"
        case .fireplace:  return "flame"
        case .binaural:   return "headphones"
        case .lofi:       return "music.note"
        }
    }

    var requiresPro: Bool {
        switch self {
        case .binaural, .lofi, .ocean, .fireplace: return true
        default: return false
        }
    }

    var fileName: String? {
        switch self {
        case .none: return nil
        default: return rawValue  // e.g., "rain.mp3" in bundle
        }
    }
}

// MARK: - Soundscape Client

@DependencyClient
struct SoundscapeClient: Sendable {
    /// Start playing a soundscape (loops).
    var play: @Sendable (_ soundscape: Soundscape, _ volume: Float) async -> Void = { _, _ in }

    /// Stop the current soundscape.
    var stop: @Sendable () async -> Void = {}

    /// Adjust volume (0.0–1.0) without stopping.
    var setVolume: @Sendable (_ volume: Float) async -> Void = { _ in }

    /// Fade out and stop over a brief duration.
    var fadeOut: @Sendable () async -> Void = {}

    /// Current playing soundscape (nil if stopped).
    var currentSoundscape: @Sendable () -> Soundscape? = { nil }
}

// MARK: - Dependency Keys

extension SoundscapeClient: DependencyKey {
    static let liveValue = SoundscapeClient.live
    static let testValue = SoundscapeClient()
}

extension DependencyValues {
    var soundscapeClient: SoundscapeClient {
        get { self[SoundscapeClient.self] }
        set { self[SoundscapeClient.self] = newValue }
    }
}

// MARK: - Live Implementation

extension SoundscapeClient {
    static let live: SoundscapeClient = {
        let manager = SoundscapeManager.shared
        return SoundscapeClient(
            play: { soundscape, volume in
                await manager.play(soundscape, volume: volume)
            },
            stop: {
                await manager.stop()
            },
            setVolume: { volume in
                await manager.setVolume(volume)
            },
            fadeOut: {
                await manager.fadeOut()
            },
            currentSoundscape: {
                SoundscapeManager.shared.currentSoundscape
            }
        )
    }()
}
