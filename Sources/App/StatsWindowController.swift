import AppKit
import QuartzCore

final class StatsWindowController: NSWindowController, NSWindowDelegate {
    private let statsStore: StatsStore
    var onClose: (() -> Void)?
    private var workTimeValueLabel: NSTextField?
    private var pomodoroValueLabel: NSTextField?
    private var progressRingLayer: CAShapeLayer?
    private var motivationLabel: NSTextField?
    private var subtitleLabel: NSTextField?
    private var resetButton: NSButton?
    private var statsCardTitleLabel: NSTextField?
    private var allTimeTitleLabel: NSTextField?
    private var totalPomodorosTitleLabel: NSTextField?
    private var totalWorkTimeTitleLabel: NSTextField?
    private var avgPomodorosTitleLabel: NSTextField?
    private var avgWorkTimeTitleLabel: NSTextField?
    private var daysTrackedTitleLabel: NSTextField?
    private let dailyGoalPomodoros = 8

    private var totalPomodoroLabel: NSTextField?
    private var totalWorkTimeLabel: NSTextField?
    private var avgPomodoroLabel: NSTextField?
    private var avgWorkTimeLabel: NSTextField?
    private var dayCountLabel: NSTextField?

    init(statsStore: StatsStore) {
        self.statsStore = statsStore
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = Localization.localized("stats.title")
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

    func windowWillClose(_ notification: Notification) {
        releaseWindowResources()
        let closeHandler = onClose
        onClose = nil
        closeHandler?()
    }

    func updateStats() {
        let stats = statsStore.statsForToday()
        workTimeValueLabel?.stringValue = formatDuration(stats.workSeconds)
        pomodoroValueLabel?.stringValue = "\(stats.pomodoroCount)"

        let progress = min(1.0, CGFloat(stats.pomodoroCount) / CGFloat(dailyGoalPomodoros))
        updateProgressRing(progress: progress)
        updateMotivation(pomodoroCount: stats.pomodoroCount)

        let total = statsStore.totalStats()
        totalPomodoroLabel?.stringValue = "\(total.pomodoroCount)"
        totalWorkTimeLabel?.stringValue = formatDuration(total.workSeconds)

        let avg = statsStore.averageStats()
        avgPomodoroLabel?.stringValue = String(format: "%.1f", avg.avgPomodoroCount)
        avgWorkTimeLabel?.stringValue = formatDuration(Int(avg.avgWorkSeconds))
        dayCountLabel?.stringValue = "\(avg.dayCount)"
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

        let allTimeCard = createAllTimeCard()
        mainStack.addArrangedSubview(allTimeCard)

        let motivation = NSTextField(labelWithString: Localization.localized("stats.keepGoing"))
        motivation.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        motivation.textColor = .secondaryLabelColor
        motivation.alignment = .center
        motivationLabel = motivation
        mainStack.addArrangedSubview(motivation)

        let resetButton = NSButton(title: Localization.localized("stats.resetAll"), target: self, action: #selector(resetButtonClicked))
        resetButton.bezelStyle = .rounded
        resetButton.controlSize = .regular
        resetButton.contentTintColor = .systemRed
        self.resetButton = resetButton
        mainStack.addArrangedSubview(resetButton)

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

        let subtitleLabel = NSTextField(labelWithString: Localization.localized("stats.subtitle.pomodoros"))
        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        subtitleLabel.textColor = .tertiaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(subtitleLabel)
        self.subtitleLabel = subtitleLabel

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

        let labelView = NSTextField(labelWithString: Localization.localized("stats.totalWorkTime"))
        labelView.font = NSFont.systemFont(ofSize: 12)
        labelView.textColor = .secondaryLabelColor
        statsCardTitleLabel = labelView

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
            message = Localization.localized("stats.motivation.start")
        } else if pomodoroCount < dailyGoalPomodoros / 2 {
            message = Localization.localized("stats.motivation.goodStart")
        } else if pomodoroCount < dailyGoalPomodoros {
            message = Localization.localized("stats.motivation.halfway")
        } else if pomodoroCount == dailyGoalPomodoros {
            message = Localization.localized("stats.motivation.goal")
        } else {
            message = Localization.localized("stats.motivation.above")
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

    private func createAllTimeCard() -> NSView {
        let card = NSVisualEffectView()
        card.material = .popover
        card.state = .active
        card.wantsLayer = true
        card.layer?.cornerRadius = 14
        card.translatesAutoresizingMaskIntoConstraints = false

        let outerStack = NSStackView()
        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.spacing = 12
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(outerStack)

        let titleLabel = NSTextField(labelWithString: Localization.localized("stats.allTime"))
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor
        allTimeTitleLabel = titleLabel
        outerStack.addArrangedSubview(titleLabel)

        let gridStack = NSStackView()
        gridStack.orientation = .vertical
        gridStack.alignment = .leading
        gridStack.spacing = 8

        let totalPomodoroRow = createStatRow(
            symbolName: "checkmark.circle.fill",
            color: .systemGreen,
            label: Localization.localized("stats.totalPomodoros"),
            value: "0"
        )
        totalPomodoroLabel = totalPomodoroRow.valueLabel
        totalPomodorosTitleLabel = totalPomodoroRow.titleLabel
        gridStack.addArrangedSubview(totalPomodoroRow.view)

        let totalWorkRow = createStatRow(
            symbolName: "clock.fill",
            color: .systemBlue,
            label: Localization.localized("stats.totalWorkTimeAll"),
            value: "--:--"
        )
        totalWorkTimeLabel = totalWorkRow.valueLabel
        totalWorkTimeTitleLabel = totalWorkRow.titleLabel
        gridStack.addArrangedSubview(totalWorkRow.view)

        let avgPomodoroRow = createStatRow(
            symbolName: "chart.bar.fill",
            color: .systemOrange,
            label: Localization.localized("stats.avgPomodorosPerDay"),
            value: "0.0"
        )
        avgPomodoroLabel = avgPomodoroRow.valueLabel
        avgPomodorosTitleLabel = avgPomodoroRow.titleLabel
        gridStack.addArrangedSubview(avgPomodoroRow.view)

        let avgWorkRow = createStatRow(
            symbolName: "hourglass",
            color: .systemPurple,
            label: Localization.localized("stats.avgWorkTimePerDay"),
            value: "--:--"
        )
        avgWorkTimeLabel = avgWorkRow.valueLabel
        avgWorkTimeTitleLabel = avgWorkRow.titleLabel
        gridStack.addArrangedSubview(avgWorkRow.view)

        let dayCountRow = createStatRow(
            symbolName: "calendar",
            color: .systemTeal,
            label: Localization.localized("stats.daysTracked"),
            value: "0"
        )
        dayCountLabel = dayCountRow.valueLabel
        daysTrackedTitleLabel = dayCountRow.titleLabel
        gridStack.addArrangedSubview(dayCountRow.view)

        outerStack.addArrangedSubview(gridStack)

        NSLayoutConstraint.activate([
            outerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            outerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            outerStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            outerStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            card.widthAnchor.constraint(greaterThanOrEqualToConstant: 220)
        ])

        return card
    }

    private func createStatRow(
        symbolName: String,
        color: NSColor,
        label: String,
        value: String
    ) -> (view: NSView, titleLabel: NSTextField, valueLabel: NSTextField) {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10

        let iconContainer = NSView()
        iconContainer.wantsLayer = true
        iconContainer.layer?.backgroundColor = color.withAlphaComponent(0.15).cgColor
        iconContainer.layer?.cornerRadius = 6
        iconContainer.translatesAutoresizingMaskIntoConstraints = false

        let imageView = NSImageView()
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            image.isTemplate = true
            imageView.image = image
            imageView.contentTintColor = color
        }
        imageView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(imageView)

        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 24),
            iconContainer.heightAnchor.constraint(equalToConstant: 24),
            imageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 12),
            imageView.heightAnchor.constraint(equalToConstant: 12)
        ])

        row.addArrangedSubview(iconContainer)

        let labelField = NSTextField(labelWithString: label)
        labelField.font = NSFont.systemFont(ofSize: 12)
        labelField.textColor = .secondaryLabelColor
        row.addArrangedSubview(labelField)

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)

        let valueField = NSTextField(labelWithString: value)
        valueField.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        valueField.textColor = .labelColor
        valueField.alignment = .right
        row.addArrangedSubview(valueField)

        return (row, labelField, valueField)
    }

    @objc private func resetButtonClicked() {
        guard let window = self.window else { return }

        let alert = NSAlert()
        alert.messageText = Localization.localized("stats.reset.alert.title")
        alert.informativeText = Localization.localized("stats.reset.alert.body")
        alert.alertStyle = .warning
        alert.addButton(withTitle: Localization.localized("stats.reset.alert.reset"))
        alert.addButton(withTitle: Localization.localized("stats.reset.alert.cancel"))

        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self = self else { return }
            if response == .alertFirstButtonReturn {
                self.statsStore.clearAll()
                self.updateStats()
            }
        }
    }

    func applyLocalization() {
        window?.title = Localization.localized("stats.title")
        subtitleLabel?.stringValue = Localization.localized("stats.subtitle.pomodoros")
        statsCardTitleLabel?.stringValue = Localization.localized("stats.totalWorkTime")
        allTimeTitleLabel?.stringValue = Localization.localized("stats.allTime")
        totalPomodorosTitleLabel?.stringValue = Localization.localized("stats.totalPomodoros")
        totalWorkTimeTitleLabel?.stringValue = Localization.localized("stats.totalWorkTimeAll")
        avgPomodorosTitleLabel?.stringValue = Localization.localized("stats.avgPomodorosPerDay")
        avgWorkTimeTitleLabel?.stringValue = Localization.localized("stats.avgWorkTimePerDay")
        daysTrackedTitleLabel?.stringValue = Localization.localized("stats.daysTracked")
        resetButton?.title = Localization.localized("stats.resetAll")
        updateMotivation(pomodoroCount: statsStore.statsForToday().pomodoroCount)
    }

    private func releaseWindowResources() {
        window?.delegate = nil
        progressRingLayer?.removeAllAnimations()
        progressRingLayer?.removeFromSuperlayer()
        progressRingLayer = nil

        workTimeValueLabel = nil
        pomodoroValueLabel = nil
        motivationLabel = nil
        subtitleLabel = nil
        resetButton = nil
        statsCardTitleLabel = nil
        allTimeTitleLabel = nil
        totalPomodorosTitleLabel = nil
        totalWorkTimeTitleLabel = nil
        avgPomodorosTitleLabel = nil
        avgWorkTimeTitleLabel = nil
        daysTrackedTitleLabel = nil
        totalPomodoroLabel = nil
        totalWorkTimeLabel = nil
        avgPomodoroLabel = nil
        avgWorkTimeLabel = nil
        dayCountLabel = nil

        window?.contentView?.subviews.forEach { $0.removeFromSuperview() }
    }
}
