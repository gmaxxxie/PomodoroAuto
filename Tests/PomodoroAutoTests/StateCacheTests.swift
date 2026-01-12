import XCTest
@testable import PomodoroAuto

final class StateCacheTests: XCTestCase {
    func testTrimsByAgeAndCount() {
        let cache = StateCache(maxCount: 2, retentionSeconds: 5)
        let oldSnapshot = FocusSnapshot(
            appName: "Old",
            bundleId: "com.example.old",
            isFullscreen: false,
            timestamp: Date().addingTimeInterval(-10)
        )
        let freshSnapshot1 = FocusSnapshot(
            appName: "Fresh1",
            bundleId: "com.example.fresh1",
            isFullscreen: false,
            timestamp: Date()
        )
        let freshSnapshot2 = FocusSnapshot(
            appName: "Fresh2",
            bundleId: "com.example.fresh2",
            isFullscreen: false,
            timestamp: Date()
        )

        cache.append(snapshot: oldSnapshot)
        cache.append(snapshot: freshSnapshot1)
        cache.append(snapshot: freshSnapshot2)

        XCTAssertEqual(cache.count, 2)
    }
}
