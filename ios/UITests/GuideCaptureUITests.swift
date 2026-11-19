// GuideCaptureUITests.swift
// Pepinillo — UI tour that drives the app into the states used by the
// landing guides and attaches a device screenshot per step. Screens are
// exported from the .xcresult with xcresulttool.
//
// Launch: scheme "Pepinillo UI Capture" (Debug). The app itself seeds
// demo data via -seedDemoData, localized with -esDemo, and simulates
// Pepinillo+ with -proMode.

import XCTest

@MainActor
final class GuideCaptureUITests: XCTestCase {

	private var app: XCUIApplication!

	override func setUpWithError() throws {
		continueAfterFailure = true
		app = XCUIApplication()
		app.launchArguments += ["-seedDemoData", "-esDemo", "-proMode", "-AppleLanguages", "(es)", "-AppleLocale", "es_AR"]
		app.launch()
	}

	private func capture(_ name: String) {
		let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
		shot.name = name
		shot.lifetime = .keepAlways
		add(shot)
	}

	private func settle(_ seconds: Double = 1.5) {
		Thread.sleep(forTimeInterval: seconds)
	}

	func testCaptureGuideScreens() throws {
		// Asegurar que la app terminó de arrancar con el seed
		let tabBar = app.tabBars.firstMatch
		XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
		settle(2)

		// 1 — Foco idle
		app.tabBars.buttons.element(boundBy: 0).tap()
		settle(2)
		capture("iphone-01-foco-idle")

		// 3 — Foco corriendo (iniciar y dejar avanzar el anillo)
		let startButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Iniciar'")).firstMatch
		XCTAssertTrue(startButton.waitForExistence(timeout: 8))
		startButton.tap()
		settle(12)
		capture("iphone-03-foco-corriendo")

		// Terminar la sesión (dos pasos) → volver a listo
		let stopPredicate = NSPredicate(format: "label CONTAINS 'Terminar' OR label CONTAINS 'Detener' OR label CONTAINS 'Stop'")
		let stopButton = app.buttons.matching(stopPredicate).firstMatch
		if stopButton.waitForExistence(timeout: 5) {
			stopButton.tap()
			settle(1.5)
			// confirmación en dos pasos: el botón pasa a pedir confirmación
			let confirm = app.buttons.matching(stopPredicate).firstMatch
			if confirm.waitForExistence(timeout: 3) { confirm.tap() }
			settle(3)
			// diario de sesión si aparece → omitir
			let skip = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Omitir' OR label CONTAINS 'Skip'")).firstMatch
			if skip.waitForExistence(timeout: 5) { skip.tap() }
			settle(2)
		}

		// 5 — Plan con tareas del seed
		app.tabBars.buttons.element(boundBy: 1).tap()
		settle(2)
		capture("iphone-04-plan")

		// 6 — Panel (dashboard)
		app.tabBars.buttons.element(boundBy: 2).tap()
		settle(2)
		capture("iphone-05-panel")

		// 9 — Más / ajustes
		app.tabBars.buttons.element(boundBy: 3).tap()
		settle(2)
		capture("iphone-06-ajustes")

		// 8 — Estadísticas (desde Más; cualquier elemento que la anuncie)
		let statsPredicate = NSPredicate(format: "label CONTAINS 'Estadísticas' OR label CONTAINS 'Estadisticas'")
		let statsRow = app.descendants(matching: .any).matching(statsPredicate).firstMatch
		if statsRow.waitForExistence(timeout: 5) {
			statsRow.tap()
			settle(2.5)
			capture("iphone-07-panel-30d")
		}

		// 2 — Modo alternativo (desde Foco, al final para no interrumpir el flujo)
		app.tabBars.buttons.element(boundBy: 0).tap()
		settle(2)
		let flowSegment = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Tiempo fluido'")).firstMatch
		if flowSegment.waitForExistence(timeout: 5) {
			flowSegment.tap()
			settle(2)
			capture("iphone-02-modos")
		}
	}
}
