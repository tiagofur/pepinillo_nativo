// WatchGuideCaptureUITests.swift
// Pepinillo — watchOS UI tour: swipes through the app pages and attaches
// a device screenshot per step for the landing guides. The watch app is
// a companion: session/task data arrives from the paired iPhone (which
// is seeded by the iOS capture run).

import XCTest

@MainActor
final class WatchGuideCaptureUITests: XCTestCase {

	private var app: XCUIApplication!

	override func setUpWithError() throws {
		continueAfterFailure = true
		app = XCUIApplication()
		app.launchArguments += ["-AppleLanguages", "(es)"]
		app.launch()
	}

	private func capture(_ name: String) {
		let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
		shot.name = name
		shot.lifetime = .keepAlways
		add(shot)
	}

	private func settle(_ seconds: Double = 2) {
		Thread.sleep(forTimeInterval: seconds)
	}

	func testCaptureWatchScreens() throws {
		// La app abre en la página del timer
		settle(3)
		capture("watchos-01-timer")

		// Página de tareas (swipe vertical entre páginas)
		app.swipeUp()
		settle(2)
		capture("watchos-02-tareas")

		app.swipeUp()
		settle(2)
		capture("watchos-03-scroll")
	}
}
