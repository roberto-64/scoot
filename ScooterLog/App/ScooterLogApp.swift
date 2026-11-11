import SwiftUI
import SwiftData

@main
struct ScooterLogApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("language") private var language = "it"
    @AppStorage("accent") private var accentId = "amber"
    @AppStorage("faceID") private var faceID = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var locked = false

    private let container: ModelContainer = {
        let schema = Schema([
            Vehicle.self,
            FuelEntry.self,
            MaintenanceEntry.self,
            MaintenanceJob.self,
            ExpenseEntry.self,
            OdometerReading.self,
            Deadline.self,
            EntryPhoto.self
        ])
        // The database lives in Scoot's own private folder, under its own name.
        // The default location is the shared App Group folder that the signing service adds to every
        // sideloaded app, with the same file name ("default.store") for every app: another app using it
        // (Cycle, 11 Nov 2026) converted the file to its own format and Scoot's data was wiped.
        let folder = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let config = ModelConfiguration("Scoot", schema: schema, url: folder.appending(path: "Scoot.store"))
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Impossibile creare il database: \(error)")
        }
    }()

    init() {
        // Lock at launch if Face ID is on.
        let on = UserDefaults.standard.bool(forKey: "faceID")
        _locked = State(initialValue: on)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Theme.bg.ignoresSafeArea()
                RootView()
                if locked {
                    LockView(onUnlock: { locked = false })
                        .transition(.opacity)
                }
            }
            .environment(\.locale, Locale(identifier: language))
            .environment(\.appAccent, Accents.preset(accentId).color)
            .environment(\.appLocked, locked)
            .tint(Accents.preset(accentId).color)
            .preferredColorScheme(.light)
            .onChange(of: scenePhase) { _, phase in
                if phase == .background && faceID { locked = true }
            }
        }
        .modelContainer(container)
    }
}
