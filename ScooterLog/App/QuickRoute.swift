import SwiftUI
import AppIntents

/// A request from outside the app (Shortcuts, Control Center, the home-screen icon menu) to open
/// the new-entry sheet straight on one of its forms.
final class QuickRoute: ObservableObject {
    static let shared = QuickRoute()
    @Published var pending: NewRoute? = nil
}

// MARK: Shortcuts

/// "Nuovo rifornimento": opens Scoot on the new fill-up form. In the Shortcuts app it can be added
/// to a shortcut, and a shortcut can be put in Control Center, on the Action Button or the lock screen.
struct NewFuelIntent: AppIntent {
    static let title: LocalizedStringResource = "Nuovo rifornimento"
    static let description = IntentDescription("Apre Scoot sul modulo del nuovo rifornimento.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickRoute.shared.pending = .fuel
        return .result()
    }
}

struct ScootShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NewFuelIntent(),
            phrases: ["Nuovo rifornimento in \(.applicationName)"],
            shortTitle: "Nuovo rifornimento",
            systemImageName: "fuelpump"
        )
    }
}

// MARK: Home-screen icon menu (long press)

enum QuickActions {
    static let newFuelType = "com.personal.scooterlog.newfuel"

    @discardableResult
    static func handle(_ item: UIApplicationShortcutItem) -> Bool {
        guard item.type == newFuelType else { return false }
        DispatchQueue.main.async { QuickRoute.shared.pending = .fuel }
        return true
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Launched from the icon menu: the item arrives here, not in the scene delegate.
        if let item = options.shortcutItem { QuickActions.handle(item) }
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    // App already running in the background.
    func windowScene(_ windowScene: UIWindowScene,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        completionHandler(QuickActions.handle(shortcutItem))
    }
}
