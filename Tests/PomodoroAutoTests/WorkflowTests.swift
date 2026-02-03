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
    
    private func simulatePoll(engine: RuleEngine, snapshot: FocusSnapshot, runningAllowlistApps: Set<String>) {
        let isWork = engine.isWork(snapshot: snapshot, runningAllowlistApps: runningAllowlistApps)
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
        simulatePoll(engine: engine, snapshot: workSnapshot, runningAllowlistApps: ["com.work.app"])
        XCTAssertTrue(workTimer.isRunning, "Timer should auto-start for allowed app")
        
        let distractionSnapshot = FocusSnapshot(
            appName: "Game",
            bundleId: "com.game.app",
            isFullscreen: false,
            timestamp: Date()
        )
        simulatePoll(engine: engine, snapshot: distractionSnapshot, runningAllowlistApps: ["com.work.app"])
        XCTAssertTrue(workTimer.isRunning, "Timer should keep running while allowed app is running")
        
        simulatePoll(engine: engine, snapshot: distractionSnapshot, runningAllowlistApps: [])
        XCTAssertFalse(workTimer.isRunning, "Timer should pause when no allowed app is running")
    }
    
    func testFullscreenRuleFlow() {
        let engine = RuleEngine(config: settingsStore.ruleConfig)
        
        let workFullscreen = FocusSnapshot(
            appName: "Work",
            bundleId: "com.work.app",
            isFullscreen: true,
            timestamp: Date()
        )
        simulatePoll(engine: engine, snapshot: workFullscreen, runningAllowlistApps: ["com.work.app"])
        XCTAssertTrue(workTimer.isRunning, "Whitelisted app in fullscreen should count as work")
        
        let randomFullscreen = FocusSnapshot(
            appName: "Movie",
            bundleId: "com.movie.player",
            isFullscreen: true,
            timestamp: Date()
        )
        simulatePoll(engine: engine, snapshot: randomFullscreen, runningAllowlistApps: ["com.work.app"])
        XCTAssertTrue(workTimer.isRunning, "Allowlist running should keep timer active even in fullscreen")
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
    
    func testBreakStartsAfterWorkCompletion() {
        let workCompletionExpectation = expectation(description: "Work timer should complete")
        
        workTimer.onComplete = { [weak self] in
            guard let self else { return }
            self.breakTimer.reset()
            self.breakTimer.start()
            workCompletionExpectation.fulfill()
        }
        
        workTimer.setDuration(seconds: 1)
        workTimer.start()
        
        wait(for: [workCompletionExpectation], timeout: 2.0)
        
        XCTAssertFalse(workTimer.isRunning, "Work timer should not be running after completion")
        XCTAssertTrue(breakTimer.isRunning, "Break timer should start after work completion")
        XCTAssertEqual(breakTimer.remainingSeconds, 5, "Break timer should have full duration")
    }
}
