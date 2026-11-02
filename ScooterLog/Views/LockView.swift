import SwiftUI
import LocalAuthentication

/// Full-screen lock shown when Face ID is switched on in Settings.
/// Uses the phone's own check (Face ID, with passcode as backup).
struct LockView: View {
    let onUnlock: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("language") private var language = "it"
    @State private var busy = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: Space.s3) {
                Spacer()
                ScooterIcon(width: Space.s8)
                    .foregroundStyle(Theme.ink)
                Text("Scoot")
                    .font(AppFont.serif(32))
                    .foregroundStyle(Theme.ink)
                Text("Bloccato. Usa Face ID per entrare.")
                    .font(AppFont.sans(15))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                Spacer()
                PrimaryButton(title: "Sblocca") { unlock() }
            }
            .padding(Space.s2)
        }
        .onAppear { unlock() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { unlock() }
        }
    }

    private func unlock() {
        if busy { return }
        busy = true
        let context = LAContext()
        var error: NSError?
        // If the phone has no passcode at all, there is nothing to check
        // against: let the user in rather than lock them out for good.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            busy = false
            onUnlock()
            return
        }
        let reason = Loc.tr("Sblocca Scoot con Face ID.", language)
        Task {
            let ok = (try? await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                        localizedReason: reason)) ?? false
            busy = false
            if ok {
                Haptics.success()
                onUnlock()
            }
        }
    }
}
