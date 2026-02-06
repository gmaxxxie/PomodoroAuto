import XCTest
@testable import PomodoroAuto

final class StatsStoreTests: XCTestCase {
    var defaults: UserDefaults!
    var store: StatsStore!
    
    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "StatsStoreTests")
        defaults.removePersistentDomain(forName: "StatsStoreTests")
        store = StatsStore(defaults: defaults, key: "test_stats")
    }
    
    override func tearDown() {
        defaults.removePersistentDomain(forName: "StatsStoreTests")
        super.tearDown()
    }
    
    func testInitialStatsAreZero() {
        let stats = store.statsForToday()
        XCTAssertEqual(stats.workSeconds, 0)
        XCTAssertEqual(stats.pomodoroCount, 0)
    }
    
    func testAddWorkSeconds() {
        store.addWorkSeconds(60)
        store.addWorkSeconds(30)
        
        let stats = store.statsForToday()
        XCTAssertEqual(stats.workSeconds, 90)
    }
    
    func testIncrementPomodoro() {
        store.incrementPomodoro()
        store.incrementPomodoro()
        
        let stats = store.statsForToday()
        XCTAssertEqual(stats.pomodoroCount, 2)
    }
    
    func testPersistenceAcrossInstances() {
        store.addWorkSeconds(100)
        store.incrementPomodoro()
        
        let newStore = StatsStore(defaults: defaults, key: "test_stats")
        let stats = newStore.statsForToday()
        
        XCTAssertEqual(stats.workSeconds, 100)
        XCTAssertEqual(stats.pomodoroCount, 1)
    }

    func testAllStatsReturnsAllDays() {
        store.addWorkSeconds(100)
        store.incrementPomodoro()

        let all = store.allStats()
        XCTAssertEqual(all.count, 1)
        let todayStats = all.values.first
        XCTAssertEqual(todayStats?.workSeconds, 100)
        XCTAssertEqual(todayStats?.pomodoroCount, 1)
    }

    func testTotalStatsAggregatesCorrectly() {
        store.addWorkSeconds(100)
        store.incrementPomodoro()
        store.addWorkSeconds(50)
        store.incrementPomodoro()

        let total = store.totalStats()
        XCTAssertEqual(total.workSeconds, 150)
        XCTAssertEqual(total.pomodoroCount, 2)
    }

    func testTotalStatsEmptyReturnsZero() {
        let total = store.totalStats()
        XCTAssertEqual(total.workSeconds, 0)
        XCTAssertEqual(total.pomodoroCount, 0)
    }

    func testAverageStatsCalculatesCorrectly() {
        store.addWorkSeconds(100)
        store.incrementPomodoro()
        store.incrementPomodoro()

        let avg = store.averageStats()
        XCTAssertEqual(avg.dayCount, 1)
        XCTAssertEqual(avg.avgWorkSeconds, 100.0, accuracy: 0.01)
        XCTAssertEqual(avg.avgPomodoroCount, 2.0, accuracy: 0.01)
    }

    func testAverageStatsEmptyReturnsZero() {
        let avg = store.averageStats()
        XCTAssertEqual(avg.dayCount, 0)
        XCTAssertEqual(avg.avgWorkSeconds, 0.0)
        XCTAssertEqual(avg.avgPomodoroCount, 0.0)
    }

    func testClearAllRemovesAllStats() {
        store.addWorkSeconds(100)
        store.incrementPomodoro()

        store.clearAll()

        let stats = store.statsForToday()
        XCTAssertEqual(stats.workSeconds, 0)
        XCTAssertEqual(stats.pomodoroCount, 0)

        let all = store.allStats()
        XCTAssertTrue(all.isEmpty)

        let total = store.totalStats()
        XCTAssertEqual(total.workSeconds, 0)
        XCTAssertEqual(total.pomodoroCount, 0)
    }
}
