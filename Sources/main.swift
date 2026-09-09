import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

// AI review test: intentionally problematic code
func dangerouslyDivide(_ a: Int, _ b: Int) -> Int {
    return a / b  // crash if b == 0
}

func hardcodedCredential() -> String {
    return "sk-live-1234567890abcdef"  // sensitive hardcoded
}
