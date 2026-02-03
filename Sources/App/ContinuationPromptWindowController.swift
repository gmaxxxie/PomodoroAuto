import AppKit

final class ContinuationPromptWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class ContinuationPromptWindowController: NSWindowController {
    var onStartNext: (() -> Void)?
    var onStop: (() -> Void)?

    init() {
        let window = ContinuationPromptWindow(
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

    func show(title: String, message: String, startNextTitle: String, stopTitle: String) {
        guard let screen = NSScreen.main else { return }

        let frame = screen.frame
        window?.setFrame(frame, display: true)

        let view = ContinuationPromptView(frame: frame)
        view.configure(
            title: title,
            message: message,
            startNextTitle: startNextTitle,
            stopTitle: stopTitle,
            onStartNext: { [weak self] in
                self?.handleStartNext()
            },
            onStop: { [weak self] in
                self?.handleStop()
            }
        )
        window?.contentView = view

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        view.animateFadeIn()
    }

    func dismiss(completion: (() -> Void)? = nil) {
        guard let view = window?.contentView as? ContinuationPromptView else {
            window?.orderOut(nil)
            completion?()
            return
        }
        view.animateFadeOut { [weak self] in
            self?.window?.orderOut(nil)
            completion?()
        }
    }

    private func handleStartNext() {
        let callback = onStartNext
        dismiss { callback?() }
    }

    private func handleStop() {
        let callback = onStop
        dismiss { callback?() }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            handleStop()
        } else if event.keyCode == 36 || event.keyCode == 49 {
            handleStartNext()
        } else {
            super.keyDown(with: event)
        }
    }
}

final class ContinuationPromptView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let messageLabel = NSTextField(labelWithString: "")
    private let startNextButton = NSButton()
    private let stopButton = NSButton()
    private var onStartNext: (() -> Void)?
    private var onStop: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false

        configureTitleLabel()
        configureMessageLabel()
        configureButtons()

        let buttonStack = NSStackView(views: [startNextButton, stopButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 16

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(messageLabel)
        stack.addArrangedSubview(buttonStack)

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.8),
            startNextButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            startNextButton.heightAnchor.constraint(equalToConstant: 44),
            stopButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            stopButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func configureTitleLabel() {
        titleLabel.font = NSFont.systemFont(ofSize: 48, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.maximumNumberOfLines = 2
    }

    private func configureMessageLabel() {
        messageLabel.font = NSFont.systemFont(ofSize: 24, weight: .regular)
        messageLabel.textColor = NSColor.white.withAlphaComponent(0.9)
        messageLabel.alignment = .center
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.maximumNumberOfLines = 3
    }

    private func configureButtons() {
        startNextButton.bezelStyle = .rounded
        startNextButton.isBordered = true
        startNextButton.wantsLayer = true
        startNextButton.layer?.backgroundColor = NSColor.systemGreen.cgColor
        startNextButton.layer?.cornerRadius = 8
        startNextButton.contentTintColor = .white
        startNextButton.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        startNextButton.target = self
        startNextButton.action = #selector(startNextTapped)

        stopButton.bezelStyle = .rounded
        stopButton.isBordered = true
        stopButton.wantsLayer = true
        stopButton.layer?.backgroundColor = NSColor.systemGray.cgColor
        stopButton.layer?.cornerRadius = 8
        stopButton.contentTintColor = .white
        stopButton.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        stopButton.target = self
        stopButton.action = #selector(stopTapped)
    }

    func configure(
        title: String,
        message: String,
        startNextTitle: String,
        stopTitle: String,
        onStartNext: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) {
        titleLabel.stringValue = title
        messageLabel.stringValue = message
        startNextButton.title = startNextTitle
        stopButton.title = stopTitle
        self.onStartNext = onStartNext
        self.onStop = onStop
    }

    @objc private func startNextTapped() {
        onStartNext?()
    }

    @objc private func stopTapped() {
        onStop?()
    }

    func animateFadeIn(duration: TimeInterval = 0.3) {
        alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
        }
    }

    func animateFadeOut(duration: TimeInterval = 0.2, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: completion)
    }
}
