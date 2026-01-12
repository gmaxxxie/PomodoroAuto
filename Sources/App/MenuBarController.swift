import AppKit

final class MenuBarController {
    var onToggle: (() -> Void)?
    var onReset: (() -> Void)?
    var onOpenStats: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private let statusTitleItem = NSMenuItem(title: "Idle", action: nil, keyEquivalent: "")

    init(
        onToggle: (() -> Void)? = nil,
        onReset: (() -> Void)? = nil,
        onOpenStats: (() -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil,
        onQuit: (() -> Void)? = nil
    ) {
        self.onToggle = onToggle
        self.onReset = onReset
        self.onOpenStats = onOpenStats
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.menu = NSMenu()
        buildMenu()
        configureStatusItem()
    }

    func setRemaining(seconds: Int, label: String = "Remaining") {
        let minutes = seconds / 60
        let secs = seconds % 60
        let text = String(format: "%02d:%02d", minutes, secs)
        statusItem.button?.title = text
        statusTitleItem.title = "\(label): \(text)"
        updateStatusIcon(isRunning: true)
    }

    func setStatus(text: String) {
        statusItem.button?.title = ""
        statusTitleItem.title = text
        updateStatusIcon(isRunning: false)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.title = ""
        updateStatusIcon(isRunning: false)
    }

    private func updateStatusIcon(isRunning: Bool) {
        guard let button = statusItem.button else { return }
        let symbolName = isRunning ? "timer.circle.fill" : "timer.circle"
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Pomodoro") {
            image.isTemplate = true
            if isRunning {
                button.contentTintColor = NSColor.controlAccentColor
            } else {
                button.contentTintColor = nil
            }
            button.image = image
        }
    }

    private func buildMenu() {
        menu.addItem(statusTitleItem)
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
