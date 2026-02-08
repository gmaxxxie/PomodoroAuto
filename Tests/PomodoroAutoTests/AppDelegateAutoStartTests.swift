import XCTest
@testable import PomodoroAuto

final class AppDelegateAutoStartTests: XCTestCase {
    func testShouldPromptAccessibilityAccessWhenAutoStartEnabledAndNotTrusted() {
        let shouldPrompt = AppDelegate.shouldPromptAccessibilityAccess(
            autoStartEnabled: true,
            isAccessibilityTrusted: false
        )

        XCTAssertTrue(shouldPrompt)
    }

    func testShouldNotPromptAccessibilityAccessWhenAlreadyTrusted() {
        let shouldPrompt = AppDelegate.shouldPromptAccessibilityAccess(
            autoStartEnabled: true,
            isAccessibilityTrusted: true
        )

        XCTAssertFalse(shouldPrompt)
    }

    func testShouldNotPromptAccessibilityAccessWhenAutoStartDisabled() {
        let shouldPrompt = AppDelegate.shouldPromptAccessibilityAccess(
            autoStartEnabled: false,
            isAccessibilityTrusted: false
        )

        XCTAssertFalse(shouldPrompt)
    }

    func testShouldNotRequestNotificationAuthorizationOnLaunch() {
        XCTAssertFalse(AppDelegate.shouldRequestNotificationAuthorizationOnLaunch)
    }

    func testShouldNotRequestAccessibilityAccessOnLaunch() {
        XCTAssertFalse(AppDelegate.shouldRequestAccessibilityAccessOnLaunch)
    }

    func testEvaluateWorkStateUsesRunningAllowlistEvenWhenFrontmostIsPomodoroAuto() {
        let snapshot = FocusSnapshot(
            appName: "PomodoroAuto",
            bundleId: "com.pomodoroauto.app",
            isFullscreen: false,
            timestamp: Date()
        )
        let engine = RuleEngine(
            config: RuleConfig(
                fullscreenNonWork: true,
                whitelistBundleIds: [],
                autoStartBundleIds: ["com.work.app"]
            )
        )

        let isWork = AppDelegate.evaluateWorkState(
            snapshot: snapshot,
            appBundleId: "com.pomodoroauto.app",
            runningAllowlistApps: ["com.work.app"],
            ruleEngine: engine
        )

        XCTAssertEqual(isWork, true, "Running allowlist app should auto-start timer even if PomodoroAuto is frontmost")
    }

    func testEvaluateWorkStateSkipsWhenFrontmostIsPomodoroAutoAndAllowlistIsEmpty() {
        let snapshot = FocusSnapshot(
            appName: "PomodoroAuto",
            bundleId: "com.pomodoroauto.app",
            isFullscreen: false,
            timestamp: Date()
        )
        let engine = RuleEngine(
            config: RuleConfig(
                fullscreenNonWork: true,
                whitelistBundleIds: [],
                autoStartBundleIds: []
            )
        )

        let isWork = AppDelegate.evaluateWorkState(
            snapshot: snapshot,
            appBundleId: "com.pomodoroauto.app",
            runningAllowlistApps: [],
            ruleEngine: engine
        )

        XCTAssertNil(isWork, "When allowlist is empty and PomodoroAuto is frontmost, focus poll should skip")
    }

    func testShouldStartTimerSkipsWhenAutoStartIsSuppressed() {
        let shouldStart = AppDelegate.shouldStartTimer(
            isWork: true,
            workTimerRunning: false,
            breakTimerRunning: false,
            isAutoStartSuppressed: true
        )

        XCTAssertFalse(shouldStart, "Explicit stop should suppress immediate auto-start")
    }

    func testNextAutoStartSuppressionStateClearsAfterLeavingWorkContext() {
        let stillSuppressed = AppDelegate.nextAutoStartSuppressionState(
            currentlySuppressed: true,
            isWork: true
        )
        XCTAssertTrue(stillSuppressed, "Suppression should remain while work condition stays true")

        let afterNonWorkSnapshot = AppDelegate.nextAutoStartSuppressionState(
            currentlySuppressed: true,
            isWork: false
        )
        XCTAssertFalse(afterNonWorkSnapshot, "Suppression should clear after leaving work context so auto-start can recover")
    }

    func testShouldStartTimerRecoversAfterSuppressionClearsOnNonWork() {
        let suppressionAfterNonWork = AppDelegate.nextAutoStartSuppressionState(
            currentlySuppressed: true,
            isWork: false
        )
        let shouldStartWhenWorkReturns = AppDelegate.shouldStartTimer(
            isWork: true,
            workTimerRunning: false,
            breakTimerRunning: false,
            isAutoStartSuppressed: suppressionAfterNonWork
        )

        XCTAssertTrue(shouldStartWhenWorkReturns, "Auto-start should resume when user returns to a work app after suppression clears")
    }

    func testShouldPauseWorkTimerDoesNotPauseWhenIsWork() {
        let shouldPause = AppDelegate.shouldPauseWorkTimer(
            isWork: true,
            workTimerRunning: true
        )

        XCTAssertFalse(shouldPause, "Work timer should keep running when current snapshot is work")
    }

    func testShouldPauseWorkTimerPausesWhenNotWorkAndRunning() {
        let shouldPause = AppDelegate.shouldPauseWorkTimer(
            isWork: false,
            workTimerRunning: true
        )

        XCTAssertTrue(shouldPause, "Work timer should pause only when not-work condition is detected")
    }
}
