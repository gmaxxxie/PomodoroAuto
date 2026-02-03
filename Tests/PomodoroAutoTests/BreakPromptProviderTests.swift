import XCTest
@testable import PomodoroAuto

final class BreakPromptProviderTests: XCTestCase {
    func testRandomPromptReturnsNonEmptyString() {
        for _ in 1...20 {
            let prompt = BreakPromptProvider.randomPrompt()
            XCTAssertFalse(prompt.isEmpty, "randomPrompt() should return non-empty string")
        }
    }

    func testRandomPromptDoesNotReturnRawKey() {
        for _ in 1...20 {
            let prompt = BreakPromptProvider.randomPrompt()
            XCTAssertFalse(prompt.hasPrefix("overlay.break.prompt."), "randomPrompt() should return localized string, not raw key")
        }
    }
}
