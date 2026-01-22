import Foundation

enum LanguagePreference: String, CaseIterable {
    case system = "system"
    case english = "en"
    case chineseSimplified = "zh-Hans"

    var appleLanguageCode: String? {
        switch self {
        case .system:
            return nil
        case .english:
            return "en"
        case .chineseSimplified:
            return "zh-Hans"
        }
    }
}

enum Localization {
    private static var overrideBundle: Bundle?

    static func apply(preference: LanguagePreference) {
        let defaults = UserDefaults.standard
        if let code = preference.appleLanguageCode {
            defaults.set([code], forKey: "AppleLanguages")
            overrideBundle = bundle(for: code)
        } else {
            defaults.removeObject(forKey: "AppleLanguages")
            overrideBundle = nil
        }
    }

    static func localized(_ key: String) -> String {
        let bundle = overrideBundle ?? Bundle.module
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    static func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: localized(key), arguments: arguments)
    }

    private static func bundle(for languageCode: String) -> Bundle? {
        let candidates = [
            languageCode,
            languageCode.lowercased()
        ]

        for code in candidates {
            if let path = Bundle.module.path(forResource: code, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }

        return nil
    }
}
