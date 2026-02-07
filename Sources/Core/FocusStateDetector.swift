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

    func runningAllowlistBundleIds(from allowlistBundleIds: [String]) -> Set<String> {
        Set(allowlistBundleIds.filter { bundleId in
            !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
        })
    }

    private func focusedWindowIsFullscreen() -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedWindow: AnyObject?
        let error = AXUIElementCopyAttributeValue(systemWide, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        guard error == .success, let window = focusedWindow else { return false }
        // swiftlint:disable:next force_cast
        let windowElement = window as! AXUIElement

        var fullscreenValue: AnyObject?
        let fullscreenError = AXUIElementCopyAttributeValue(windowElement, "AXFullScreen" as CFString, &fullscreenValue)
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
