// HapticManager.swift
// Pepinillo — Deep Work Companion for Apple

#if os(iOS)
import UIKit
#endif

@MainActor
enum HapticManager {
    #if os(iOS)
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    #endif

    static func impact(_ style: HapticStyle = .medium) {
        #if os(iOS)
        switch style {
        case .light:
            lightGenerator.impactOccurred()
        case .medium:
            mediumGenerator.impactOccurred()
        case .heavy:
            heavyGenerator.impactOccurred()
        }
        #endif
    }

    static func notification(_ type: NotificationType) {
        #if os(iOS)
        switch type {
        case .success:
            notificationGenerator.notificationOccurred(.success)
        case .warning:
            notificationGenerator.notificationOccurred(.warning)
        case .error:
            notificationGenerator.notificationOccurred(.error)
        }
        #endif
    }

    static func selection() {
        #if os(iOS)
        selectionGenerator.selectionChanged()
        #endif
    }

    enum HapticStyle {
        case light, medium, heavy
    }

    enum NotificationType {
        case success, warning, error
    }
}
