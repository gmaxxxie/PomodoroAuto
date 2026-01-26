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
        guard let window = window, window.frame != .zero else { return }
        window.contentView = BreakOverlayView(title: title, message: message, footer: footer)
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
        let resolvedScreen = screen ?? NSScreen.screens.first
        let frame = resolvedScreen?.frame ?? .zero
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: resolvedScreen
        )
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
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
