import AppKit

final class StatsWindowController: NSWindowController, NSWindowDelegate {
    private let statsStore: StatsStore
    private var workTimeValueLabel: NSTextField?
    private var pomodoroValueLabel: NSTextField?

    init(statsStore: StatsStore) {
        self.statsStore = statsStore
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 260),
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
        pomodoroValueLabel?.stringValue = String(stats.pomodoroCount)
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        let backgroundView = NSVisualEffectView()
        backgroundView.material = .underWindowBackground
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(backgroundView)

        let cardView = NSVisualEffectView()
        cardView.material = .popover
        cardView.state = .active
        cardView.wantsLayer = true
        cardView.layer?.cornerRadius = 16
        cardView.layer?.shadowColor = NSColor.black.cgColor
        cardView.layer?.shadowOpacity = 0.15
        cardView.layer?.shadowOffset = NSSize(width: 0, height: -2)
        cardView.layer?.shadowRadius = 20
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(stack)

        let heading = createHeading(title: "Today", symbolName: "calendar")
        stack.addArrangedSubview(heading)

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        stack.addArrangedSubview(divider)

        let workRow = createStatRow(label: "Work time", symbolName: "clock")
        stack.addArrangedSubview(workRow)

        let pomodoroRow = createStatRow(label: "Pomodoros", symbolName: "checkmark.circle.fill")
        stack.addArrangedSubview(pomodoroRow)

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: contentView.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            cardView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            cardView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 30),
            cardView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -30),
            cardView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 30),
            cardView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -30),

            stack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -24)
        ])
    }

    private func createHeading(title: String, symbolName: String) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10

        let iconContainer = NSView()
        iconContainer.wantsLayer = true
        iconContainer.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        iconContainer.layer?.cornerRadius = 10
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.widthAnchor.constraint(equalToConstant: 36).isActive = true
        iconContainer.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let imageView = NSImageView()
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title) {
            image.isTemplate = true
            imageView.contentTintColor = .white
            imageView.image = image
        }
        imageView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 20),
            imageView.heightAnchor.constraint(equalToConstant: 20)
        ])

        let label = NSTextField(labelWithString: title)
        label.font = NSFont.boldSystemFont(ofSize: 16)

        stack.addArrangedSubview(iconContainer)
        stack.addArrangedSubview(label)

        return stack
    }

    private func createStatRow(label: String, symbolName: String) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12

        let iconView = NSView()
        iconView.wantsLayer = true
        iconView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        iconView.layer?.cornerRadius = 8
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 32).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 32).isActive = true

        let imageView = NSImageView()
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: label) {
            image.isTemplate = true
            imageView.image = image
        }
        imageView.translatesAutoresizingMaskIntoConstraints = false
        iconView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 18),
            imageView.heightAnchor.constraint(equalToConstant: 18)
        ])

        let labelView = NSTextField(labelWithString: label)
        labelView.font = NSFont.systemFont(ofSize: 13)
        labelView.textColor = .secondaryLabelColor

        let valueView = NSTextField(labelWithString: "--")
        valueView.font = NSFont.monospacedSystemFont(ofSize: 16, weight: .medium)
        valueView.textColor = .labelColor

        if label == "Work time" {
            workTimeValueLabel = valueView
        } else if label == "Pomodoros" {
            pomodoroValueLabel = valueView
        }

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(labelView)
        stack.addArrangedSubview(valueView)

        return stack
    }

    private func formatDuration(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let secs = clamped % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}
