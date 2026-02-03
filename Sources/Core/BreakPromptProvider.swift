import Foundation

enum BreakPromptProvider {
    private static let promptCount = 10

    static func randomPrompt() -> String {
        let index = Int.random(in: 1...promptCount)
        let key = "overlay.break.prompt.\(index)"
        let result = Localization.localized(key)
        if result == key {
            return Localization.localized("overlay.break.prompt.1")
        }
        return result
    }
}
