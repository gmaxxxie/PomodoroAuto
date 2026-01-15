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
    
    private func findTextField(placeholder: String) -> NSTextField? {
        guard let contentView = controller.window?.contentView else { return nil }
        return findTextField(in: contentView, placeholder: placeholder)
    }
    
    private func findTextField(in view: NSView, placeholder: String) -> NSTextField? {
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
}
