import XCTest
@testable import PomodoroAuto

final class RuleEngineTests: XCTestCase {
    func testAutoStartAllowlistBlocksOtherApps() {
        let config = RuleConfig(
            fullscreenNonWork: true,
            whitelistBundleIds: [],
            autoStartBundleIds: ["com.example.Allowed"]
        )
        let engine = RuleEngine(config: config)
        let allowed = FocusSnapshot(
            appName: "Allowed",
            bundleId: "com.example.Allowed",
            isFullscreen: false,
            timestamp: Date()
        )
        let blocked = FocusSnapshot(
            appName: "Blocked",
            bundleId: "com.example.Blocked",
            isFullscreen: false,
            timestamp: Date()
        )
        XCTAssertTrue(engine.isWork(snapshot: allowed))
        XCTAssertFalse(engine.isWork(snapshot: blocked))
    }

    func testSafariFullscreenAlwaysNonWork() {
        let config = RuleConfig(
            fullscreenNonWork: false,
            whitelistBundleIds: ["com.apple.Safari"],
            autoStartBundleIds: []
        )
        let engine = RuleEngine(config: config)
        let snapshot = FocusSnapshot(
            appName: "Safari",
            bundleId: "com.apple.Safari",
            isFullscreen: true,
            timestamp: Date()
        )
        XCTAssertFalse(engine.isWork(snapshot: snapshot))
    }

    func testFullscreenNonWorkRespectsAllowlist() {
        let config = RuleConfig(
            fullscreenNonWork: true,
            whitelistBundleIds: ["com.example.Allowed"],
            autoStartBundleIds: []
        )
        let engine = RuleEngine(config: config)
        let allowed = FocusSnapshot(
            appName: "Allowed",
            bundleId: "com.example.Allowed",
            isFullscreen: true,
            timestamp: Date()
        )
        let blocked = FocusSnapshot(
            appName: "Blocked",
            bundleId: "com.example.Blocked",
            isFullscreen: true,
            timestamp: Date()
        )
        XCTAssertTrue(engine.isWork(snapshot: allowed))
        XCTAssertFalse(engine.isWork(snapshot: blocked))
    }

    func testEmptyAutoStartAllowlistAllowsAllApps() {
        let config = RuleConfig(
            fullscreenNonWork: false,
            whitelistBundleIds: [],
            autoStartBundleIds: []
        )
        let engine = RuleEngine(config: config)
        let snapshot = FocusSnapshot(
            appName: "AnyApp",
            bundleId: "com.example.AnyApp",
            isFullscreen: false,
            timestamp: Date()
        )
        XCTAssertTrue(engine.isWork(snapshot: snapshot))
    }

    func testCombinedAutoStartAndFullscreenRules() {
        let config = RuleConfig(
            fullscreenNonWork: true,
            whitelistBundleIds: ["com.example.WorkApp"],
            autoStartBundleIds: ["com.example.WorkApp"]
        )
        let engine = RuleEngine(config: config)

        let workAppNotFullscreen = FocusSnapshot(
            appName: "WorkApp",
            bundleId: "com.example.WorkApp",
            isFullscreen: false,
            timestamp: Date()
        )
        let workAppFullscreen = FocusSnapshot(
            appName: "WorkApp",
            bundleId: "com.example.WorkApp",
            isFullscreen: true,
            timestamp: Date()
        )
        let otherAppNotFullscreen = FocusSnapshot(
            appName: "OtherApp",
            bundleId: "com.example.OtherApp",
            isFullscreen: false,
            timestamp: Date()
        )

        XCTAssertTrue(engine.isWork(snapshot: workAppNotFullscreen))
        XCTAssertTrue(engine.isWork(snapshot: workAppFullscreen))
        XCTAssertFalse(engine.isWork(snapshot: otherAppNotFullscreen))
    }
}
