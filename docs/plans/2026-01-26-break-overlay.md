# Break Overlay Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Show a full-screen dim overlay on the main display with a centered break message when a work session ends, dismissible via ESC or after 15 seconds, with randomized localized tips.

**Architecture:** Add a `BreakOverlayWindowController` that owns a borderless, transparent window on the main display. The window hosts a simple `BreakOverlayView` and listens for ESC to dismiss, with an internal timer for auto-dismiss. A `BreakPromptProvider` supplies randomized localized tips. AppDelegate shows the overlay only when work completes and break starts.

**Tech Stack:** AppKit (NSWindow/NSView/NSStackView), DispatchSourceTimer, UserNotifications, Localization via `Localization.localized`.

---

### Task 1: Add break prompt provider + tests

**Files:**
- Create: `Sources/App/BreakPromptProvider.swift`
- Create: `Tests/PomodoroAutoTests/BreakPromptProviderTests.swift`

**Step 1: Write the failing test**

```swift
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
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter BreakPromptProviderTests.testRandomPromptIsNonEmptyAndFromExpectedSet`
Expected: FAIL (missing `BreakPromptProvider` or symbols)

**Step 3: Write minimal implementation**

```swift
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
```

**Step 4: Run test to verify it passes**

Run: `swift test --filter BreakPromptProviderTests.testRandomPromptIsNonEmptyAndFromExpectedSet`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/App/BreakPromptProvider.swift Tests/PomodoroAutoTests/BreakPromptProviderTests.swift
git commit -m "feat: add break prompt provider"
```

---

### Task 2: Add overlay localization strings (EN + zh-Hans)

**Files:**
- Modify: `Sources/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/Resources/zh-Hans.lproj/Localizable.strings`

**Step 1: Add English strings**

Append:

```strings
"overlay.break.title" = "Time to take a break";
"overlay.break.dismiss" = "Press Esc to dismiss";
"overlay.break.prompt.1" = "Stand up, stretch your shoulders, and relax your jaw.";
"overlay.break.prompt.2" = "Look 20 feet away for 20 seconds to rest your eyes.";
"overlay.break.prompt.3" = "Take five slow breaths in and out, counting each one.";
"overlay.break.prompt.4" = "Get a glass of water and take a few sips.";
"overlay.break.prompt.5" = "Roll your neck gently left and right to release tension.";
"overlay.break.prompt.6" = "Walk around for a minute to reset your focus.";
"overlay.break.prompt.7" = "Open a window and take a few deep breaths.";
"overlay.break.prompt.8" = "Shake out your hands and loosen your wrists.";
"overlay.break.prompt.9" = "Close your eyes for a moment and relax your forehead.";
"overlay.break.prompt.10" = "Sit back and let your shoulders drop for a few seconds.";
```

**Step 2: Add Simplified Chinese strings**

Append:

```strings
"overlay.break.title" = "该休息了";
"overlay.break.dismiss" = "按 Esc 退出";
"overlay.break.prompt.1" = "站起来伸伸肩，放松下颌。";
"overlay.break.prompt.2" = "远眺 6 米外 20 秒，让眼睛休息。";
"overlay.break.prompt.3" = "做 5 次缓慢深呼吸，跟着呼吸数数。";
"overlay.break.prompt.4" = "去喝几口水，补充水分。";
"overlay.break.prompt.5" = "轻轻左右转动脖子，缓解紧张。";
"overlay.break.prompt.6" = "走动一分钟，重置注意力。";
"overlay.break.prompt.7" = "打开窗户，深呼吸几次。";
"overlay.break.prompt.8" = "甩甩手，放松手腕和手指。";
"overlay.break.prompt.9" = "闭眼片刻，放松额头。";
"overlay.break.prompt.10" = "靠着椅背，让肩膀自然下沉几秒。";
```

**Step 3: Commit**

```bash
git add Sources/Resources/en.lproj/Localizable.strings Sources/Resources/zh-Hans.lproj/Localizable.strings
git commit -m "feat: add break overlay localized strings"
```

---

### Task 3: Implement break overlay window controller + view

**Files:**
- Create: `Sources/App/BreakOverlayWindowController.swift`

**Step 1: Write the implementation**

```swift
import AppKit

final class BreakOverlayWindowController: NSWindowController {
    private let timeoutSeconds: TimeInterval
    private let onDismiss: (() -> Void)?
    private var dismissTimer: DispatchSourceTimer?

    init(timeoutSeconds: TimeInterval, onDismiss: (() -> Void)? = nil) {
        self.timeoutSeconds = timeoutSeconds
        self.onDismiss = onDismiss
        let window = BreakOverlayWindow(screen: NSScreen.main)
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func show(title: String, message: String, footer: String) {
        guard let window = window else { return }
        let view = BreakOverlayView(title: title, message: message, footer: footer)
        window.contentView = view
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window.animator().alphaValue = 1
        }

        startDismissTimer()
    }

    func dismiss() {
        dismissTimer?.cancel()
        dismissTimer = nil
        window?.orderOut(nil)
        onDismiss?()
    }

    private func startDismissTimer() {
        dismissTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now() + timeoutSeconds)
        timer.setEventHandler { [weak self] in
            self?.dismiss()
        }
        timer.resume()
        dismissTimer = timer
    }
}

final class BreakOverlayWindow: NSWindow {
    init(screen: NSScreen?) {
        let frame = screen?.frame ?? NSScreen.screens.first?.frame ?? .zero
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = false
        hasShadow = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            (windowController as? BreakOverlayWindowController)?.dismiss()
        } else {
            super.keyDown(with: event)
        }
    }
}

final class BreakOverlayView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let messageLabel = NSTextField(labelWithString: "")
    private let footerLabel = NSTextField(labelWithString: "")

    init(title: String, message: String, footer: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor

        titleLabel.stringValue = title
        titleLabel.font = NSFont.systemFont(ofSize: 40, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center

        messageLabel.stringValue = message
        messageLabel.font = NSFont.systemFont(ofSize: 22, weight: .medium)
        messageLabel.textColor = .white
        messageLabel.alignment = .center
        messageLabel.maximumNumberOfLines = 2
        messageLabel.lineBreakMode = .byWordWrapping

        footerLabel.stringValue = footer
        footerLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        footerLabel.textColor = NSColor.white.withAlphaComponent(0.8)
        footerLabel.alignment = .center

        let stack = NSStackView(views: [titleLabel, messageLabel, footerLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }
}
```

**Step 2: Commit**

```bash
git add Sources/App/BreakOverlayWindowController.swift
git commit -m "feat: add break overlay window"
```

---

### Task 4: Wire overlay into AppDelegate

**Files:**
- Modify: `Sources/App/AppDelegate.swift`

**Step 1: Add property + show helper**

Add near other properties:

```swift
private var breakOverlayWindowController: BreakOverlayWindowController?
private let breakPromptProvider = BreakPromptProvider()
```

Add helper method:

```swift
private func showBreakOverlay() {
    let title = Localization.localized("overlay.break.title")
    let message = breakPromptProvider.randomPrompt()
    let footer = Localization.localized("overlay.break.dismiss")
    let controller = BreakOverlayWindowController(timeoutSeconds: 15) { [weak self] in
        self?.breakOverlayWindowController = nil
    }
    breakOverlayWindowController = controller
    controller.show(title: title, message: message, footer: footer)
}
```

**Step 2: Call in `startBreak()`**

```swift
private func startBreak() {
    breakTimer.start()
    state = .resting
    updateStatusTextForCurrentState()
    sendBreakStartedNotification()
    showBreakOverlay()
}
```

**Step 3: Commit**

```bash
git add Sources/App/AppDelegate.swift
git commit -m "feat: show break overlay when work completes"
```

---

### Task 5: Run tests + manual verification

**Step 1: Run unit tests**

Run: `swift test --filter BreakPromptProviderTests`
Expected: PASS

**Step 2: Manual test**
- Start a work session, wait for completion.
- Verify overlay appears on main display, background dimmed, centered text.
- Press ESC to dismiss; re-run and wait 15s to confirm auto-dismiss.

**Step 3: Final commit (if any changes)**

```bash
git status --short
```

---

## Notes
- If `swift` isn’t available in the environment, run tests locally outside the sandbox before finalizing.
