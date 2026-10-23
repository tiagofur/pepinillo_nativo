// MacActivitySampler.swift
// Pepinillo — native macOS top-activity capture
//
// Samples the frontmost application once per second while a focus session
// runs (opt-in, Settings → Usage statistics) and flushes a per-day rollup to
// `AppActivityUsageStore` when the session ends. Only bundle IDs, display
// names, and seconds are captured — never window titles — and the rollup
// never leaves this Mac.
//
// The accumulation and rollup logic lives in `AppActivityAccumulator` /
// `AppActivityUsageStore` (Shared) so it can be tested without AppKit.

import AppKit
import ComposableArchitecture

@MainActor
final class MacActivitySampler {
    private var store: StoreOf<AppFeature>?
    private var accumulator = AppActivityAccumulator()
    private var usageStore: AppActivityUsageStore?
    private var timer: Timer?
    private var lockObservers: [NSObjectProtocol] = []
    private var wasSessionActive = false
    private var isScreenLocked = false

    /// Raw UserDefaults read each tick so the Settings toggle applies with no
    /// observation wiring (same key `MacPreferences` writes).
    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: MacAppStorageKeys.topActivityEnabled)
    }

    func install(store: StoreOf<AppFeature>) {
        self.store = store
        usageStore = AppActivityUsageStore()
        wasSessionActive = false

        let sampler = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        sampler.tolerance = 0.25
        RunLoop.main.add(sampler, forMode: .common)
        timer = sampler

        // A locked screen must not credit the frontmost app for absent time.
        let center = DistributedNotificationCenter.default()
        lockObservers = [
            center.addObserver(
                forName: .init("com.apple.screenIsLocked"), object: nil, queue: nil
            ) { [weak self] _ in
                Task { @MainActor in self?.screenLockChanged(true) }
            },
            center.addObserver(
                forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: nil
            ) { [weak self] _ in
                Task { @MainActor in self?.screenLockChanged(false) }
            },
        ]
    }

    private func tick() {
        guard let store else { return }
        let sessionActive = store.withState { state in
            state.focus.isRunning && !state.focus.isPaused
        }

        if sessionActive, isEnabled, !isScreenLocked,
           let front = NSWorkspace.shared.frontmostApplication,
           let bundleID = front.bundleIdentifier {
            accumulator.record(
                bundleID: bundleID,
                name: front.localizedName ?? bundleID,
                at: Date.now
            )
        } else {
            // Disabled, paused, locked, or no frontmost app: drop the open
            // interval so nothing stretches across the gap.
            accumulator.closeInterval()
        }

        if wasSessionActive, !sessionActive {
            flush()
        }
        wasSessionActive = sessionActive
    }

    private func screenLockChanged(_ locked: Bool) {
        isScreenLocked = locked
        accumulator.closeInterval()
    }

    private func flush() {
        let usage = accumulator.takeUsage()
        guard !usage.isEmpty else { return }
        usageStore?.merge(usage, on: .now)
    }
}
