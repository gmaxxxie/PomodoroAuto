import AppKit

final class SettingsWindowController: NSWindowController {
    private let settings: SettingsStore
    private let onSave: () -> Void

    private let workMinutesField = NSTextField()
    private let breakMinutesField = NSTextField()
    private let autoStartCheckbox = NSButton(checkboxWithTitle: "Auto start/pause", target: nil, action: nil)
    private let autoStartAppsField = NSTextField()
    private let fullscreenRuleCheckbox = NSButton(checkboxWithTitle: "Fullscreen non-work", target: nil, action: nil)
    private let whitelistField = NSTextField()
    private let autoStartPickButton = NSButton()
    private let whitelistPickButton = NSButton()

    init(settings: SettingsStore, onSave: @escaping () -> Void) {
        self.settings = settings
        self.onSave = onSave
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 520),
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
        scrollView.documentView = documentView

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stack)

        let timingSection = createTimingSection()
        let autoStartSection = createAutoStartSection()
        let fullscreenSection = createFullscreenSection()

        stack.addArrangedSubview(timingSection)
        stack.addArrangedSubview(autoStartSection)
        stack.addArrangedSubview(fullscreenSection)

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
        section.spacing = 12

        let title = createSectionTitle(title: "Timing", symbolName: "clock")
        section.addArrangedSubview(title)

        let workRow = createLabeledRow(label: "Work minutes", field: workMinutesField, placeholder: "25")
        let breakRow = createLabeledRow(label: "Break minutes", field: breakMinutesField, placeholder: "5")

        section.addArrangedSubview(workRow)
        section.addArrangedSubview(breakRow)

        return section
    }

    private func createAutoStartSection() -> NSStackView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 12

        let title = createSectionTitle(title: "Auto Start", symbolName: "play.circle.fill")
        section.addArrangedSubview(title)

        autoStartCheckbox.controlSize = .regular
        autoStartCheckbox.font = NSFont.systemFont(ofSize: 13)
        section.addArrangedSubview(autoStartCheckbox)

        let appsLabel = createInfoLabel(text: "Auto-start allowlist (comma-separated)")
        section.addArrangedSubview(appsLabel)

        let appsRow = createButtonFieldRow(field: autoStartAppsField, button: autoStartPickButton, placeholder: "com.apple.Terminal, com.apple.dt.Xcode")
        section.addArrangedSubview(appsRow)

        return section
    }

    private func createFullscreenSection() -> NSStackView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 12

        let title = createSectionTitle(title: "Fullscreen Rules", symbolName: "rectangle.on.rectangle")
        section.addArrangedSubview(title)

        fullscreenRuleCheckbox.controlSize = .regular
        fullscreenRuleCheckbox.font = NSFont.systemFont(ofSize: 13)
        section.addArrangedSubview(fullscreenRuleCheckbox)

        let whitelistLabel = createInfoLabel(text: "Fullscreen work allowlist (comma-separated)")
        section.addArrangedSubview(whitelistLabel)

        let whitelistRow = createButtonFieldRow(field: whitelistField, button: whitelistPickButton, placeholder: "com.apple.TextEdit")
        section.addArrangedSubview(whitelistRow)

        let note = createNoteLabel(text: "Note: Safari fullscreen is always treated as non-work.")
        section.addArrangedSubview(note)

        return section
    }

    private func createSectionTitle(title: String, symbolName: String) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8

        let imageView = NSImageView()
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title) {
            image.isTemplate = true
            imageView.image = image
            imageView.imageScaling = .scaleProportionallyUpOrDown
        }
        imageView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let label = NSTextField(labelWithString: title)
        label.font = NSFont.boldSystemFont(ofSize: 13)
        label.textColor = .labelColor

        stack.addArrangedSubview(imageView)
        stack.addArrangedSubview(label)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 10
        container.addArrangedSubview(stack)
        container.addArrangedSubview(separator)

        separator.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true

        return container
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

    private func createButtonFieldRow(field: NSTextField, button: NSButton, placeholder: String) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8

        field.placeholderString = placeholder
        field.controlSize = .regular
        field.bezelStyle = .roundedBezel

        configurePickButton(button)

        stack.addArrangedSubview(field)
        stack.addArrangedSubview(button)

        field.translatesAutoresizingMaskIntoConstraints = false
        button.translatesAutoresizingMaskIntoConstraints = false

        return stack
    }

    private func configurePickButton(_ button: NSButton) {
        button.title = "Choose..."
        button.bezelStyle = .rounded
        button.controlSize = .small

        if let image = NSImage(systemSymbolName: "plus.app", accessibilityDescription: "Choose App") {
            image.isTemplate = true
            image.size = NSSize(width: 14, height: 14)
            button.image = image
            button.imagePosition = .imageLeading
        }

        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 110).isActive = true
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
    }

    @objc private func handleSave() {
        let minutes = Int(workMinutesField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 25
        let breakMinutes = Int(breakMinutesField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 5
        settings.workMinutes = max(1, minutes)
        settings.breakMinutes = max(1, breakMinutes)
        settings.autoStart = autoStartCheckbox.state == .on
        settings.fullscreenNonWork = fullscreenRuleCheckbox.state == .on

        let autoStartRaw = autoStartAppsField.stringValue
        let autoStartParts = autoStartRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        settings.autoStartBundleIds = autoStartParts.filter { !$0.isEmpty }

        let raw = whitelistField.stringValue
        let parts = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        settings.whitelistBundleIds = parts.filter { !$0.isEmpty }

        onSave()
        window?.close()
    }

    @objc private func handlePickAutoStartApp() {
        pickBundleId(into: autoStartAppsField)
    }

    @objc private func handlePickWhitelistApp() {
        pickBundleId(into: whitelistField)
    }

    private func pickBundleId(into field: NSTextField) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedFileTypes = ["app"]
        panel.title = "Choose an app"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            guard let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier else {
                self?.showAlert(title: "Bundle ID Not Found", message: "The selected app does not have a bundle identifier.")
                return
            }
            self?.appendBundleId(bundleId, to: field)
        }
    }

    private func appendBundleId(_ bundleId: String, to field: NSTextField) {
        let existing = field.stringValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if existing.contains(bundleId) {
            return
        }
        let updated = existing + [bundleId]
        field.stringValue = updated.joined(separator: ", ")
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
