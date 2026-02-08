import AppKit

final class SettingsWindowController: NSWindowController, NSMenuDelegate, NSWindowDelegate {
    private enum Layout {
        static let cardMaxWidth: CGFloat = 620
        static let cardMinWidth: CGFloat = 520
    }
    private let settings: SettingsStore
    private let statsStore: StatsStore
    private let onSave: () -> Void
    private let appSearchUrls: [URL]
    var onClose: (() -> Void)?

    private let workMinutesField = NSTextField()
    private let breakMinutesField = NSTextField()
    private let autoStartCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoStartAppsField = NSTextField()
    private let autoStartAppPopup = NSPopUpButton()
    private let autoStartSearchField = NSSearchField()
    private let fullscreenRuleCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let whitelistField = NSTextField()
    private let whitelistAppPopup = NSPopUpButton()
    private let whitelistSearchField = NSSearchField()
    private let languagePopup = NSPopUpButton()
    private var installedAppsCache: [AppInfo] = []
    private var selectedAppIconCache: [String: NSImage] = [:]

    private let autoStartChipsContainer = NSStackView()
    private let whitelistChipsContainer = NSStackView()

    private struct AppInfo {
        let name: String
        let bundleId: String
        let bundlePath: String
    }

    init(
        settings: SettingsStore,
        statsStore: StatsStore,
        onSave: @escaping () -> Void,
        appSearchUrls: [URL]? = nil
    ) {
        self.settings = settings
        self.statsStore = statsStore
        self.onSave = onSave
        self.appSearchUrls = appSearchUrls ?? Self.defaultAppSearchUrls(fileManager: .default)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 600),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = Localization.localized("settings.title")
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
        window.delegate = self

        buildContent()
        loadValues()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private static func defaultAppSearchUrls(fileManager: FileManager) -> [URL] {
        [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]
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

        let languageSection = wrapCard(createCardSection(content: createLanguageSection()))
        let timingSection = wrapCard(createCardSection(content: createTimingSection()))
        let autoStartSection = wrapCard(createCardSection(content: createAutoStartSection()))
        let fullscreenSection = wrapCard(createCardSection(content: createFullscreenSection()))
        let resetSection = wrapCard(createCardSection(content: createResetSection()))

        stack.addArrangedSubview(languageSection)
        stack.addArrangedSubview(timingSection)
        stack.addArrangedSubview(autoStartSection)
        stack.addArrangedSubview(fullscreenSection)
        stack.addArrangedSubview(resetSection)

        let saveButton = createModernButton(title: Localization.localized("settings.save"), symbolName: "checkmark.circle.fill")
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

        let title = createSectionTitle(title: Localization.localized("settings.section.timing"), symbolName: "clock", color: .systemGreen)
        section.addArrangedSubview(title)

        let fieldsStack = NSStackView()
        fieldsStack.orientation = .horizontal
        fieldsStack.alignment = .top
        fieldsStack.spacing = 24

        let workRow = createLabeledRow(label: Localization.localized("settings.workMinutes"), field: workMinutesField, placeholder: "25")
        let breakRow = createLabeledRow(label: Localization.localized("settings.breakMinutes"), field: breakMinutesField, placeholder: "5")

        fieldsStack.addArrangedSubview(workRow)
        fieldsStack.addArrangedSubview(breakRow)

        section.addArrangedSubview(fieldsStack)

        return section
    }

    private func createLanguageSection() -> NSStackView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 14

        let title = createSectionTitle(title: Localization.localized("settings.section.language"), symbolName: "globe", color: .systemTeal)
        section.addArrangedSubview(title)

        let description = createInfoLabel(text: Localization.localized("settings.language.description"))
        section.addArrangedSubview(description)

        configureLanguagePopup()
        languagePopup.controlSize = .regular
        languagePopup.widthAnchor.constraint(equalToConstant: 220).isActive = true
        section.addArrangedSubview(languagePopup)

        return section
    }

    private func createAutoStartSection() -> NSStackView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 14

        let title = createSectionTitle(title: Localization.localized("settings.section.autoStart"), symbolName: "play.circle.fill", color: .systemBlue)
        section.addArrangedSubview(title)

        autoStartCheckbox.title = Localization.localized("settings.autoStart")
        autoStartCheckbox.controlSize = .regular
        autoStartCheckbox.font = NSFont.systemFont(ofSize: 13)
        section.addArrangedSubview(autoStartCheckbox)

        let appsLabel = createInfoLabel(text: Localization.localized("settings.autoStartAllowlist"))
        section.addArrangedSubview(appsLabel)

        let appsRow = createPopupFieldRow(
            field: autoStartAppsField,
            popup: autoStartAppPopup,
            placeholder: Localization.localized("settings.autoStartPlaceholder"),
            searchField: autoStartSearchField,
            menuTitle: "autoStartApps"
        )
        section.addArrangedSubview(appsRow)

        configureChipsContainer(autoStartChipsContainer)
        section.addArrangedSubview(autoStartChipsContainer)

        return section
    }

    private func createFullscreenSection() -> NSStackView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 14

        let title = createSectionTitle(title: Localization.localized("settings.section.fullscreen"), symbolName: "rectangle.on.rectangle", color: .systemPurple)
        section.addArrangedSubview(title)

        fullscreenRuleCheckbox.title = Localization.localized("settings.fullscreenNonWork")
        fullscreenRuleCheckbox.controlSize = .regular
        fullscreenRuleCheckbox.font = NSFont.systemFont(ofSize: 13)
        section.addArrangedSubview(fullscreenRuleCheckbox)

        let whitelistLabel = createInfoLabel(text: Localization.localized("settings.fullscreenAllowlist"))
        section.addArrangedSubview(whitelistLabel)

        let whitelistRow = createPopupFieldRow(
            field: whitelistField,
            popup: whitelistAppPopup,
            placeholder: Localization.localized("settings.fullscreenPlaceholder"),
            searchField: whitelistSearchField,
            menuTitle: "whitelistApps"
        )
        section.addArrangedSubview(whitelistRow)

        configureChipsContainer(whitelistChipsContainer)
        section.addArrangedSubview(whitelistChipsContainer)

        let note = createNoteLabel(text: Localization.localized("settings.fullscreenNote"))
        section.addArrangedSubview(note)

        return section
    }

    private func createResetSection() -> NSStackView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 14

        let title = createSectionTitle(title: Localization.localized("settings.section.reset"), symbolName: "arrow.counterclockwise", color: .systemRed)
        section.addArrangedSubview(title)

        let description = createNoteLabel(text: Localization.localized("settings.reset.description"))
        section.addArrangedSubview(description)

        let resetButton = createDangerButton(title: Localization.localized("settings.reset.button"), symbolName: "trash")
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
        firstAlert.messageText = Localization.localized("settings.reset.alert.title")
        firstAlert.informativeText = Localization.localized("settings.reset.alert.body")
        firstAlert.alertStyle = .warning
        firstAlert.addButton(withTitle: Localization.localized("settings.reset.alert.continue"))
        firstAlert.addButton(withTitle: Localization.localized("settings.reset.alert.cancel"))

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
        secondAlert.messageText = Localization.localized("settings.reset.alert.confirm.title")
        secondAlert.informativeText = Localization.localized("settings.reset.alert.confirm.body")
        secondAlert.alertStyle = .critical
        secondAlert.addButton(withTitle: Localization.localized("settings.reset.alert.confirm.action"))
        secondAlert.addButton(withTitle: Localization.localized("settings.reset.alert.cancel"))

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

    private func wrapCard(_ card: NSView) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            card.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.cardMinWidth),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.cardMaxWidth)
        ])

        return container
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
        popup.target = self
        popup.action = #selector(handlePopupSelection(_:))
        popup.menu = NSMenu(title: menuTitle)
        popup.menu?.delegate = self
        configureMenuSearchField(searchField)
        populateInstalledApps(into: popup, filter: searchField.stringValue)
    }

    private func configureLanguagePopup() {
        languagePopup.removeAllItems()

        languagePopup.addItem(withTitle: Localization.localized("settings.language.system"))
        languagePopup.lastItem?.representedObject = LanguagePreference.system

        languagePopup.addItem(withTitle: Localization.localized("settings.language.english"))
        languagePopup.lastItem?.representedObject = LanguagePreference.english

        languagePopup.addItem(withTitle: Localization.localized("settings.language.chineseSimplified"))
        languagePopup.lastItem?.representedObject = LanguagePreference.chineseSimplified
    }

    private func selectLanguagePreference(_ preference: LanguagePreference) {
        let index = languagePopup.itemArray.firstIndex { item in
            guard let value = item.representedObject as? LanguagePreference else { return false }
            return value == preference
        }
        if let index {
            languagePopup.selectItem(at: index)
        }
    }

    private func languagePreferenceSelection() -> LanguagePreference {
        guard let item = languagePopup.selectedItem,
              let preference = item.representedObject as? LanguagePreference else {
            return .system
        }
        return preference
    }

    private func configureMenuSearchField(_ field: NSSearchField) {
        field.placeholderString = Localization.localized("settings.search.placeholder")
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

    private func configureChipsContainer(_ container: NSStackView) {
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 6
        container.translatesAutoresizingMaskIntoConstraints = false
    }

    private func updateChips(for container: NSStackView, bundleIds: [String]) {
        container.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if bundleIds.isEmpty { return }

        let flowContainer = NSView()
        flowContainer.translatesAutoresizingMaskIntoConstraints = false

        var chips: [NSView] = []
        let appCache = Dictionary(uniqueKeysWithValues: installedApps().map { ($0.bundleId, $0) })

        for bundleId in bundleIds {
            let chip = createChip(
                bundleId: bundleId,
                appInfo: appCache[bundleId],
                container: container
            )
            chips.append(chip)
            flowContainer.addSubview(chip)
        }

        container.addArrangedSubview(flowContainer)

        flowContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 500).isActive = true

        layoutChipsInFlow(chips, container: flowContainer)
    }

    private func layoutChipsInFlow(_ chips: [NSView], container: NSView) {
        guard !chips.isEmpty else { return }

        let maxWidth: CGFloat = 500
        let horizontalSpacing: CGFloat = 6
        let verticalSpacing: CGFloat = 6

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for chip in chips {
            chip.layoutSubtreeIfNeeded()
            let chipWidth = chip.fittingSize.width
            let chipHeight = chip.fittingSize.height

            if x + chipWidth > maxWidth && x > 0 {
                x = 0
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }

            chip.frame = NSRect(x: x, y: y, width: chipWidth, height: chipHeight)
            x += chipWidth + horizontalSpacing
            rowHeight = max(rowHeight, chipHeight)
        }

        let totalHeight = y + rowHeight
        container.heightAnchor.constraint(equalToConstant: max(totalHeight, 24)).isActive = true
    }

    private func createChip(bundleId: String, appInfo: AppInfo?, container: NSStackView) -> NSView {
        let chip = NSView()
        chip.wantsLayer = true
        chip.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        chip.layer?.cornerRadius = 6
        chip.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        chip.addSubview(stack)

        if let icon = appIcon(for: appInfo) {
            let iconView = NSImageView(image: icon)
            iconView.imageScaling = .scaleProportionallyUpOrDown
            iconView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                iconView.widthAnchor.constraint(equalToConstant: 14),
                iconView.heightAnchor.constraint(equalToConstant: 14)
            ])
            stack.addArrangedSubview(iconView)
        }

        let displayName = appInfo?.name ?? bundleId
        let label = NSTextField(labelWithString: displayName)
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        stack.addArrangedSubview(label)

        let removeButton = NSButton()
        removeButton.bezelStyle = .inline
        removeButton.isBordered = false
        removeButton.title = ""
        if let xImage = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: Localization.localized("settings.chip.remove")) {
            xImage.isTemplate = true
            removeButton.image = xImage
            removeButton.contentTintColor = .secondaryLabelColor
        }
        removeButton.target = self
        removeButton.action = #selector(handleRemoveChip(_:))
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            removeButton.widthAnchor.constraint(equalToConstant: 16),
            removeButton.heightAnchor.constraint(equalToConstant: 16)
        ])

        let isAutoStart = (container === autoStartChipsContainer)
        removeButton.tag = isAutoStart ? 1000 : 2000
        removeButton.identifier = NSUserInterfaceItemIdentifier(bundleId)

        stack.addArrangedSubview(removeButton)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: chip.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: chip.trailingAnchor, constant: -6),
            stack.topAnchor.constraint(equalTo: chip.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: chip.bottomAnchor, constant: -4)
        ])

        return chip
    }

    @objc private func handleRemoveChip(_ sender: NSButton) {
        guard let bundleId = sender.identifier?.rawValue else { return }

        let isAutoStart = sender.tag == 1000
        let field = isAutoStart ? autoStartAppsField : whitelistField
        let popup = isAutoStart ? autoStartAppPopup : whitelistAppPopup
        let container = isAutoStart ? autoStartChipsContainer : whitelistChipsContainer
        let filter = isAutoStart ? autoStartSearchField.stringValue : whitelistSearchField.stringValue

        var existing = bundleIds(from: field)
        if let index = existing.firstIndex(of: bundleId) {
            existing.remove(at: index)
        }
        field.stringValue = existing.joined(separator: ", ")

        updateChips(for: container, bundleIds: existing)
        populateInstalledApps(into: popup, filter: filter)
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
        selectLanguagePreference(settings.languagePreference)
        populateInstalledApps(into: autoStartAppPopup, filter: autoStartSearchField.stringValue)
        populateInstalledApps(into: whitelistAppPopup, filter: whitelistSearchField.stringValue)
        updateChips(for: autoStartChipsContainer, bundleIds: bundleIds(from: autoStartAppsField))
        updateChips(for: whitelistChipsContainer, bundleIds: bundleIds(from: whitelistField))
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
        settings.languagePreference = languagePreferenceSelection()

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
        let container = isAutoStart ? autoStartChipsContainer : whitelistChipsContainer
        
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
            updateChips(for: container, bundleIds: bundleIds(from: field))
        default:
            selectPlaceholder(in: popup)
        }
    }

    @objc private func handlePopupSelection(_ sender: NSPopUpButton) {
        guard let selectedItem = sender.selectedItem else { return }
        if let bundleId = selectedItem.representedObject as? String {
            applySelection(bundleId, for: sender)
            return
        }
        handlePopupMenuItem(selectedItem)
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

        let placeholder = NSMenuItem(title: Localization.localized("settings.selectApp.placeholder"), action: nil, keyEquivalent: "")
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
            item.representedObject = app.bundleId
            item.tag = baseTag + 2
            item.state = selectedIds.contains(app.bundleId) ? .on : .off
            popup.menu?.addItem(item)
        }

        let refresh = NSMenuItem(title: Localization.localized("settings.refreshApps"), action: nil, keyEquivalent: "")
        refresh.tag = baseTag + 1
        refresh.target = self
        refresh.action = #selector(handlePopupMenuItem(_:))
        popup.menu?.addItem(refresh)
        selectPlaceholder(in: popup)
    }

    private func applySelection(_ bundleId: String, for popup: NSPopUpButton) {
        let field = field(for: popup)
        let filter = searchField(for: popup).stringValue
        let container = (popup === autoStartAppPopup) ? autoStartChipsContainer : whitelistChipsContainer

        toggleBundleId(bundleId, in: field)
        populateInstalledApps(into: popup, filter: filter)
        selectPlaceholder(in: popup)
        updateChips(for: container, bundleIds: bundleIds(from: field))
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

    func windowWillClose(_ notification: Notification) {
        window?.delegate = nil
        installedAppsCache.removeAll(keepingCapacity: false)
        selectedAppIconCache.removeAll(keepingCapacity: false)
        autoStartAppPopup.menu?.delegate = nil
        whitelistAppPopup.menu?.delegate = nil
        autoStartAppPopup.target = nil
        autoStartAppPopup.action = nil
        whitelistAppPopup.target = nil
        whitelistAppPopup.action = nil
        autoStartSearchField.target = nil
        autoStartSearchField.action = nil
        whitelistSearchField.target = nil
        whitelistSearchField.action = nil
        autoStartAppPopup.menu?.removeAllItems()
        whitelistAppPopup.menu?.removeAllItems()
        let closeHandler = onClose
        onClose = nil
        closeHandler?()
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

        for base in appSearchUrls where fileManager.fileExists(atPath: base.path) {
            for appURL in appBundleURLs(in: base, fileManager: fileManager) {
                guard let appInfo = appInfo(at: appURL) else { continue }
                if !seen.insert(appInfo.bundleId).inserted {
                    continue
                }
                results.append(appInfo)
            }
        }

        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func appBundleURLs(in base: URL, fileManager: FileManager) -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: base,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .volumeIsLocalKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.filter { url in
            guard url.pathExtension == "app" else { return false }
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .volumeIsLocalKey]) else {
                return false
            }
            guard values.isDirectory == true else { return false }
            if values.isSymbolicLink == true {
                return false
            }
            if let volumeIsLocal = values.volumeIsLocal, !volumeIsLocal {
                return false
            }
            return true
        }
    }

    private func appInfo(at appURL: URL) -> AppInfo? {
        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoPlistURL),
              let plistObject = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let plist = plistObject as? [String: Any],
              let bundleId = plist["CFBundleIdentifier"] as? String else {
            return nil
        }

        let name =
            (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? appURL.deletingPathExtension().lastPathComponent

        return AppInfo(name: name, bundleId: bundleId, bundlePath: appURL.path)
    }

    private func appIcon(for appInfo: AppInfo?) -> NSImage? {
        guard let appInfo else { return nil }
        if let icon = selectedAppIconCache[appInfo.bundleId] {
            return icon
        }
        let icon = NSWorkspace.shared.icon(forFile: appInfo.bundlePath)
        icon.size = NSSize(width: 16, height: 16)
        selectedAppIconCache[appInfo.bundleId] = icon
        return icon
    }
}
