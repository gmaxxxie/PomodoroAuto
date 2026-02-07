import AppKit
import XCTest
@testable import PomodoroAuto

@MainActor
final class OverlayWindowControllerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        _ = NSApplication.shared
    }

    func testBreakOverlayDismissOrdersOutWindowWhenControllerIsReleased() throws {
        guard NSScreen.main != nil else {
            throw XCTSkip("No main screen is available for overlay window tests")
        }

        var controller: BreakOverlayWindowController? = BreakOverlayWindowController()
        controller?.show(title: "Break", message: "Move around", footer: "ESC", timeoutSeconds: 30)

        guard let window = controller?.window else {
            XCTFail("Overlay window should be created")
            return
        }
        XCTAssertTrue(window.isVisible)

        controller?.dismiss()
        controller = nil
        runMainLoop(for: 0.35)

        XCTAssertFalse(window.isVisible, "Overlay window should be ordered out after dismiss")
    }

    func testBreakOverlayDismissesWhenEscapeIsPressedOnWindow() throws {
        guard NSScreen.main != nil else {
            throw XCTSkip("No main screen is available for overlay window tests")
        }

        let controller = BreakOverlayWindowController()
        var didDismiss = false
        controller.onDismiss = { didDismiss = true }
        controller.show(title: "Break", message: "Move around", footer: "ESC", timeoutSeconds: 30)

        guard let window = controller.window else {
            XCTFail("Overlay window should be created")
            return
        }

        let event = makeEscapeKeyDownEvent(windowNumber: window.windowNumber)
        window.keyDown(with: event)
        runMainLoop(for: 0.35)

        XCTAssertTrue(didDismiss, "Pressing Escape should dismiss the break overlay")
        XCTAssertFalse(window.isVisible, "Overlay window should be hidden after Escape")
    }

    func testBreakOverlayIncludesCloseButtonThatDismissesOverlay() throws {
        guard NSScreen.main != nil else {
            throw XCTSkip("No main screen is available for overlay window tests")
        }

        let controller = BreakOverlayWindowController()
        var didDismiss = false
        controller.onDismiss = { didDismiss = true }
        controller.show(
            title: "Break",
            message: "Move around",
            footer: "ESC",
            closeTitle: "CloseOverlayTest",
            timeoutSeconds: 30
        )

        guard let rootView = controller.window?.contentView else {
            XCTFail("Overlay window should have a content view")
            return
        }

        guard let closeButton = findButton(in: rootView, title: "CloseOverlayTest") else {
            XCTFail("Break overlay should include a close button")
            return
        }

        closeButton.performClick(nil)
        runMainLoop(for: 0.35)

        XCTAssertTrue(didDismiss, "Clicking close should dismiss the break overlay")
        XCTAssertFalse(controller.window?.isVisible == true, "Overlay should be hidden after clicking close")
    }

    func testContinuationPromptShowsOnlyStartAndStopActions() throws {
        guard NSScreen.main != nil else {
            throw XCTSkip("No main screen is available for overlay window tests")
        }

        let controller = ContinuationPromptWindowController()
        var didStartNext = false
        var didStop = false

        controller.onStartNext = { didStartNext = true }
        controller.onStop = { didStop = true }

        controller.show(
            title: "Break Complete",
            message: "Ready for next pomodoro?",
            startNextTitle: "StartTest",
            stopTitle: "StopTest"
        )

        guard let rootView = controller.window?.contentView else {
            XCTFail("Continuation prompt should have a content view")
            return
        }

        XCTAssertNotNil(findButton(in: rootView, title: "StartTest"), "Continuation prompt should include start action")
        XCTAssertNotNil(findButton(in: rootView, title: "StopTest"), "Continuation prompt should include stop action")
        XCTAssertNil(findButton(in: rootView, title: "CloseTest"), "Continuation prompt should not include close action")
        XCTAssertFalse(didStartNext, "Rendering prompt should not trigger start")
        XCTAssertFalse(didStop, "Rendering prompt should not trigger stop")
    }

    private func runMainLoop(for seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private func findButton(in root: NSView, title: String) -> NSButton? {
        findButtons(in: root).first { $0.title == title }
    }

    private func findButtons(in view: NSView) -> [NSButton] {
        var buttons: [NSButton] = []
        if let button = view as? NSButton {
            buttons.append(button)
        }
        for subview in view.subviews {
            buttons.append(contentsOf: findButtons(in: subview))
        }
        return buttons
    }

    private func makeEscapeKeyDownEvent(windowNumber: Int) -> NSEvent {
        // keyCode 53 is Escape on macOS keyboards.
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: windowNumber,
            context: nil,
            characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}",
            isARepeat: false,
            keyCode: 53
        )!
    }
}
