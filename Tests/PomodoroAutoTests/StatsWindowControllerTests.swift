import XCTest
import AppKit
@testable import PomodoroAuto

final class StatsWindowControllerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var statsStore: StatsStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "StatsWindowControllerTests")
        defaults.removePersistentDomain(forName: "StatsWindowControllerTests")
        statsStore = StatsStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "StatsWindowControllerTests")
        statsStore = nil
        defaults = nil
        super.tearDown()
    }

    func testStatsWindowCloseClearsOnCloseCallback() {
        let controller = StatsWindowController(statsStore: statsStore)
        _ = controller.window
        controller.onClose = {}

        controller.window?.close()

        XCTAssertNil(controller.onClose, "onClose should be cleared when stats window closes")
    }

    func testStatsWindowControllerReleasesAfterClose() {
        weak var weakController: StatsWindowController?

        autoreleasepool {
            var localController: StatsWindowController? = StatsWindowController(statsStore: statsStore)
            _ = localController?.window
            weakController = localController
            localController?.window?.close()
            localController = nil
        }

        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        XCTAssertNil(weakController, "Stats window controller should be released after closing")
    }
}
