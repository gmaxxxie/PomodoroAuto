import AppKit
import ApplicationServices

struct FocusSnapshot {
    let appName: String
    let bundleId: String
    let isFullscreen: Bool
    let timestamp: Date
}

final class FocusStateDetector {
    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    func requestAccess() -> Bool {
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary)
    }

    func snapshot() -> FocusSnapshot? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appName = app.localizedName ?? "Unknown"
        let bundleId = app.bundleIdentifier ?? "unknown"
        let isFullscreen = focusedWindowIsFullscreen()
        return FocusSnapshot(appName: appName, bundleId: bundleId, isFullscreen: isFullscreen, timestamp: Date())
    }

    func runningBundleIds() -> Set<String> {
        Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
    }

    private func focusedWindowIsFullscreen() -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedWindow: AnyObject?
        let error = AXUIElementCopyAttributeValue(systemWide, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        guard error == .success, let window = focusedWindow else { return false }

        var fullscreenValue: AnyObject?
        let fullscreenError = AXUIElementCopyAttributeValue(window as! AXUIElement, "AXFullScreen" as CFString, &fullscreenValue)
        guard fullscreenError == .success else { return false }
        if let value = fullscreenValue as? Bool {
            return value
        }
        if let value = fullscreenValue as? NSNumber {
            return value.boolValue
        }
        return false
    }
}
