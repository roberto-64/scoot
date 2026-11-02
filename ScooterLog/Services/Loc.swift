import Foundation

/// Looks up a string for a specific language (used outside SwiftUI Text, e.g. notifications).
/// Italian text doubles as the key, so Italian simply returns the key.
enum Loc {
    static func tr(_ key: String, _ lang: String) -> String {
        if lang == "it" { return key }
        guard let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func locale(_ lang: String) -> Locale { Locale(identifier: lang) }
}
