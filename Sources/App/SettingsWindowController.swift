import AppKit

final class SettingsWindowController: NSWindowController, NSMenuDelegate {
    private let settings: SettingsStore
    private let statsStore: StatsStore
    private let onSave: () -> Void

    private let workMinutesField = NSTextField()
    private let breakMinutesField = NSTextField()
    private let autoStartCheckbox = NSButton(checkboxWithTitle: "Auto start/pause", target: nil, action: nil)
    private let autoStartAppsField = NSTextField()
    private let autoStartAppPopup = NSPopUpButton()
    private let autoStartSearchField = NSSearchField()
    private let fullscreenRuleCheckbox = NSButton(checkboxWithTitle: "Fullscreen non-work", target: nil, action: nil)
    private let whitelistField = NSTextField()
    private let whitelistAppPopup = NSPopUpButton()
    private let whitelistSearchField = NSSearchField()
    private var installedAppsCache: [AppInfo] = []

    private struct AppInfo {
        let name: String
        let bundleId: String
        let icon: NSImage?
    }

    init(settings: SettingsStore, statsStore: StatsStore, onSave: @escaping () -> Void) {
        self.settings = settings
        self.statsStore = statsStore
        self.onSave = onSave
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.titleVisibility = .hidden

        if #available(macOS 11.0, *) {
            window.styleMask.insert(.fullSizeContentView)
        }

        super.init(window: window)

        if #available(macOS 11.0, *) {
            window.level = .floating
        }

        buildContent()
        loadValues()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        let backgroundView = NSVisualEffectView()
        backgroundView.material = .underWindowBackground
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.8).cgColor
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(backgroundView)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stack)

        let timingSection = createCardSection(content: createTimingSection())
        let autoStartSection = createCardSection(content: createAutoStartSection())
        let fullscreenSection = createCardSection(content: createFullscreenSection())
        let resetSection = createCardSection(content: createResetSection())

        stack.addArrangedSubview(timingSection)
        stack.addArrangedSubview(autoStartSection)
        stack.addArrangedSubview(fullscreenSection)
        stack.addArrangedSubview(resetSection)

        let saveButton = createModernButton(title: "Save", symbolName: "checkmark.circle.fill")
        saveButton.target = self
        saveButton.action = #selector(handleSave)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(saveButton)

        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: contentView.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 30),
            stack.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -24),

            saveButton.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -28),
            saveButton.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -30),
            saveButton.widthAnchor.constraint(equalToConstant: 100)
        ])
    }

    private func createTimingSection() -> NSStackView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 16

        let title = createSectionTitle(title: "Timing", symbolName: "clock", color: .systemGreen)
        section.addArrangedSubview(title)

        let fieldsStack = NSStackView()
        fieldsStack.orientation = .horizontal
        fieldsStack.alignment = .top
        fieldsStack.spacing = 24

        let workRow = createLabeledRow(label: "Work minutes", field: workMinutesField, placeholder: "25")
        let breakRow = createLabeledRow(label: "Break minutes", field: breakMinutesField, placeholder: "5")

        fieldsStack.addArrangedSubview(workRow)
        fieldsStack.addArrangedSubview(breakRow)

        section.addArrangedSubview(fieldsStack)

        return section
    }

    private func createAutoStartSection() -> NSStackView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 14

        let title = createSectionTitle(title: "Auto Start", symbolName: "play.circle.fill", color: .systemBlue)
        section.addArrangedSubview(title)

        autoStartCheckbox.controlSize = .regular
        autoStartCheckbox.font = NSFont.systemFont(ofSize: 13)
        section.addArrangedSubview(autoStartCheckbox)

        let appsLabel = createInfoLabel(text: "Auto-start allowlist (comma-separated)")
        section.addArrangedSubview(appsLabel)

        let appsRow = createPopupFieldRow(
            field: autoStartAppsField,
            popup: autoStartAppPopup,
            placeholder: "com.apple.Terminal, com.apple.dt.Xcode",
            searchField: autoStartSearchField,
            menuTitle: "autoStartApps"
        )
        section.addArrangedSubview(appsRow)

        return section
    }

    private func createFullscreenSection() -> NSStackView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 14

        let title = createSectionTitle(title: "Fullscreen Rules", symbolName: "rectangle.on.rectangle", color: .systemPurple)
        section.addArrangedSubview(title)

        fullscreenRuleCheckbox.controlSize = .regular
        fullscreenRuleCheckbox.font = NSFont.systemFont(ofSize: 13)
        section.addArrangedSubview(fullscreenRuleCheckbox)

        let whitelistLabel = createInfoLabel(text: "Fullscreen work allowlist (comma-separated)")
        section.addArrangedSubview(whitelistLabel)

        let whitelistRow = createPopupFieldRow(
            field: whitelistField,
            popup: whitelistAppPopup,
            placeholder: "com.apple.TextEdit",
            searchField: whitelistSearchField,
            menuTitle: "whitelistApps"
        )
        section.addArrangedSubview(whitelistRow)

        let note = createNoteLabel(text: "Note: Safari fullscreen is always treated as non-work.")
        section.addArrangedSubview(note)

        return section
    }

    private func createResetSection() -> NSStackView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 14

        let title = createSectionTitle(title: "Reset", symbolName: "arrow.counterclockwise", color: .systemRed)
        section.addArrangedSubview(title)

        let description = createNoteLabel(text: "Reset all settings to defaults and clear all history records. This action cannot be undone.")
        section.addArrangedSubview(description)

        let resetButton = createDangerButton(title: "Reset All Data", symbolName: "trash")
        resetButton.target = self
        resetButton.action = #selector(handleResetAllData)
        section.addArrangedSubview(resetButton)

        return section
    }

    private func createDangerButton(title: String, symbolName: String) -> NSButton {
        let button = NSButton()
        button.title = title
        button.bezelStyle = .rounded
        button.controlSize = .regular

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title) {
            image.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading
        }

        button.contentTintColor = NSColor.systemRed
        button.wantsLayer = true
        button.layer?.cornerRadius = 8

        return button
    }

    @objc private func handleResetAllData() {
        guard let window = self.window else { return }

        let firstAlert = NSAlert()
        firstAlert.messageText = "Reset All Data?"
        firstAlert.informativeText = "This will reset all settings to defaults and clear all history records."
        firstAlert.alertStyle = .warning
        firstAlert.addButton(withTitle: "Continue")
        firstAlert.addButton(withTitle: "Cancel")

        firstAlert.beginSheetModal(for: window) { [weak self] response in
            guard let self = self else { return }
            if response == .alertFirstButtonReturn {
                self.showSecondConfirmation()
            }
        }
    }

    private func showSecondConfirmation() {
        guard let window = self.window else { return }

        let secondAlert = NSAlert()
        secondAlert.messageText = "Are you absolutely sure?"
        secondAlert.informativeText = "All your settings and history will be permanently deleted. This cannot be undone."
        secondAlert.alertStyle = .critical
        secondAlert.addButton(withTitle: "Reset All Data")
        secondAlert.addButton(withTitle: "Cancel")

        secondAlert.beginSheetModal(for: window) { [weak self] response in
            guard let self = self else { return }
            if response == .alertFirstButtonReturn {
                self.performReset()
            }
        }
    }

    private func performReset() {
        settings.resetToDefaults()
        statsStore.clearAll()
        loadValues()
        onSave()
    }

    private func createCardSection(content: NSStackView) -> NSView {
        let card = NSVisualEffectView()
        card.material = .popover
        card.state = .active
        card.wantsLayer = true
        card.layer?.cornerRadius = 12
        card.layer?.masksToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false

        let shadowContainer = NSView()
        shadowContainer.wantsLayer = true
        shadowContainer.layer?.shadowColor = NSColor.black.cgColor
        shadowContainer.layer?.shadowOpacity = 0.08
        shadowContainer.layer?.shadowOffset = NSSize(width: 0, height: -2)
        shadowContainer.layer?.shadowRadius = 8
        shadowContainer.translatesAutoresizingMaskIntoConstraints = false

        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)

        shadowContainer.addSubview(card)

        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),

            card.leadingAnchor.constraint(equalTo: shadowContainer.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: shadowContainer.trailingAnchor),
            card.topAnchor.constraint(equalTo: shadowContainer.topAnchor),
            card.bottomAnchor.constraint(equalTo: shadowContainer.bottomAnchor)
        ])

        return shadowContainer
    }

    private func createSectionTitle(title: String, symbolName: String, color: NSColor = .controlAccentColor) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10

        let iconContainer = NSView()
        iconContainer.wantsLayer = true
        iconContainer.layer?.backgroundColor = color.withAlphaComponent(0.15).cgColor
        iconContainer.layer?.cornerRadius = 8
        iconContainer.translatesAutoresizingMaskIntoConstraints = false

        let imageView = NSImageView()
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title) {
            image.isTemplate = true
            imageView.image = image
            imageView.contentTintColor = color
            imageView.imageScaling = .scaleProportionallyUpOrDown
        }
        imageView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(imageView)

        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 28),
            iconContainer.heightAnchor.constraint(equalToConstant: 28),
            imageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 16),
            imageView.heightAnchor.constraint(equalToConstant: 16)
        ])

        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .labelColor

        stack.addArrangedSubview(iconContainer)
        stack.addArrangedSubview(label)

        return stack
    }

    private func createLabeledRow(label: String, field: NSTextField, placeholder: String) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6

        let labelView = NSTextField(labelWithString: label)
        labelView.font = NSFont.systemFont(ofSize: 12)
        labelView.textColor = .secondaryLabelColor

        field.placeholderString = placeholder
        field.controlSize = .regular
        field.bezelStyle = .roundedBezel
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: 120).isActive = true
        field.heightAnchor.constraint(equalToConstant: 28).isActive = true

        stack.addArrangedSubview(labelView)
        stack.addArrangedSubview(field)

        return stack
    }

    private func createPopupFieldRow(
        field: NSTextField,
        popup: NSPopUpButton,
        placeholder: String,
        searchField: NSSearchField,
        menuTitle: String
    ) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8

        field.placeholderString = placeholder
        field.controlSize = .regular
        field.bezelStyle = .roundedBezel

        configureAppPopup(popup, searchField: searchField, menuTitle: menuTitle)

        stack.addArrangedSubview(field)
        stack.addArrangedSubview(popup)

        field.translatesAutoresizingMaskIntoConstraints = false
        popup.translatesAutoresizingMaskIntoConstraints = false

        return stack
    }

    private func configureAppPopup(_ popup: NSPopUpButton, searchField: NSSearchField, menuTitle: String) {
        popup.pullsDown = false
        popup.controlSize = .regular
        popup.widthAnchor.constraint(equalToConstant: 200).isActive = true
        popup.menu = NSMenu(title: menuTitle)
        popup.menu?.delegate = self
        configureMenuSearchField(searchField)
        populateInstalledApps(into: popup, filter: searchField.stringValue)
    }

    private func configureMenuSearchField(_ field: NSSearchField) {
        field.placeholderString = "Filter apps"
        field.controlSize = .small
        field.sendsSearchStringImmediately = true
        field.target = self
        field.action = #selector(handleMenuSearchChanged(_:))
        field.frame = NSRect(x: 0, y: 0, width: 240, height: 22)
    }

    private func createInfoLabel(text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func createNoteLabel(text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = .tertiaryLabelColor
        label.lineBreakMode = .byWordWrapping
        return label
    }

    private func createModernButton(title: String, symbolName: String) -> NSButton {
        let button = NSButton()
        button.title = title
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.keyEquivalent = "\r"

        if #available(macOS 11.0, *) {
            button.controlSize = .large
        }

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title) {
            image.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading
        }

        button.wantsLayer = true
        button.layer?.cornerRadius = 8

        return button
    }

    private func loadValues() {
        workMinutesField.stringValue = String(settings.workMinutes)
        breakMinutesField.stringValue = String(settings.breakMinutes)
        autoStartCheckbox.state = settings.autoStart ? .on : .off
        autoStartAppsField.stringValue = settings.autoStartBundleIds.joined(separator: ", ")
        fullscreenRuleCheckbox.state = settings.fullscreenNonWork ? .on : .off
        whitelistField.stringValue = settings.whitelistBundleIds.joined(separator: ", ")
        populateInstalledApps(into: autoStartAppPopup, filter: autoStartSearchField.stringValue)
        populateInstalledApps(into: whitelistAppPopup, filter: whitelistSearchField.stringValue)
    }

    @objc private func handleSave() {
        let minutes = Int(workMinutesField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 25
        let breakMinutes = Int(breakMinutesField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 5
        settings.workMinutes = max(1, minutes)
        settings.breakMinutes = max(1, breakMinutes)
        settings.autoStart = autoStartCheckbox.state == .on
        settings.fullscreenNonWork = fullscreenRuleCheckbox.state == .on

        settings.autoStartBundleIds = bundleIds(from: autoStartAppsField)
        settings.whitelistBundleIds = bundleIds(from: whitelistField)

        onSave()
        window?.close()
    }

    @objc private func handleMenuSearchChanged(_ sender: NSSearchField) {
        if sender === autoStartSearchField {
            populateInstalledApps(into: autoStartAppPopup, filter: autoStartSearchField.stringValue)
            window?.makeFirstResponder(autoStartSearchField)
        } else if sender === whitelistSearchField {
            populateInstalledApps(into: whitelistAppPopup, filter: whitelistSearchField.stringValue)
            window?.makeFirstResponder(whitelistSearchField)
        }
    }

    @objc private func handlePopupMenuItem(_ sender: NSMenuItem) {
        let tag = sender.tag
        if tag == -1 || tag == 0 { return }

        let isAutoStart = (tag >= 1000 && tag < 2000)
        let isWhitelist = (tag >= 2000 && tag < 3000)
        
        guard isAutoStart || isWhitelist else { return }
        
        let popup = isAutoStart ? autoStartAppPopup : whitelistAppPopup
        let field = isAutoStart ? autoStartAppsField : whitelistField
        let filter = isAutoStart ? autoStartSearchField.stringValue : whitelistSearchField.stringValue
        
        let actionType = tag % 1000
        
        switch actionType {
        case 1:
            refreshInstalledApps()
            populateInstalledApps(into: popup, filter: filter)
            selectPlaceholder(in: popup)
        case 2:
            if let bundleId = sender.representedObject as? String {
                toggleBundleId(bundleId, in: field)
            }
            populateInstalledApps(into: popup, filter: filter)
            selectPlaceholder(in: popup)
        default:
            selectPlaceholder(in: popup)
        }
    }

    private func populateInstalledApps(into popup: NSPopUpButton, filter: String) {
        popup.removeAllItems()
        if popup.menu == nil {
            popup.menu = NSMenu()
        }
        
        let isAutoStart = (popup === autoStartAppPopup)
        let baseTag = isAutoStart ? 1000 : 2000
        
        let selectedIds = Set(bundleIds(from: field(for: popup)))
        let searchField = searchField(for: popup)
        let searchItem = NSMenuItem()
        searchItem.view = searchField
        searchItem.tag = -1
        popup.menu?.addItem(searchItem)
        popup.menu?.addItem(.separator())

        let placeholder = NSMenuItem(title: "Select installed app...", action: nil, keyEquivalent: "")
        placeholder.tag = 0
        popup.menu?.addItem(placeholder)

        let normalized = filter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for app in installedApps() {
            if !normalized.isEmpty {
                let haystack = "\(app.name) \(app.bundleId)".lowercased()
                if !haystack.contains(normalized) {
                    continue
                }
            }
            let item = NSMenuItem(title: "\(app.name) (\(app.bundleId))", action: nil, keyEquivalent: "")
            if let icon = app.icon {
                item.image = icon
            }
            item.representedObject = app.bundleId
            item.tag = baseTag + 2
            item.state = selectedIds.contains(app.bundleId) ? .on : .off
            item.target = self
            item.action = #selector(handlePopupMenuItem(_:))
            popup.menu?.addItem(item)
        }

        let refresh = NSMenuItem(title: "Refresh list", action: nil, keyEquivalent: "")
        refresh.tag = baseTag + 1
        refresh.target = self
        refresh.action = #selector(handlePopupMenuItem(_:))
        popup.menu?.addItem(refresh)
        selectPlaceholder(in: popup)
    }

    private func field(for popup: NSPopUpButton) -> NSTextField {
        if popup === autoStartAppPopup {
            return autoStartAppsField
        }
        return whitelistField
    }

    private func searchField(for popup: NSPopUpButton) -> NSSearchField {
        if popup === autoStartAppPopup {
            return autoStartSearchField
        }
        return whitelistSearchField
    }

    private func bundleIds(from field: NSTextField) -> [String] {
        field.stringValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func toggleBundleId(_ bundleId: String, in field: NSTextField) {
        var existing = bundleIds(from: field)
        if let index = existing.firstIndex(of: bundleId) {
            existing.remove(at: index)
        } else {
            existing.append(bundleId)
        }
        field.stringValue = existing.joined(separator: ", ")
    }

    private func selectPlaceholder(in popup: NSPopUpButton) {
        if let placeholder = popup.menu?.item(withTag: 0) {
            popup.select(placeholder)
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        if menu === autoStartAppPopup.menu {
            window?.makeFirstResponder(autoStartSearchField)
        } else if menu === whitelistAppPopup.menu {
            window?.makeFirstResponder(whitelistSearchField)
        }
    }

    private func installedApps() -> [AppInfo] {
        if installedAppsCache.isEmpty {
            installedAppsCache = loadInstalledApps()
        }
        return installedAppsCache
    }

    private func refreshInstalledApps() {
        installedAppsCache = loadInstalledApps()
    }

    private func loadInstalledApps() -> [AppInfo] {
        var results: [AppInfo] = []
        var seen = Set<String>()
        let fileManager = FileManager.default
        let searchUrls = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]

        for base in searchUrls where fileManager.fileExists(atPath: base.path) {
            guard let enumerator = fileManager.enumerator(
                at: base,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            for case let url as URL in enumerator {
                guard url.pathExtension == "app" else { continue }
                guard let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier else { continue }
                if !seen.insert(bundleId).inserted {
                    continue
                }
                let name =
                    (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 16, height: 16)
                results.append(AppInfo(name: name, bundleId: bundleId, icon: icon))
            }
        }

        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
