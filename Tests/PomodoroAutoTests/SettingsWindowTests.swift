import XCTest
import AppKit
@testable import PomodoroAuto

final class SettingsWindowTests: XCTestCase {
    var defaults: UserDefaults!
    var store: SettingsStore!
    var statsStore: StatsStore!
    var controller: SettingsWindowController!
    
    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "SettingsWindowTests")
        defaults.removePersistentDomain(forName: "SettingsWindowTests")
        store = SettingsStore(defaults: defaults)
        statsStore = StatsStore(defaults: defaults)
        controller = SettingsWindowController(settings: store, statsStore: statsStore, onSave: {})
        _ = controller.window
    }
    
    override func tearDown() {
        defaults.removePersistentDomain(forName: "SettingsWindowTests")
        controller = nil
        statsStore = nil
        store = nil
        defaults = nil
        super.tearDown()
    }
    
    func testSelectingAutoStartAppUpdatesField() {
        let item = NSMenuItem(title: "Test App", action: nil, keyEquivalent: "")
        item.tag = 1002
        item.representedObject = "com.test.app"
        
        let selector = Selector("handlePopupMenuItem:")
        XCTAssertTrue(controller.responds(to: selector), "Controller should respond to handlePopupMenuItem:")
        controller.perform(selector, with: item)
        
        let textField = findTextField(placeholder: "com.apple.Terminal, com.apple.dt.Xcode")
        XCTAssertNotNil(textField, "Could not find Auto Start text field")
        XCTAssertEqual(textField?.stringValue, "com.test.app", "Text field should contain the selected bundle ID")
        
        controller.perform(selector, with: item)
        XCTAssertEqual(textField?.stringValue, "", "Text field should be empty after toggling off")
    }
    
    func testSelectingWhitelistAppUpdatesField() {
        let item = NSMenuItem(title: "Test App", action: nil, keyEquivalent: "")
        item.tag = 2002
        item.representedObject = "com.test.whitelist"
        
        let selector = Selector("handlePopupMenuItem:")
        controller.perform(selector, with: item)
        
        let textField = findTextField(placeholder: "com.apple.TextEdit")
        XCTAssertNotNil(textField, "Could not find Whitelist text field")
        XCTAssertEqual(textField?.stringValue, "com.test.whitelist")
    }
    
    // MARK: - Save Settings Tests
    
    func testSaveUpdatesSettingsStore() {
        let workField = findTextField(placeholder: "25")
        let breakField = findTextField(placeholder: "5")
        
        workField?.stringValue = "30"
        breakField?.stringValue = "10"
        
        let saveSelector = Selector("handleSave")
        XCTAssertTrue(controller.responds(to: saveSelector))
        controller.perform(saveSelector)
        
        XCTAssertEqual(store.workMinutes, 30)
        XCTAssertEqual(store.breakMinutes, 10)
    }
    
    func testSaveUpdatesAutoStartBundleIds() {
        let textField = findTextField(placeholder: "com.apple.Terminal, com.apple.dt.Xcode")
        textField?.stringValue = "com.saved.app1, com.saved.app2"
        
        let saveSelector = Selector("handleSave")
        controller.perform(saveSelector)
        
        XCTAssertEqual(store.autoStartBundleIds, ["com.saved.app1", "com.saved.app2"])
    }
    
    func testSaveUpdatesWhitelistBundleIds() {
        let textField = findTextField(placeholder: "com.apple.TextEdit")
        textField?.stringValue = "com.whitelist.app"
        
        let saveSelector = Selector("handleSave")
        controller.perform(saveSelector)
        
        XCTAssertEqual(store.whitelistBundleIds, ["com.whitelist.app"])
    }
    
    func testSaveCallsOnSaveCallback() {
        var callbackCalled = false
        let testController = SettingsWindowController(settings: store, statsStore: statsStore) {
            callbackCalled = true
        }
        _ = testController.window
        
        let saveSelector = Selector("handleSave")
        testController.perform(saveSelector)
        
        XCTAssertTrue(callbackCalled)
    }
    
    func testSaveEnforcesMinimumOneMinute() {
        let workField = findTextField(placeholder: "25")
        let breakField = findTextField(placeholder: "5")
        
        workField?.stringValue = "0"
        breakField?.stringValue = "-5"
        
        let saveSelector = Selector("handleSave")
        controller.perform(saveSelector)
        
        XCTAssertEqual(store.workMinutes, 1)
        XCTAssertEqual(store.breakMinutes, 1)
    }
    
    // MARK: - Load Values Tests
    
    func testLoadValuesPopulatesWorkMinutes() {
        store.workMinutes = 45
        
        let testController = SettingsWindowController(settings: store, statsStore: statsStore, onSave: {})
        _ = testController.window
        
        let workField = findTextField(in: testController.window?.contentView, placeholder: "25")
        XCTAssertEqual(workField?.stringValue, "45")
    }
    
    func testLoadValuesPopulatesBreakMinutes() {
        store.breakMinutes = 15
        
        let testController = SettingsWindowController(settings: store, statsStore: statsStore, onSave: {})
        _ = testController.window
        
        let breakField = findTextField(in: testController.window?.contentView, placeholder: "5")
        XCTAssertEqual(breakField?.stringValue, "15")
    }
    
    func testLoadValuesPopulatesAutoStartApps() {
        store.autoStartBundleIds = ["com.load.app1", "com.load.app2"]
        
        let testController = SettingsWindowController(settings: store, statsStore: statsStore, onSave: {})
        _ = testController.window
        
        let textField = findTextField(in: testController.window?.contentView, placeholder: "com.apple.Terminal, com.apple.dt.Xcode")
        XCTAssertEqual(textField?.stringValue, "com.load.app1, com.load.app2")
    }
    
    func testLoadValuesPopulatesWhitelistApps() {
        store.whitelistBundleIds = ["com.whitelist.loaded"]
        
        let testController = SettingsWindowController(settings: store, statsStore: statsStore, onSave: {})
        _ = testController.window
        
        let textField = findTextField(in: testController.window?.contentView, placeholder: "com.apple.TextEdit")
        XCTAssertEqual(textField?.stringValue, "com.whitelist.loaded")
    }
    
    // MARK: - Checkbox Tests
    
    func testAutoStartCheckboxLoadsState() {
        store.autoStart = false
        
        let testController = SettingsWindowController(settings: store, statsStore: statsStore, onSave: {})
        _ = testController.window
        
        let checkbox = findCheckbox(in: testController.window?.contentView, title: "Auto start/pause")
        XCTAssertEqual(checkbox?.state, .off)
    }
    
    func testAutoStartCheckboxSavesState() {
        let checkbox = findCheckbox(in: controller.window?.contentView, title: "Auto start/pause")
        checkbox?.state = .off
        
        let saveSelector = Selector("handleSave")
        controller.perform(saveSelector)
        
        XCTAssertFalse(store.autoStart)
    }
    
    func testFullscreenCheckboxLoadsState() {
        store.fullscreenNonWork = false
        
        let testController = SettingsWindowController(settings: store, statsStore: statsStore, onSave: {})
        _ = testController.window
        
        let checkbox = findCheckbox(in: testController.window?.contentView, title: "Fullscreen non-work")
        XCTAssertEqual(checkbox?.state, .off)
    }
    
    func testFullscreenCheckboxSavesState() {
        let checkbox = findCheckbox(in: controller.window?.contentView, title: "Fullscreen non-work")
        checkbox?.state = .off
        
        let saveSelector = Selector("handleSave")
        controller.perform(saveSelector)
        
        XCTAssertFalse(store.fullscreenNonWork)
    }
    
    // MARK: - Reset Tests
    
    func testResetClearsSettings() {
        store.workMinutes = 99
        store.breakMinutes = 88
        store.autoStartBundleIds = ["com.test.reset"]
        store.whitelistBundleIds = ["com.test.whitelist"]
        
        store.resetToDefaults()
        
        XCTAssertEqual(store.workMinutes, 25)
        XCTAssertEqual(store.breakMinutes, 5)
        XCTAssertEqual(store.autoStartBundleIds, [])
        XCTAssertEqual(store.whitelistBundleIds, [])
    }
    
    // MARK: - Refresh App List Tests
    
    func testRefreshAppListActionWorks() {
        let item = NSMenuItem(title: "Refresh list", action: nil, keyEquivalent: "")
        item.tag = 1001
        
        let selector = Selector("handlePopupMenuItem:")
        XCTAssertTrue(controller.responds(to: selector))
        controller.perform(selector, with: item)
    }
    
    func testRefreshWhitelistAppListActionWorks() {
        let item = NSMenuItem(title: "Refresh list", action: nil, keyEquivalent: "")
        item.tag = 2001
        
        let selector = Selector("handlePopupMenuItem:")
        controller.perform(selector, with: item)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyBundleIdStringParsesCorrectly() {
        let textField = findTextField(placeholder: "com.apple.Terminal, com.apple.dt.Xcode")
        textField?.stringValue = ""
        
        let saveSelector = Selector("handleSave")
        controller.perform(saveSelector)
        
        XCTAssertEqual(store.autoStartBundleIds, [])
    }
    
    func testWhitespaceOnlyBundleIdStringParsesCorrectly() {
        let textField = findTextField(placeholder: "com.apple.Terminal, com.apple.dt.Xcode")
        textField?.stringValue = "   ,  ,   "
        
        let saveSelector = Selector("handleSave")
        controller.perform(saveSelector)
        
        XCTAssertEqual(store.autoStartBundleIds, [])
    }
    
    func testBundleIdsWithExtraSpacesAreTrimmed() {
        let textField = findTextField(placeholder: "com.apple.Terminal, com.apple.dt.Xcode")
        textField?.stringValue = "  com.space.app1  ,  com.space.app2  "
        
        let saveSelector = Selector("handleSave")
        controller.perform(saveSelector)
        
        XCTAssertEqual(store.autoStartBundleIds, ["com.space.app1", "com.space.app2"])
    }
    
    func testInvalidMinutesDefaultsToValidValue() {
        let workField = findTextField(placeholder: "25")
        workField?.stringValue = "abc"
        
        let saveSelector = Selector("handleSave")
        controller.perform(saveSelector)
        
        XCTAssertEqual(store.workMinutes, 25)
    }
    
    // MARK: - Chips Tests
    
    func testSelectingAppCreatesChip() {
        let item = NSMenuItem(title: "Test App", action: nil, keyEquivalent: "")
        item.tag = 1002
        item.representedObject = "com.test.chip"
        
        let selector = Selector("handlePopupMenuItem:")
        controller.perform(selector, with: item)
        
        let chipsContainer = findStackView(withOrientation: .vertical, hasChips: true, isAutoStart: true)
        XCTAssertNotNil(chipsContainer, "Chips container should exist after selecting an app")
        
        let chipCount = countChips(in: chipsContainer)
        XCTAssertEqual(chipCount, 1, "Should have exactly 1 chip after selecting one app")
    }
    
    func testSelectingMultipleAppsCreatesMultipleChips() {
        let selector = Selector("handlePopupMenuItem:")
        
        let item1 = NSMenuItem(title: "App 1", action: nil, keyEquivalent: "")
        item1.tag = 1002
        item1.representedObject = "com.test.app1"
        controller.perform(selector, with: item1)
        
        let item2 = NSMenuItem(title: "App 2", action: nil, keyEquivalent: "")
        item2.tag = 1002
        item2.representedObject = "com.test.app2"
        controller.perform(selector, with: item2)
        
        let chipsContainer = findStackView(withOrientation: .vertical, hasChips: true, isAutoStart: true)
        let chipCount = countChips(in: chipsContainer)
        XCTAssertEqual(chipCount, 2, "Should have 2 chips after selecting two apps")
    }
    
    func testDeselectingAppRemovesChip() {
        let item = NSMenuItem(title: "Test App", action: nil, keyEquivalent: "")
        item.tag = 1002
        item.representedObject = "com.test.remove"
        
        let selector = Selector("handlePopupMenuItem:")
        controller.perform(selector, with: item)
        
        var chipsContainer = findStackView(withOrientation: .vertical, hasChips: true, isAutoStart: true)
        XCTAssertEqual(countChips(in: chipsContainer), 1, "Should have 1 chip after selecting")
        
        controller.perform(selector, with: item)
        
        chipsContainer = findStackView(withOrientation: .vertical, hasChips: true, isAutoStart: true)
        XCTAssertEqual(countChips(in: chipsContainer), 0, "Should have 0 chips after deselecting")
    }
    
    func testWhitelistChipsAreIndependent() {
        let selector = Selector("handlePopupMenuItem:")
        
        let autoStartItem = NSMenuItem(title: "AutoStart App", action: nil, keyEquivalent: "")
        autoStartItem.tag = 1002
        autoStartItem.representedObject = "com.test.autostart"
        controller.perform(selector, with: autoStartItem)
        
        let whitelistItem = NSMenuItem(title: "Whitelist App", action: nil, keyEquivalent: "")
        whitelistItem.tag = 2002
        whitelistItem.representedObject = "com.test.whitelist"
        controller.perform(selector, with: whitelistItem)
        
        let autoStartChips = findStackView(withOrientation: .vertical, hasChips: true, isAutoStart: true)
        let whitelistChips = findStackView(withOrientation: .vertical, hasChips: true, isAutoStart: false)
        
        XCTAssertEqual(countChips(in: autoStartChips), 1, "AutoStart should have 1 chip")
        XCTAssertEqual(countChips(in: whitelistChips), 1, "Whitelist should have 1 chip")
    }
    
    func testChipRemoveButtonRemovesApp() {
        let item = NSMenuItem(title: "Test App", action: nil, keyEquivalent: "")
        item.tag = 1002
        item.representedObject = "com.test.removebtn"
        
        let popupSelector = Selector("handlePopupMenuItem:")
        controller.perform(popupSelector, with: item)
        
        let textField = findTextField(placeholder: "com.apple.Terminal, com.apple.dt.Xcode")
        XCTAssertEqual(textField?.stringValue, "com.test.removebtn")
        
        let removeButton = findRemoveButton(forBundleId: "com.test.removebtn")
        XCTAssertNotNil(removeButton, "Remove button should exist on chip")
        
        if let button = removeButton {
            let removeSelector = Selector("handleRemoveChip:")
            XCTAssertTrue(controller.responds(to: removeSelector))
            controller.perform(removeSelector, with: button)
            
            XCTAssertEqual(textField?.stringValue, "", "Text field should be empty after removing chip")
        }
    }
    
    func testPreloadedAppsShowChipsOnInit() {
        store.autoStartBundleIds = ["com.preload.app1", "com.preload.app2"]
        
        let newController = SettingsWindowController(settings: store, statsStore: statsStore, onSave: {})
        _ = newController.window
        
        let chipsContainer = findStackView(in: newController.window?.contentView, withOrientation: .vertical, hasChips: true, isAutoStart: true)
        let chipCount = countChips(in: chipsContainer)
        XCTAssertEqual(chipCount, 2, "Should show 2 chips for preloaded apps")
    }
    
    // MARK: - Helper Methods
    
    private func findTextField(placeholder: String) -> NSTextField? {
        guard let contentView = controller.window?.contentView else { return nil }
        return findTextField(in: contentView, placeholder: placeholder)
    }
    
    private func findTextField(in view: NSView?, placeholder: String) -> NSTextField? {
        guard let view = view else { return nil }
        if let field = view as? NSTextField, field.placeholderString == placeholder {
            return field
        }
        
        for subview in view.subviews {
            if let found = findTextField(in: subview, placeholder: placeholder) {
                return found
            }
        }
        return nil
    }
    
    private func findCheckbox(in view: NSView?, title: String) -> NSButton? {
        guard let view = view else { return nil }
        if let button = view as? NSButton, button.title == title {
            return button
        }
        
        for subview in view.subviews {
            if let found = findCheckbox(in: subview, title: title) {
                return found
            }
        }
        return nil
    }
    
    private func findStackView(withOrientation orientation: NSUserInterfaceLayoutOrientation, hasChips: Bool, isAutoStart: Bool) -> NSStackView? {
        guard let contentView = controller.window?.contentView else { return nil }
        return findStackView(in: contentView, withOrientation: orientation, hasChips: hasChips, isAutoStart: isAutoStart)
    }
    
    private func findStackView(in view: NSView?, withOrientation orientation: NSUserInterfaceLayoutOrientation, hasChips: Bool, isAutoStart: Bool) -> NSStackView? {
        guard let view = view else { return nil }
        
        if let stack = view as? NSStackView, stack.orientation == orientation {
            if hasChips {
                let hasFlowContainer = stack.arrangedSubviews.contains { subview in
                    !(subview is NSStackView) && subview.subviews.contains { chip in
                        chip.subviews.contains { $0 is NSStackView }
                    }
                }
                if hasFlowContainer || stack.arrangedSubviews.isEmpty {
                    if let parentSection = findParentSection(of: stack, in: controller.window?.contentView) {
                        let isAutoStartSection = parentSection.contains("Auto Start") || parentSection.contains("Terminal")
                        if isAutoStart == isAutoStartSection {
                            return stack
                        }
                    }
                }
            }
        }
        
        for subview in view.subviews {
            if let found = findStackView(in: subview, withOrientation: orientation, hasChips: hasChips, isAutoStart: isAutoStart) {
                return found
            }
        }
        return nil
    }
    
    private func findParentSection(of target: NSView, in view: NSView?) -> String {
        guard let view = view else { return "" }
        
        for subview in view.subviews {
            if subview === target {
                return collectLabels(in: view)
            }
            let result = findParentSection(of: target, in: subview)
            if !result.isEmpty {
                return result
            }
        }
        return ""
    }
    
    private func collectLabels(in view: NSView) -> String {
        var labels: [String] = []
        if let field = view as? NSTextField, !field.isEditable {
            labels.append(field.stringValue)
        }
        if let field = view as? NSTextField {
            if let placeholder = field.placeholderString {
                labels.append(placeholder)
            }
        }
        for subview in view.subviews {
            labels.append(collectLabels(in: subview))
        }
        return labels.joined(separator: " ")
    }
    
    private func countChips(in container: NSStackView?) -> Int {
        guard let container = container else { return 0 }
        
        var count = 0
        for subview in container.arrangedSubviews {
            if !(subview is NSStackView) {
                count += subview.subviews.count
            }
        }
        return count
    }
    
    private func findRemoveButton(forBundleId bundleId: String) -> NSButton? {
        guard let contentView = controller.window?.contentView else { return nil }
        return findRemoveButton(in: contentView, forBundleId: bundleId)
    }
    
    private func findRemoveButton(in view: NSView, forBundleId bundleId: String) -> NSButton? {
        if let button = view as? NSButton,
           button.identifier?.rawValue == bundleId {
            return button
        }
        
        for subview in view.subviews {
            if let found = findRemoveButton(in: subview, forBundleId: bundleId) {
                return found
            }
        }
        return nil
    }
}
