import Foundation

final class SettingsStore {
    private enum Keys {
        static let workMinutes = "workMinutes"
        static let breakMinutes = "breakMinutes"
        static let autoStart = "autoStart"
        static let fullscreenNonWork = "fullscreenNonWork"
        static let whitelistBundleIds = "whitelistBundleIds"
        static let autoStartBundleIds = "autoStartBundleIds"
        static let languagePreference = "languagePreference"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.workMinutes: 25,
            Keys.breakMinutes: 5,
            Keys.autoStart: true,
            Keys.fullscreenNonWork: true,
            Keys.whitelistBundleIds: [],
            Keys.autoStartBundleIds: [],
            Keys.languagePreference: LanguagePreference.system.rawValue
        ])
    }

    var workMinutes: Int {
        get { defaults.integer(forKey: Keys.workMinutes) }
        set { defaults.set(newValue, forKey: Keys.workMinutes) }
    }

    var breakMinutes: Int {
        get { defaults.integer(forKey: Keys.breakMinutes) }
        set { defaults.set(newValue, forKey: Keys.breakMinutes) }
    }

    var autoStart: Bool {
        get { defaults.bool(forKey: Keys.autoStart) }
        set { defaults.set(newValue, forKey: Keys.autoStart) }
    }

    var fullscreenNonWork: Bool {
        get { defaults.bool(forKey: Keys.fullscreenNonWork) }
        set { defaults.set(newValue, forKey: Keys.fullscreenNonWork) }
    }

    var whitelistBundleIds: [String] {
        get { defaults.stringArray(forKey: Keys.whitelistBundleIds) ?? [] }
        set { defaults.set(newValue, forKey: Keys.whitelistBundleIds) }
    }

    var autoStartBundleIds: [String] {
        get { defaults.stringArray(forKey: Keys.autoStartBundleIds) ?? [] }
        set { defaults.set(newValue, forKey: Keys.autoStartBundleIds) }
    }

    var languagePreference: LanguagePreference {
        get {
            let raw = defaults.string(forKey: Keys.languagePreference) ?? LanguagePreference.system.rawValue
            return LanguagePreference(rawValue: raw) ?? .system
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.languagePreference) }
    }

    var ruleConfig: RuleConfig {
        RuleConfig(
            fullscreenNonWork: fullscreenNonWork,
            whitelistBundleIds: Set(whitelistBundleIds),
            autoStartBundleIds: Set(autoStartBundleIds)
        )
    }

    func resetToDefaults() {
        defaults.removeObject(forKey: Keys.workMinutes)
        defaults.removeObject(forKey: Keys.breakMinutes)
        defaults.removeObject(forKey: Keys.autoStart)
        defaults.removeObject(forKey: Keys.fullscreenNonWork)
        defaults.removeObject(forKey: Keys.whitelistBundleIds)
        defaults.removeObject(forKey: Keys.autoStartBundleIds)
        defaults.removeObject(forKey: Keys.languagePreference)
    }
}
