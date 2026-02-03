import AppKit

final class BreakOverlayView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let countdownLabel = NSTextField(labelWithString: "")
    private let messageLabel = NSTextField(labelWithString: "")
    private let footerLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.75).cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        configureTitleLabel()
        configureCountdownLabel()
        configureMessageLabel()
        configureFooterLabel()

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(countdownLabel)
        stack.addArrangedSubview(messageLabel)
        stack.addArrangedSubview(footerLabel)

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.8)
        ])
    }

    private func configureTitleLabel() {
        titleLabel.font = NSFont.systemFont(ofSize: 48, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.maximumNumberOfLines = 2
    }

    private func configureCountdownLabel() {
        countdownLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 72, weight: .light)
        countdownLabel.textColor = NSColor.white.withAlphaComponent(0.95)
        countdownLabel.alignment = .center
    }

    private func configureMessageLabel() {
        messageLabel.font = NSFont.systemFont(ofSize: 24, weight: .regular)
        messageLabel.textColor = NSColor.white.withAlphaComponent(0.9)
        messageLabel.alignment = .center
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.maximumNumberOfLines = 3
    }

    private func configureFooterLabel() {
        footerLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        footerLabel.textColor = NSColor.white.withAlphaComponent(0.5)
        footerLabel.alignment = .center
    }

    func configure(title: String, message: String, footer: String) {
        titleLabel.stringValue = title
        messageLabel.stringValue = message
        footerLabel.stringValue = footer
    }

    func updateCountdown(seconds: Int) {
        let minutes = seconds / 60
        let secs = seconds % 60
        countdownLabel.stringValue = String(format: "%02d:%02d", minutes, secs)
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
