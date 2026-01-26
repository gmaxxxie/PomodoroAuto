import XCTest
@testable import PomodoroAuto

final class BreakPromptProviderTests: XCTestCase {
    func testRandomPromptIsNonEmptyAndFromExpectedSet() {
        Localization.apply(preference: .english)
        let provider = BreakPromptProvider()
        let prompts = provider.allPrompts()
        XCTAssertEqual(prompts.count, 10)
        for prompt in prompts {
            XCTAssertFalse(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        let random = provider.randomPrompt()
        XCTAssertTrue(prompts.contains(random))
        Localization.apply(preference: .system)
    }
}
