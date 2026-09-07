import XCTest
@testable import PomodoroAuto

final class SettingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "SettingsStoreTests")
        defaults.removePersistentDomain(forName: "SettingsStoreTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "SettingsStoreTests")
        defaults = nil
        super.tearDown()
    }

    func testDefaultAutoStartIsDisabled() {
        let store = SettingsStore(defaults: defaults)

        XCTAssertFalse(store.autoStart)
    }

    func testDefaultTimerDisplayModeIsTimerAndProgress() {
        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.timerDisplayMode, .timerAndProgress)
    }

    func testTimerDisplayModeCanBePersisted() {
        let store = SettingsStore(defaults: defaults)

        store.timerDisplayMode = .progressOnly

        XCTAssertEqual(store.timerDisplayMode, .progressOnly)
    }

    func testResetToDefaultsRestoresTimerDisplayMode() {
        let store = SettingsStore(defaults: defaults)
        store.timerDisplayMode = .progressOnly

        store.resetToDefaults()

        XCTAssertEqual(store.timerDisplayMode, .timerAndProgress)
    }
}
