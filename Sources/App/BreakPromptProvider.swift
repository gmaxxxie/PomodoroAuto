import Foundation

struct BreakPromptProvider {
    private let promptKeys = [
        "overlay.break.prompt.1",
        "overlay.break.prompt.2",
        "overlay.break.prompt.3",
        "overlay.break.prompt.4",
        "overlay.break.prompt.5",
        "overlay.break.prompt.6",
        "overlay.break.prompt.7",
        "overlay.break.prompt.8",
        "overlay.break.prompt.9",
        "overlay.break.prompt.10"
    ]

    func allPrompts() -> [String] {
        promptKeys.map { Localization.localized($0) }
    }

    func randomPrompt() -> String {
        let prompts = allPrompts()
        return prompts.randomElement() ?? Localization.localized("overlay.break.title")
    }
}
