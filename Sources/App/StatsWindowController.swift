import AppKit
import QuartzCore

final class StatsWindowController: NSWindowController, NSWindowDelegate {
    private let statsStore: StatsStore
    private var workTimeValueLabel: NSTextField?
    private var pomodoroValueLabel: NSTextField?
    private var progressRingLayer: CAShapeLayer?
    private var motivationLabel: NSTextField?
    private let dailyGoalPomodoros = 8

    init(statsStore: StatsStore) {
        self.statsStore = statsStore
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 380),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Stats"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.titleVisibility = .hidden

        if #available(macOS 11.0, *) {
            window.styleMask.insert(.fullSizeContentView)
            window.level = .floating
        }

        super.init(window: window)
        window.delegate = self
        buildContent()
        updateStats()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func windowDidBecomeKey(_ notification: Notification) {
        updateStats()
    }

    func updateStats() {
        let stats = statsStore.statsForToday()
        workTimeValueLabel?.stringValue = formatDuration(stats.workSeconds)
        pomodoroValueLabel?.stringValue = "\(stats.pomodoroCount)"

        let progress = min(1.0, CGFloat(stats.pomodoroCount) / CGFloat(dailyGoalPomodoros))
        updateProgressRing(progress: progress)
        updateMotivation(pomodoroCount: stats.pomodoroCount)
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        let backgroundView = NSVisualEffectView()
        backgroundView.material = .underWindowBackground
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(backgroundView)

        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.alignment = .centerX
        mainStack.spacing = 24
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)

        let progressRingView = createProgressRing()
        mainStack.addArrangedSubview(progressRingView)

        let statsCard = createStatsCard()
        mainStack.addArrangedSubview(statsCard)

        let motivation = NSTextField(labelWithString: "Keep going!")
        motivation.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        motivation.textColor = .secondaryLabelColor
        motivation.alignment = .center
        motivationLabel = motivation
        mainStack.addArrangedSubview(motivation)

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: contentView.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            mainStack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            mainStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            mainStack.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 24),
            mainStack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -24)
        ])
    }

    private func createProgressRing() -> NSView {
        let size: CGFloat = 140
        let lineWidth: CGFloat = 10

        let container = NSView()
        container.wantsLayer = true
        container.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: size),
            container.heightAnchor.constraint(equalToConstant: size)
        ])

        let center = CGPoint(x: size / 2, y: size / 2)
        let radius = (size - lineWidth) / 2

        let bgPath = CGMutablePath()
        bgPath.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)

        let bgLayer = CAShapeLayer()
        bgLayer.path = bgPath
        bgLayer.fillColor = nil
        bgLayer.strokeColor = NSColor.tertiaryLabelColor.cgColor
        bgLayer.lineWidth = lineWidth
        bgLayer.lineCap = .round
        bgLayer.frame = CGRect(x: 0, y: 0, width: size, height: size)
        container.layer?.addSublayer(bgLayer)

        let progressPath = CGMutablePath()
        progressPath.addArc(center: center, radius: radius, startAngle: .pi / 2, endAngle: -.pi * 1.5, clockwise: true)

        let progressLayer = CAShapeLayer()
        progressLayer.path = progressPath
        progressLayer.fillColor = nil
        progressLayer.strokeColor = NSColor.systemGreen.cgColor
        progressLayer.lineWidth = lineWidth
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0
        progressLayer.frame = CGRect(x: 0, y: 0, width: size, height: size)
        container.layer?.addSublayer(progressLayer)
        progressRingLayer = progressLayer

        let centerLabel = NSTextField(labelWithString: "0/\(dailyGoalPomodoros)")
        centerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 24, weight: .bold)
        centerLabel.textColor = .labelColor
        centerLabel.alignment = .center
        centerLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(centerLabel)
        pomodoroValueLabel = centerLabel

        let subtitleLabel = NSTextField(labelWithString: "pomodoros")
        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        subtitleLabel.textColor = .tertiaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            centerLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            centerLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -8),
            subtitleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: centerLabel.bottomAnchor, constant: 2)
        ])

        return container
    }

    private func createStatsCard() -> NSView {
        let card = NSVisualEffectView()
        card.material = .popover
        card.state = .active
        card.wantsLayer = true
        card.layer?.cornerRadius = 14
        card.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let iconView = createStatIcon(symbolName: "clock.fill", color: .systemBlue)
        stack.addArrangedSubview(iconView)

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        let labelView = NSTextField(labelWithString: "Total work time")
        labelView.font = NSFont.systemFont(ofSize: 12)
        labelView.textColor = .secondaryLabelColor

        let valueView = NSTextField(labelWithString: "--:--")
        valueView.font = NSFont.monospacedDigitSystemFont(ofSize: 20, weight: .semibold)
        valueView.textColor = .labelColor
        workTimeValueLabel = valueView

        textStack.addArrangedSubview(labelView)
        textStack.addArrangedSubview(valueView)
        stack.addArrangedSubview(textStack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            card.widthAnchor.constraint(greaterThanOrEqualToConstant: 220)
        ])

        return card
    }

    private func createStatIcon(symbolName: String, color: NSColor) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = color.withAlphaComponent(0.15).cgColor
        container.layer?.cornerRadius = 10
        container.translatesAutoresizingMaskIntoConstraints = false

        let imageView = NSImageView()
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            image.isTemplate = true
            imageView.image = image
            imageView.contentTintColor = color
        }
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 40),
            container.heightAnchor.constraint(equalToConstant: 40),
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 20),
            imageView.heightAnchor.constraint(equalToConstant: 20)
        ])

        return container
    }

    private func updateProgressRing(progress: CGFloat) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.5)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        progressRingLayer?.strokeEnd = progress

        let color: NSColor
        if progress >= 1.0 {
            color = .systemGreen
        } else if progress >= 0.5 {
            color = .systemBlue
        } else if progress > 0 {
            color = .systemOrange
        } else {
            color = .tertiaryLabelColor
        }
        progressRingLayer?.strokeColor = color.cgColor
        CATransaction.commit()
    }

    private func updateMotivation(pomodoroCount: Int) {
        let message: String
        if pomodoroCount == 0 {
            message = "Start your first pomodoro!"
        } else if pomodoroCount < dailyGoalPomodoros / 2 {
            message = "Good start! Keep it up!"
        } else if pomodoroCount < dailyGoalPomodoros {
            message = "Halfway there! You're doing great!"
        } else if pomodoroCount == dailyGoalPomodoros {
            message = "Goal achieved! Amazing work!"
        } else {
            message = "Above and beyond! You're on fire!"
        }
        motivationLabel?.stringValue = message

        pomodoroValueLabel?.stringValue = "\(pomodoroCount)/\(dailyGoalPomodoros)"
    }

    private func formatDuration(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let secs = clamped % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}
