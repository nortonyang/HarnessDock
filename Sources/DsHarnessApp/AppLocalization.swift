import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .system:
            "跟随系统"
        case .simplifiedChinese:
            "简体中文"
        case .english:
            "English"
        }
    }

    var resolvedIdentifier: String {
        switch self {
        case .system:
            Self.systemUsesChinese ? AppLanguage.simplifiedChinese.rawValue : AppLanguage.english.rawValue
        case .simplifiedChinese, .english:
            rawValue
        }
    }

    var locale: Locale {
        Locale(identifier: resolvedIdentifier)
    }

    private static var systemUsesChinese: Bool {
        guard let preferredLanguage = Locale.preferredLanguages.first?.lowercased() else {
            return false
        }
        return preferredLanguage == "zh" || preferredLanguage.hasPrefix("zh-")
    }
}

enum AppLocalization {
    static func localized(_ key: String, language: AppLanguage) -> String {
        guard language.resolvedIdentifier == AppLanguage.english.rawValue,
              let resourcePath = Bundle.main.path(forResource: "en", ofType: "lproj"),
              let englishBundle = Bundle(path: resourcePath)
        else {
            return key
        }

        return englishBundle.localizedString(forKey: key, value: key, table: nil)
    }
}
