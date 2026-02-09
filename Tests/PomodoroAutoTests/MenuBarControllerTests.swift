import AppKit
import QuartzCore
import XCTest
@testable import PomodoroAuto

@MainActor
final class MenuBarControllerTests: XCTestCase {
    private var previousAppearance: NSAppearance?

    override func setUp() {
        super.setUp()
        _ = NSApplication.shared
        previousAppearance = NSApp.appearance
        NSApp.appearance = NSAppearance(named: .aqua)
    }

    override func tearDown() {
        NSApp.appearance = previousAppearance
        previousAppearance = nil
        super.tearDown()
    }

    func testSetRemainingDoesNotForceStatusButtonTintColor() {
        let controller = MenuBarController()
        controller.setRemaining(seconds: 90)

        guard let button = statusButton(from: controller) else {
            XCTFail("Expected status button to exist")
            return
        }

        XCTAssertNil(button.contentTintColor)
    }

    func testSetRemainingDoesNotForceWhiteStatusButtonTitleColor() {
        let controller = MenuBarController()
        controller.setRemaining(seconds: 90)

        guard let button = statusButton(from: controller) else {
            XCTFail("Expected status button to exist")
            return
        }

        let attributedTitle = button.attributedTitle
        XCTAssertEqual(attributedTitle.string, "01:30")

        let color = attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        assertColorIsNotForcedWhite(color)

        if let cell = button.cell as? NSButtonCell {
            let cellColor = cell.attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
            assertColorIsNotForcedWhite(cellColor)
        } else {
            XCTFail("Expected NSButtonCell")
        }
    }

    func testSetRemainingDoesNotRenderCustomTimerTextLayer() {
        let controller = MenuBarController()
        controller.setRemaining(seconds: 90)

        guard let button = statusButton(from: controller) else {
            XCTFail("Expected status button to exist")
            return
        }

        XCTAssertNil(findTimerTextLayer(in: button.layer))
    }

    func testSetRemainingDoesNotForceDarkStatusButtonAppearance() {
        let controller = MenuBarController()
        controller.setRemaining(seconds: 90)

        guard let button = statusButton(from: controller) else {
            XCTFail("Expected status button to exist")
            return
        }

        XCTAssertNotEqual(button.appearance?.name, .vibrantDark)
    }

    func testSetRemainingUsesTemplateStatusImage() {
        let controller = MenuBarController()
        controller.setRemaining(seconds: 90)

        guard let button = statusButton(from: controller) else {
            XCTFail("Expected status button to exist")
            return
        }

        XCTAssertEqual(button.image?.isTemplate, true)
    }

    func testFallbackStatusIconUsesImageInsteadOfEmojiTitle() {
        let controller = MenuBarController(
            customStatusIconLoader: { nil },
            systemSymbolLoader: { _, _ in nil }
        )
        controller.setStatus(text: "Idle", mode: .idle)

        guard let button = statusButton(from: controller) else {
            XCTFail("Expected status button to exist")
            return
        }

        XCTAssertNotEqual(button.title, "🍅")
        XCTAssertNotNil(button.image)
        XCTAssertEqual(button.image?.isTemplate, true)
    }

    private func statusButton(from controller: MenuBarController) -> NSStatusBarButton? {
        let mirror = Mirror(reflecting: controller)
        guard let statusItem = mirror.children.first(where: { $0.label == "statusItem" })?.value as? NSStatusItem else {
            return nil
        }
        return statusItem.button
    }

    private func assertColorIsNotForcedWhite(
        _ color: NSColor?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let color else {
            return
        }

        guard let rgbColor = color.usingColorSpace(.deviceRGB) else {
            XCTFail("Expected color in RGB space", file: file, line: line)
            return
        }

        let isWhite = abs(rgbColor.redComponent - 1.0) < 0.001
            && abs(rgbColor.greenComponent - 1.0) < 0.001
            && abs(rgbColor.blueComponent - 1.0) < 0.001
        XCTAssertFalse(isWhite, file: file, line: line)
    }

    private func findTimerTextLayer(in layer: CALayer?) -> CATextLayer? {
        guard let layer else { return nil }
        if let textLayer = layer as? CATextLayer,
           let text = textLayer.string as? String,
           text.contains(":") {
            return textLayer
        }
        for sublayer in layer.sublayers ?? [] {
            if let found = findTimerTextLayer(in: sublayer) {
                return found
            }
        }
        return nil
    }
}
