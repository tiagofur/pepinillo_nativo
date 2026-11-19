// ShareViewController.swift
// Pepinillo — Deep Work Companion for Apple
//
// iOS Share Extension (#669): capture plain text or a URL from any app into
// a Pepinillo task. The extension stays deliberately light — one file, no
// model stack: it hands the title to the app through the app-group
// UserDefaults queue (the same external-command channel widgets and Control
// Center use) and lets the app create the task through its quick-add
// pipeline on activation.
// Localized: EN, ES, PT.

import CoreFoundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Constants
//
// Mirrors AppGroup.id / AppGroupDefaults.externalCapturedTaskTitleKey from
// the app target on purpose: compiling the model stack into a share
// extension would defeat the point of keeping it light. Keep in sync.

enum ShareCaptureConstants {
    static let appGroupID = "group.com.pepinillo.app"
    static let capturedTaskTitleKey = "externalCapturedTaskTitle"
    static let darwinSignalName = "com.pepinillo.app.externalCommand"
}

// MARK: - ShareViewController

@MainActor
final class ShareViewController: UIViewController {

    private var capturedText: String = ""
    private var hostingController: UIHostingController<ShareCaptureView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        installView(with: "")
        resolveSharedContent()
    }

    // MARK: Content resolution

    private func resolveSharedContent() {
        let attachments = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }

        // Selected text wins over the page URL (A4): sharing highlighted
        // text from Safari carries both, and the words are the task.
        if let textProvider = attachments.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.text.identifier)
        }) {
            textProvider.loadItem(forTypeIdentifier: UTType.text.identifier) { [weak self] item, _ in
                let text = (item as? String) ?? (item as? NSURL)?.absoluteString ?? ""
                Task { @MainActor in self?.adoptCaptured(text) }
            }
            return
        }

        if let urlProvider = attachments.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
        }) {
            urlProvider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] item, _ in
                let text = (item as? URL)?.absoluteString ?? (item as? NSURL)?.absoluteString ?? ""
                Task { @MainActor in self?.adoptCaptured(text) }
            }
            return
        }

        adoptCaptured("")
    }

    private func adoptCaptured(_ text: String) {
        capturedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        installView(with: capturedText)
    }

    // MARK: UI

    private func installView(with prefill: String) {
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()

        let view = ShareCaptureView(
            initialTitle: prefill,
            onSave: { [weak self] title in self?.save(title) },
            onCancel: { [weak self] in self?.cancel() }
        )
        let controller = UIHostingController(rootView: view)
        controller.view.backgroundColor = .clear
        addChild(controller)
        controller.view.frame = self.view.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(controller.view)
        controller.didMove(toParent: self)
        hostingController = controller
    }

    // MARK: Actions

    private func save(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            cancel()
            return
        }
        if let defaults = UserDefaults(suiteName: ShareCaptureConstants.appGroupID) {
            defaults.set(trimmed, forKey: ShareCaptureConstants.capturedTaskTitleKey)
        }
        // Wake the running app so it drains immediately; a cold app drains on
        // activation regardless (the Darwin signal is best-effort here).
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(ShareCaptureConstants.darwinSignalName as CFString),
            nil, nil, true
        )
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func cancel() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}

// MARK: - ShareCaptureView

private struct ShareCaptureView: View {
    let initialTitle: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var title: String
    @FocusState private var isFieldFocused: Bool

    init(initialTitle: String, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.initialTitle = initialTitle
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: initialTitle)
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text("New task")
                    .font(.headline)
                Spacer()
                Button(role: .cancel) {
                    onCancel()
                } label: {
                    Text("Cancel")
                }
            }

            TextField(
                String(localized: "New task"),
                text: $title,
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .focused($isFieldFocused)
            .lineLimit(1...4)

            Button {
                onSave(title)
            } label: {
                Label(String(localized: "Save"), systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(12)
        .onAppear {
            if initialTitle.isEmpty { isFieldFocused = true }
        }
    }
}
