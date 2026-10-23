// CompletionSound.swift
// Pepinillo — phase-complete cue sounds
//
// `classic` is the system beep Pepinillo always played; the rest are short
// bundled clips (Shared/Sounds/completion-*.caf) played through Audio
// Services, the same no-AVAudioSession path, so they behave identically on
// iOS and macOS. The choice is device-local (standard defaults) — it is
// audio taste, not product state, so the preferences schema stays untouched.
// watchOS has no Audio Services: the whole type is compiled out there.

#if !os(watchOS)
import AudioToolbox
import Foundation

@MainActor
enum CompletionSound: String, CaseIterable, Codable, Sendable {
    case classic
    case chime
    case bell
    case digital
    case woodblock

    static let defaultsKey = "completionSound"

    /// Device-local choice; falls back to the classic beep.
    static var current: CompletionSound {
        CompletionSound(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .classic
    }

    var displayName: String {
        switch self {
        case .classic: String(localized: "Classic")
        case .chime: String(localized: "Chime")
        case .bell: String(localized: "Bell")
        case .digital: String(localized: "Digital")
        case .woodblock: String(localized: "Woodblock")
        }
    }

    private static var cachedSoundIDs: [CompletionSound: SystemSoundID] = [:]

    func play() {
        switch self {
        case .classic:
            AudioServicesPlaySystemSound(1007)
        default:
            guard let soundID = Self.soundID(for: self) else { return }
            AudioServicesPlaySystemSound(soundID)
        }
    }

    private static func soundID(for sound: CompletionSound) -> SystemSoundID? {
        if let cached = cachedSoundIDs[sound] { return cached }
        guard let url = Bundle.main.url(
            forResource: "completion-\(sound.rawValue)",
            withExtension: "caf"
        ) else { return nil }
        var soundID: SystemSoundID = 0
        guard AudioServicesCreateSystemSoundID(url as CFURL, &soundID) == noErr else { return nil }
        cachedSoundIDs[sound] = soundID
        return soundID
    }
}
#endif
