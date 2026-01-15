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
}
