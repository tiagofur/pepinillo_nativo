// MacQuickCaptureController.swift
// Pepinillo — global quick capture panel
//
// A Spotlight-style floating field on `⌃⌥T`: type a task from any app and
// press Return. The panel is a non-activating `NSPanel`, so capturing a
// thought never steals focus from the app the user was working in.

import AppKit
import ComposableArchitecture
import SwiftUI

extension Notification.Name {
    /// Posted when the capture panel becomes key; the field takes focus then,
    /// because SwiftUI focus requests made before the panel is key are lost.
    static let macQuickCaptureFocusField = Notification.Name("pepinillo.mac.quickCapture.focusField")
}

@MainActor
final class MacQuickCaptureController: NSObject, NSWindowDelegate {
    static private(set) var shared: MacQuickCaptureController?

    private var panel: QuickCapturePanel?
    private weak var store: StoreOf<AppFeature>?

    override init() {
        super.init()
        Self.shared = self
        NotificationCenter.default.addObserver(
            forName: .macQuickCaptureToggleRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.togglePanel()
            }
        }
    }

    // MARK: - Lifecycle

    /// Installs the panel content once the shared store exists. The panel
    /// itself is created lazily on first toggle so screen geometry is current.
    func install(store: StoreOf<AppFeature>) {
        self.store = store
    }

    func togglePanel() {
        if let panel, panel.isVisible {
            hide(panel)
        } else {
            showPanel()
        }
    }

    // MARK: - Panel

    private func showPanel() {
        let panel = self.panel ?? makePanel()
        self.panel = panel

        position(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: false)
    }

    private func makePanel() -> QuickCapturePanel {
        let panel = QuickCapturePanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 64),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.hidesOnDeactivate = false

        panel.contentViewController = NSHostingController(
            rootView: MacQuickCaptureView(
                onSubmit: { [weak self] title in
                    self?.submit(title: title)
                },
                onCancel: { [weak self] in
                    guard let panel = self?.panel else { return }
                    self?.hide(panel)
                }
            )
        )
        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelFrame = panel.frame
        let x = screenFrame.midX - panelFrame.width / 2
        let y = screenFrame.maxY - screenFrame.height * 0.22
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func hide(_ panel: NSPanel) {
        panel.orderOut(nil)
    }


    private func submit(title raw: String) {
        let title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let store else { return }
        store.send(.tabSelected(.plan))
        store.send(.tasks(.newTaskTitleChanged(String(title.prefix(200)))))
        store.send(.tasks(.addTaskTapped))
        if let panel {
            hide(panel)
        }
    }

    // MARK: - NSWindowDelegate

    /// Clicking anywhere outside the panel dismisses it, like Spotlight.
    func windowDidResignKey(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel, panel == self.panel else { return }
        hide(panel)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel, panel == self.panel else { return }
        NotificationCenter.default.post(name: .macQuickCaptureFocusField, object: nil)
        // The SwiftUI content mounts shortly after the panel becomes key; the
        // first focus request can land before the field exists in the window.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            NotificationCenter.default.post(name: .macQuickCaptureFocusField, object: nil)
        }
    }
}

/// Borderless panels are not key by default; the capture field needs key
/// focus to receive typing without activating the whole app.
private final class QuickCapturePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - View

private struct MacQuickCaptureView: View {
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @State private var text = ""
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            TextField(
                String(localized: "New task"),
                text: $text,
                prompt: Text(String(localized: "Add a task and press Return"))
            )
            .textFieldStyle(.plain)
            .font(.title3)
            .focused($isFieldFocused)
            .onSubmit { onSubmit(text) }
            .onExitCommand { onCancel() }

            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("⏎")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 64)
        .frame(width: 520)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.quaternary)
        }
        .onAppear { isFieldFocused = true }
        .onReceive(NotificationCenter.default.publisher(for: .macQuickCaptureFocusField)) { _ in
            isFieldFocused = true
        }
    }
}
