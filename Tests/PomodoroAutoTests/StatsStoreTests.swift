import XCTest
@testable import PomodoroAuto

final class StatsStoreTests: XCTestCase {
    func testAddWorkAndPomodoro() {
        let suiteName = "PomodoroAutoTests.StatsStore"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let calendar = Calendar(identifier: .gregorian)
        let store = StatsStore(defaults: defaults, key: "statsByDay", calendar: calendar)

        store.addWorkSeconds(120)
        store.incrementPomodoro()

        let stats = store.statsForToday()
        XCTAssertEqual(stats.workSeconds, 120)
        XCTAssertEqual(stats.pomodoroCount, 1)
    }
}
