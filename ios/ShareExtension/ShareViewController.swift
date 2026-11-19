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

    // Bound into the single SwiftUI install; content resolution updates it
    // in place so there is no second mount (no flash, no lost keystrokes).
    private var titleBinding = BindingHolder("")
    private var hostingController: UIHostingController<ShareCaptureView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        installView()
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
                // Rich-text providers hand more than plain String: coerce
                // String, NSAttributedString, NSURL, and plist dictionaries
                // (typed key first, then any String value); anything else
                // falls through to manual typing.
                let text = (item as? String)
                    ?? (item as? NSAttributedString)?.string
                    ?? (item as? NSURL)?.absoluteString
                    ?? Self.text(fromDictionary: item)
                    ?? ""
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
        guard titleBinding.value.isEmpty else { return }
        titleBinding.value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Some rich-text providers deliver `loadItem` payloads as a plist
    /// dictionary keyed by type identifier.
    private nonisolated static func text(fromDictionary item: Any?) -> String? {
        guard let dict = item as? NSDictionary else { return nil }
        if let typed = dict[UTType.text.identifier] as? String { return typed }
        return dict.allValues.first(where: { $0 is String }) as? String
    }

    // MARK: UI

    private func installView() {
        let view = ShareCaptureView(
            holder: titleBinding,
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
        // The app drains this key on next activation (bootstrap or
        // appBecameActive); no iOS process observes the Darwin signal today —
        // it is posted for parity with the other external-command writers and
        // in case a Mac-side-style observer lands on iOS later.
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

// MARK: - Binding holder
//
// The view controller owns the title so content resolution can update it in
// place after the single SwiftUI mount. The view observes the holder via
// @ObservedObject — without that subscription, @Published invalidation never
// reaches SwiftUI and the resolved text would never appear (judgment-day
// round-2 finding).

private final class BindingHolder: ObservableObject {
    @Published var value: String
    init(_ value: String) { self.value = value }
}

// MARK: - ShareCaptureView

private struct ShareCaptureView: View {
    @ObservedObject var holder: BindingHolder
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @FocusState private var isFieldFocused: Bool

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
                text: $holder.value,
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .focused($isFieldFocused)
            .lineLimit(1...4)

            Button {
                onSave(holder.value)
            } label: {
                Label(String(localized: "Save"), systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(holder.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(12)
        .onAppear {
            if holder.value.isEmpty { isFieldFocused = true }
        }
    }
}
