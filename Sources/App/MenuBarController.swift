import AppKit
import QuartzCore

final class MenuBarController: NSObject, NSMenuDelegate {
    enum TimerMode {
        case idle
        case work
        case rest
        case paused
    }

    struct TodayStats {
        var pomodoroCount: Int
        var workSeconds: Int
    }

    var onToggle: (() -> Void)?
    var onReset: (() -> Void)?
    var onOpenStats: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?
    var statsProvider: (() -> TodayStats)?

    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private let statusTitleItem = NSMenuItem(title: "Idle", action: nil, keyEquivalent: "")
    private let pomodoroStatsItem = NSMenuItem(title: "🍅 0 pomodoros", action: nil, keyEquivalent: "")
    private let workTimeStatsItem = NSMenuItem(title: "⏱ 00:00", action: nil, keyEquivalent: "")
    private var currentMode: TimerMode = .idle
    private var totalDuration: Int = 25 * 60
    private var progressLayer: CAShapeLayer?
    private var backgroundLayer: CAShapeLayer?

    init(
        onToggle: (() -> Void)? = nil,
        onReset: (() -> Void)? = nil,
        onOpenStats: (() -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil,
        onQuit: (() -> Void)? = nil,
        statsProvider: (() -> TodayStats)? = nil
    ) {
        self.onToggle = onToggle
        self.onReset = onReset
        self.onOpenStats = onOpenStats
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
        self.statsProvider = statsProvider
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.menu = NSMenu()
        super.init()
        buildMenu()
        configureStatusItem()
        setupProgressRing()
        menu.delegate = self
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        refreshStats()
    }

    func refreshStats() {
        guard let stats = statsProvider?() else { return }
        pomodoroStatsItem.title = "  \(stats.pomodoroCount) pomodoro\(stats.pomodoroCount == 1 ? "" : "s")"
        workTimeStatsItem.title = "  \(formatDuration(stats.workSeconds))"
    }

    private func formatDuration(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        return String(format: "%dm", minutes)
    }

    func setTotalDuration(seconds: Int) {
        totalDuration = max(1, seconds)
    }

    func setRemaining(seconds: Int, label: String = "Remaining", isBreak: Bool = false) {
        let minutes = seconds / 60
        let secs = seconds % 60
        let text = String(format: "%02d:%02d", minutes, secs)
        statusItem.button?.title = text
        statusTitleItem.title = "\(label): \(text)"
        currentMode = isBreak ? .rest : .work
        updateStatusIcon(isRunning: true)
        updateProgressRing(remaining: seconds)
    }

    func setStatus(text: String) {
        statusItem.button?.title = ""
        statusTitleItem.title = text
        if text == "Paused" {
            currentMode = .paused
        } else {
            currentMode = .idle
        }
        updateStatusIcon(isRunning: false)
        updateProgressRing(remaining: 0)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.title = ""
        updateStatusIcon(isRunning: false)
    }

    private func updateStatusIcon(isRunning: Bool) {
        guard let button = statusItem.button else { return }
        let symbolName: String
        let tintColor: NSColor

        switch currentMode {
        case .work:
            symbolName = "timer.circle.fill"
            tintColor = NSColor.systemGreen
        case .rest:
            symbolName = "cup.and.saucer.fill"
            tintColor = NSColor.systemBlue
        case .paused:
            symbolName = "pause.circle.fill"
            tintColor = NSColor.systemOrange
        case .idle:
            symbolName = "timer.circle"
            tintColor = NSColor.secondaryLabelColor
        }

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Pomodoro") {
            image.isTemplate = false
            button.contentTintColor = tintColor
            button.image = image
        }
    }

    private func setupProgressRing() {
        guard let button = statusItem.button else { return }
        button.wantsLayer = true

        let size: CGFloat = 18
        let lineWidth: CGFloat = 2.5
        let center = CGPoint(x: size / 2, y: size / 2)
        let radius = (size - lineWidth) / 2

        let circlePath = CGPath(
            ellipseIn: CGRect(x: lineWidth / 2, y: lineWidth / 2, width: size - lineWidth, height: size - lineWidth),
            transform: nil
        )

        let bgLayer = CAShapeLayer()
        bgLayer.path = circlePath
        bgLayer.fillColor = nil
        bgLayer.strokeColor = NSColor.tertiaryLabelColor.cgColor
        bgLayer.lineWidth = lineWidth
        bgLayer.frame = CGRect(x: 0, y: 0, width: size, height: size)
        bgLayer.isHidden = true
        backgroundLayer = bgLayer

        let progressPath = CGMutablePath()
        progressPath.addArc(center: center, radius: radius, startAngle: .pi / 2, endAngle: -.pi * 1.5, clockwise: true)

        let progLayer = CAShapeLayer()
        progLayer.path = progressPath
        progLayer.fillColor = nil
        progLayer.strokeColor = NSColor.systemGreen.cgColor
        progLayer.lineWidth = lineWidth
        progLayer.lineCap = .round
        progLayer.strokeEnd = 0
        progLayer.frame = CGRect(x: 0, y: 0, width: size, height: size)
        progLayer.isHidden = true
        progressLayer = progLayer
    }

    private func updateProgressRing(remaining: Int) {
        let progress: CGFloat
        if remaining > 0 && totalDuration > 0 {
            progress = CGFloat(remaining) / CGFloat(totalDuration)
            progressLayer?.isHidden = false
            backgroundLayer?.isHidden = false
        } else {
            progress = 0
            progressLayer?.isHidden = true
            backgroundLayer?.isHidden = true
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        progressLayer?.strokeEnd = progress

        let color: NSColor
        switch currentMode {
        case .work:
            color = .systemGreen
        case .rest:
            color = .systemBlue
        case .paused:
            color = .systemOrange
        case .idle:
            color = .secondaryLabelColor
        }
        progressLayer?.strokeColor = color.cgColor
        CATransaction.commit()
    }

    private func buildMenu() {
        menu.addItem(statusTitleItem)
        menu.addItem(.separator())

        let pomodoroIcon = NSImage(systemSymbolName: "target", accessibilityDescription: "Pomodoros")
        pomodoroIcon?.isTemplate = true
        pomodoroStatsItem.image = pomodoroIcon
        pomodoroStatsItem.isEnabled = false
        menu.addItem(pomodoroStatsItem)

        let clockIcon = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "Work time")
        clockIcon?.isTemplate = true
        workTimeStatsItem.image = clockIcon
        workTimeStatsItem.isEnabled = false
        menu.addItem(workTimeStatsItem)

        menu.addItem(.separator())

        let toggleItem = createMenuItem(
            title: "Start/Pause",
            symbolName: "playpause.circle.fill",
            keyEquivalent: " ",
            action: #selector(handleToggle)
        )
        menu.addItem(toggleItem)

        let resetItem = createMenuItem(
            title: "Reset",
            symbolName: "arrow.counterclockwise.circle.fill",
            keyEquivalent: "r",
            action: #selector(handleReset)
        )
        menu.addItem(resetItem)

        menu.addItem(.separator())

        let statsItem = createMenuItem(
            title: "Stats",
            symbolName: "chart.bar.fill",
            keyEquivalent: "s",
            action: #selector(handleStats)
        )
        menu.addItem(statsItem)

        let settingsItem = createMenuItem(
            title: "Settings",
            symbolName: "gearshape.fill",
            keyEquivalent: ",",
            action: #selector(handleSettings)
        )
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = createMenuItem(
            title: "Quit",
            symbolName: "power",
            keyEquivalent: "q",
            action: #selector(handleQuit)
        )
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func createMenuItem(title: String, symbolName: String, keyEquivalent: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title) {
            image.isTemplate = true
            image.size = NSSize(width: 16, height: 16)
            item.image = image
        }
        return item
    }

    @objc private func handleToggle() {
        onToggle?()
    }

    @objc private func handleReset() {
        onReset?()
    }

    @objc private func handleSettings() {
        onOpenSettings?()
    }

    @objc private func handleStats() {
        onOpenStats?()
    }

    @objc private func handleQuit() {
        onQuit?()
    }
}
