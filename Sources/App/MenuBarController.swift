import AppKit
import QuartzCore

final class MenuBarController: NSObject, NSMenuDelegate {
    private enum Layout {
        static let iconSize: CGFloat = 19
        static let ringLineWidth: CGFloat = 2
        static let iconInset: CGFloat = 3
    }

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
    private let customStatusIconLoader: () -> NSImage?
    private let systemSymbolLoader: (String, String) -> NSImage?
    private let statusTitleItem = NSMenuItem(title: Localization.localized("menu.status.idle"), action: nil, keyEquivalent: "")
    private let pomodoroStatsItem = NSMenuItem(title: "🍅 0", action: nil, keyEquivalent: "")
    private let workTimeStatsItem = NSMenuItem(title: "⏱ 00:00", action: nil, keyEquivalent: "")
    private var toggleItem: NSMenuItem?
    private var resetItem: NSMenuItem?
    private var statsItem: NSMenuItem?
    private var settingsItem: NSMenuItem?
    private var quitItem: NSMenuItem?
    private var currentMode: TimerMode = .idle
    private var totalDuration: Int = 25 * 60
    private var progressLayer: CAShapeLayer?
    private var backgroundLayer: CAShapeLayer?
    private static func loadBundledStatusIcon() -> NSImage? {
        guard let url = Bundle.module.url(forResource: "menubar-icon-template", withExtension: "pdf"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        return image
    }

    private static func makeFallbackStatusIcon(size: CGFloat) -> NSImage? {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.white.setFill()

        let circleDiameter = size * 0.64
        let circleRect = NSRect(
            x: (size - circleDiameter) / 2,
            y: size * 0.12,
            width: circleDiameter,
            height: circleDiameter
        )
        NSBezierPath(ovalIn: circleRect).fill()

        let leafPath = NSBezierPath()
        leafPath.move(to: NSPoint(x: size * 0.50, y: size * 0.92))
        leafPath.curve(to: NSPoint(x: size * 0.34, y: size * 0.74), controlPoint1: NSPoint(x: size * 0.42, y: size * 0.92), controlPoint2: NSPoint(x: size * 0.35, y: size * 0.84))
        leafPath.curve(to: NSPoint(x: size * 0.50, y: size * 0.72), controlPoint1: NSPoint(x: size * 0.39, y: size * 0.77), controlPoint2: NSPoint(x: size * 0.45, y: size * 0.75))
        leafPath.curve(to: NSPoint(x: size * 0.66, y: size * 0.74), controlPoint1: NSPoint(x: size * 0.55, y: size * 0.75), controlPoint2: NSPoint(x: size * 0.61, y: size * 0.77))
        leafPath.curve(to: NSPoint(x: size * 0.50, y: size * 0.92), controlPoint1: NSPoint(x: size * 0.65, y: size * 0.84), controlPoint2: NSPoint(x: size * 0.58, y: size * 0.92))
        leafPath.close()
        leafPath.fill()

        image.isTemplate = false
        return image
    }

    private lazy var menuBarIcon: NSImage? = {
        guard let image = customStatusIconLoader() else {
            return nil
        }
        image.isTemplate = false
        image.size = NSSize(width: Layout.iconSize, height: Layout.iconSize)
        return image
    }()

    init(
        onToggle: (() -> Void)? = nil,
        onReset: (() -> Void)? = nil,
        onOpenStats: (() -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil,
        onQuit: (() -> Void)? = nil,
        statsProvider: (() -> TodayStats)? = nil,
        customStatusIconLoader: @escaping () -> NSImage? = MenuBarController.loadBundledStatusIcon,
        systemSymbolLoader: @escaping (String, String) -> NSImage? = { name, description in
            NSImage(systemSymbolName: name, accessibilityDescription: description)
        }
    ) {
        self.onToggle = onToggle
        self.onReset = onReset
        self.onOpenStats = onOpenStats
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
        self.statsProvider = statsProvider
        self.customStatusIconLoader = customStatusIconLoader
        self.systemSymbolLoader = systemSymbolLoader
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.menu = NSMenu()
        super.init()
        buildMenu()
        configureStatusItem()
        setupProgressRing()
        menu.delegate = self
        refreshLocalizedStrings()
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        refreshStats()
    }

    func refreshStats() {
        guard let stats = statsProvider?() else { return }
        pomodoroStatsItem.title = "  \(Localization.localizedFormat("menu.stats.pomodoros", stats.pomodoroCount))"
        workTimeStatsItem.title = "  \(Localization.localizedFormat("menu.stats.workTime", formatDuration(stats.workSeconds)))"
    }

    private func formatDuration(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        if hours > 0 {
            return Localization.localizedFormat("menu.duration.hoursMinutes", hours, minutes)
        }
        return Localization.localizedFormat("menu.duration.minutes", minutes)
    }

    func setTotalDuration(seconds: Int) {
        totalDuration = max(1, seconds)
    }

    func setRemaining(seconds: Int, label: String? = nil, isBreak: Bool = false) {
        let minutes = seconds / 60
        let secs = seconds % 60
        let text = String(format: "%02d:%02d", minutes, secs)
        setStatusButtonTitle(text)
        let resolvedLabel = label ?? Localization.localized("menu.status.remaining")
        statusTitleItem.title = "\(resolvedLabel): \(text)"
        currentMode = isBreak ? .rest : .work
        updateStatusIcon(isRunning: true)
        updateProgressRing(remaining: seconds)
    }

    func setStatus(text: String, mode: TimerMode) {
        setStatusButtonTitle("")
        statusTitleItem.title = text
        currentMode = mode
        updateStatusIcon(isRunning: false)
        updateProgressRing(remaining: 0)
    }

    private func configureStatusItem() {
        guard statusItem.button != nil else { return }
        setStatusButtonTitle("")
        updateStatusIcon(isRunning: false)
    }

    private func setStatusButtonTitle(_ text: String) {
        guard let button = statusItem.button else { return }
        button.title = text
        if #available(macOS 10.14, *) {
            button.attributedTitle = NSAttributedString(
                string: text,
                attributes: [.foregroundColor: NSColor.white]
            )
        }
    }

    private func updateStatusIcon(isRunning: Bool) {
        guard let button = statusItem.button else { return }

        if let icon = menuBarIcon {
            button.image = icon
            button.imagePosition = .imageLeading
        } else if let icon = systemSymbolLoader("timer.circle", Localization.localized("menu.accessibility.pomodoro")) {
            icon.isTemplate = true
            icon.size = NSSize(width: Layout.iconSize, height: Layout.iconSize)
            button.image = icon
            button.imagePosition = .imageLeading
        } else if let icon = Self.makeFallbackStatusIcon(size: Layout.iconSize) {
            button.image = icon
            button.imagePosition = .imageLeading
        } else {
            button.image = nil
            setStatusButtonTitle("")
        }

        if #available(macOS 10.14, *) {
            button.contentTintColor = .white
        }
    }

    private func setupProgressRing() {
        guard let button = statusItem.button else { return }
        button.wantsLayer = true

        let size: CGFloat = Layout.iconSize
        let lineWidth: CGFloat = Layout.ringLineWidth
        let center = CGPoint(x: size / 2, y: size / 2)
        let radius = (size - lineWidth) / 2

        let circlePath = CGPath(
            ellipseIn: CGRect(x: lineWidth / 2, y: lineWidth / 2, width: size - lineWidth, height: size - lineWidth),
            transform: nil
        )

        let bgLayer = CAShapeLayer()
        bgLayer.path = circlePath
        bgLayer.fillColor = nil
        bgLayer.strokeColor = NSColor.tertiaryLabelColor.withAlphaComponent(0.3).cgColor
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
        
        button.layer?.addSublayer(bgLayer)
        button.layer?.addSublayer(progLayer)
        
        updateProgressRingPosition()
    }
    
    private func updateProgressRingPosition() {
        guard let button = statusItem.button,
              let bgLayer = backgroundLayer,
              let progLayer = progressLayer else { return }
        
        button.layoutSubtreeIfNeeded()
        
        let buttonBounds = button.bounds
        let ringSize: CGFloat = Layout.iconSize
        
        var xOffset: CGFloat = Layout.iconInset
        if let cell = button.cell as? NSButtonCell {
            let imageRect = cell.imageRect(forBounds: buttonBounds)
            if imageRect.width > 0 && imageRect.origin.x >= 0 {
                xOffset = imageRect.origin.x + (imageRect.width - ringSize) / 2
            }
        }
        let yOffset = (buttonBounds.height - ringSize) / 2
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bgLayer.frame.origin = CGPoint(x: xOffset, y: yOffset)
        progLayer.frame.origin = CGPoint(x: xOffset, y: yOffset)
        CATransaction.commit()
    }

    private func updateProgressRing(remaining: Int) {
        updateProgressRingPosition()
        
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

        let pomodoroIcon = NSImage(systemSymbolName: "target", accessibilityDescription: Localization.localized("menu.accessibility.pomodoros"))
        pomodoroIcon?.isTemplate = true
        pomodoroStatsItem.image = pomodoroIcon
        pomodoroStatsItem.isEnabled = false
        menu.addItem(pomodoroStatsItem)

        let clockIcon = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: Localization.localized("menu.accessibility.workTime"))
        clockIcon?.isTemplate = true
        workTimeStatsItem.image = clockIcon
        workTimeStatsItem.isEnabled = false
        menu.addItem(workTimeStatsItem)

        menu.addItem(.separator())

        let toggleItem = createMenuItem(
            title: Localization.localized("menu.title.startPause"),
            symbolName: "playpause.circle.fill",
            keyEquivalent: " ",
            action: #selector(handleToggle)
        )
        self.toggleItem = toggleItem
        menu.addItem(toggleItem)

        let resetItem = createMenuItem(
            title: Localization.localized("menu.title.reset"),
            symbolName: "arrow.counterclockwise.circle.fill",
            keyEquivalent: "r",
            action: #selector(handleReset)
        )
        self.resetItem = resetItem
        menu.addItem(resetItem)

        menu.addItem(.separator())

        let statsItem = createMenuItem(
            title: Localization.localized("menu.title.stats"),
            symbolName: "chart.bar.fill",
            keyEquivalent: "s",
            action: #selector(handleStats)
        )
        self.statsItem = statsItem
        menu.addItem(statsItem)

        let settingsItem = createMenuItem(
            title: Localization.localized("menu.title.settings"),
            symbolName: "gearshape.fill",
            keyEquivalent: ",",
            action: #selector(handleSettings)
        )
        self.settingsItem = settingsItem
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = createMenuItem(
            title: Localization.localized("menu.title.quit"),
            symbolName: "power",
            keyEquivalent: "q",
            action: #selector(handleQuit)
        )
        self.quitItem = quitItem
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

    func refreshLocalizedStrings() {
        statusTitleItem.title = Localization.localized("menu.status.idle")
        toggleItem?.title = Localization.localized("menu.title.startPause")
        resetItem?.title = Localization.localized("menu.title.reset")
        statsItem?.title = Localization.localized("menu.title.stats")
        settingsItem?.title = Localization.localized("menu.title.settings")
        quitItem?.title = Localization.localized("menu.title.quit")
        refreshStats()
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
