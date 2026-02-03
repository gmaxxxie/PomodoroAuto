import AppKit

final class BreakOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class BreakOverlayWindowController: NSWindowController {
    private var dismissTimer: DispatchSourceTimer?
    private var overlayView: BreakOverlayView?
    var onDismiss: (() -> Void)?
    var onSkipBreak: (() -> Void)?

    init() {
        let window = BreakOverlayWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false
        window.hasShadow = false

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func show(title: String, message: String, footer: String, timeoutSeconds: Int = 15) {
        guard let screen = NSScreen.main else { return }

        let frame = screen.frame
        window?.setFrame(frame, display: true)

        let view = BreakOverlayView(frame: frame)
        view.configure(title: title, message: message, footer: footer)
        window?.contentView = view
        overlayView = view

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        view.animateFadeIn()

        startDismissTimer(seconds: timeoutSeconds)
    }

    func dismiss() {
        cancelDismissTimer()
        overlayView?.animateFadeOut { [weak self] in
            self?.window?.orderOut(nil)
            self?.onDismiss?()
        }
    }

    func updateCountdown(seconds: Int) {
        overlayView?.updateCountdown(seconds: seconds)
    }

    func skipBreakAndStartWork() {
        cancelDismissTimer()
        overlayView?.animateFadeOut { [weak self] in
            self?.window?.orderOut(nil)
            self?.onSkipBreak?()
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            dismiss()
        } else {
            super.keyDown(with: event)
        }
    }

    private func startDismissTimer(seconds: Int) {
        cancelDismissTimer()
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now() + .seconds(seconds))
        timer.setEventHandler { [weak self] in
            self?.dismiss()
        }
        timer.resume()
        dismissTimer = timer
    }

    private func cancelDismissTimer() {
        dismissTimer?.cancel()
        dismissTimer = nil
    }

    deinit {
        cancelDismissTimer()
    }
}
