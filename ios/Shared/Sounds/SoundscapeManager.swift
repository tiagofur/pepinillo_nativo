// SoundscapeManager.swift
// Pepinillo — Deep Work Companion for Apple
//
// AVAudioEngine-based ambient audio manager.
// Loops a single ambient track with smooth fade in/out transitions.
// Runs on a dedicated actor to avoid data races.

import Foundation
import AVFoundation

// MARK: - SoundscapeManager Actor

actor SoundscapeManager {
    static let shared = SoundscapeManager()

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?

    nonisolated(unsafe) private(set) var currentSoundscape: Soundscape? = nil
    private var currentVolume: Float = 0.5

    private init() {}

    // MARK: - Playback

    func play(_ soundscape: Soundscape, volume: Float) async {
        guard soundscape != .none else {
            await stop()
            return
        }
        guard soundscape != currentSoundscape else {
            // Already playing this soundscape — just update volume
            await setVolume(volume)
            return
        }

        // Stop current first
        stopEngine()

        guard let fileName = soundscape.fileName,
              let url = Bundle.main.url(forResource: fileName, withExtension: "mp3")
               ?? Bundle.main.url(forResource: fileName, withExtension: "m4a") else {
            // File not found — graceful no-op
            return
        }

        do {
            try configureAudioSession()
            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()
            let file = try AVAudioFile(forReading: url)

            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode,
                           format: file.processingFormat)
            engine.mainMixerNode.outputVolume = 0

            try engine.start()
            scheduleLoop(player: player, file: file, engine: engine)

            player.play()

            self.audioEngine = engine
            self.playerNode = player
            self.audioFile  = file
            self.currentSoundscape = soundscape
            self.currentVolume = volume

            // Fade in
            await fadeVolume(from: 0, to: volume, duration: 1.5, engine: engine)
        } catch {
            stopEngine()
        }
    }

    func stop() async {
        await fadeOut()
        stopEngine()
        currentSoundscape = nil
    }

    func setVolume(_ volume: Float) async {
        currentVolume = volume
        if let engine = audioEngine {
            await fadeVolume(
                from: engine.mainMixerNode.outputVolume,
                to: volume,
                duration: 0.3,
                engine: engine
            )
        }
    }

    func fadeOut() async {
        guard let engine = audioEngine else { return }
        await fadeVolume(from: engine.mainMixerNode.outputVolume, to: 0, duration: 1.2, engine: engine)
    }

    // MARK: - Private Helpers

    private func stopEngine() {
        playerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        audioFile = nil
        currentSoundscape = nil
    }

    private func configureAudioSession() throws {
        #if os(macOS)
        return
        #else
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
        #endif
    }

    /// Schedule a buffer from the file to loop indefinitely.
    private func scheduleLoop(player: AVAudioPlayerNode,
                               file: AVAudioFile,
                               engine: AVAudioEngine) {
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else { return }

        do {
            try file.read(into: buffer)
            player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        } catch {
            // Read failed — no audio
        }
    }

    /// Smooth volume ramp using a short sleep-tick loop.
    private func fadeVolume(from start: Float,
                             to end: Float,
                             duration: TimeInterval,
                             engine: AVAudioEngine) async {
        let steps = 30
        let stepDuration = duration / Double(steps)
        for i in 0...steps {
            guard !Task.isCancelled else { break }
            let t = Float(i) / Float(steps)
            let volume = start + (end - start) * t
            engine.mainMixerNode.outputVolume = max(0, min(1, volume))
            try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
        }
    }
}
