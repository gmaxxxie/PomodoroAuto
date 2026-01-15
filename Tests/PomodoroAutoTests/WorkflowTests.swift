import XCTest
@testable import PomodoroAuto

final class WorkflowTests: XCTestCase {
    var defaults: UserDefaults!
    var settingsStore: SettingsStore!
    var workTimer: PomodoroTimer!
    var breakTimer: PomodoroTimer!
    
    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "WorkflowTests")
        defaults.removePersistentDomain(forName: "WorkflowTests")
        settingsStore = SettingsStore(defaults: defaults)
        
        settingsStore.autoStart = true
        settingsStore.autoStartBundleIds = ["com.work.app"]
        settingsStore.fullscreenNonWork = true
        settingsStore.whitelistBundleIds = ["com.work.app"]
        
        workTimer = PomodoroTimer(durationSeconds: 10)
        breakTimer = PomodoroTimer(durationSeconds: 5)
    }
    
    override func tearDown() {
        defaults.removePersistentDomain(forName: "WorkflowTests")
        super.tearDown()
    }
    
    private func simulatePoll(engine: RuleEngine, snapshot: FocusSnapshot) {
        let isWork = engine.isWork(snapshot: snapshot)
        if isWork {
            if !workTimer.isRunning && !breakTimer.isRunning {
                workTimer.start()
            }
        } else {
            if workTimer.isRunning {
                workTimer.pause()
            }
        }
    }
    
    func testAutoStartAndPauseFlow() {
        let engine = RuleEngine(config: settingsStore.ruleConfig)
        
        XCTAssertFalse(workTimer.isRunning)
        
        let workSnapshot = FocusSnapshot(
            appName: "Work",
            bundleId: "com.work.app",
            isFullscreen: false,
            timestamp: Date()
        )
        simulatePoll(engine: engine, snapshot: workSnapshot)
        XCTAssertTrue(workTimer.isRunning, "Timer should auto-start for allowed app")
        
        let distractionSnapshot = FocusSnapshot(
            appName: "Game",
            bundleId: "com.game.app",
            isFullscreen: false,
            timestamp: Date()
        )
        simulatePoll(engine: engine, snapshot: distractionSnapshot)
        XCTAssertFalse(workTimer.isRunning, "Timer should pause for non-allowed app")
        
        simulatePoll(engine: engine, snapshot: workSnapshot)
        XCTAssertTrue(workTimer.isRunning, "Timer should resume when back to work")
    }
    
    func testFullscreenRuleFlow() {
        let engine = RuleEngine(config: settingsStore.ruleConfig)
        
        let workFullscreen = FocusSnapshot(
            appName: "Work",
            bundleId: "com.work.app",
            isFullscreen: true,
            timestamp: Date()
        )
        simulatePoll(engine: engine, snapshot: workFullscreen)
        XCTAssertTrue(workTimer.isRunning, "Whitelisted app in fullscreen should count as work")
        
        let randomFullscreen = FocusSnapshot(
            appName: "Movie",
            bundleId: "com.movie.player",
            isFullscreen: true,
            timestamp: Date()
        )
        simulatePoll(engine: engine, snapshot: randomFullscreen)
        XCTAssertFalse(workTimer.isRunning, "Non-whitelisted app in fullscreen should pause")
    }
    
    func testTimerCompletionFlow() {
        let completionExpectation = expectation(description: "Timer should complete")
        workTimer.onComplete = {
            completionExpectation.fulfill()
        }
        
        workTimer.setDuration(seconds: 1)
        workTimer.start()
        
        wait(for: [completionExpectation], timeout: 2.0)
        
        XCTAssertFalse(workTimer.isRunning)
        XCTAssertEqual(workTimer.remainingSeconds, 1, "Timer should reset to duration after completion")
    }
}
