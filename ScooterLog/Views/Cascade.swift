import SwiftUI

/// Counts how many times a tab has been switched to. RootView bumps it for the tab that is coming in;
/// everything marked with `.cascadeIn` on that screen replays its entrance.
private struct CascadeTokenKey: EnvironmentKey {
    static let defaultValue = 0
}

extension EnvironmentValues {
    var cascadeToken: Int {
        get { self[CascadeTokenKey.self] }
        set { self[CascadeTokenKey.self] = newValue }
    }
}

/// Each block of a screen rises from below with a springy bounce, one after the other (top block first).
struct CascadeIn: ViewModifier {
    @Environment(\.cascadeToken) private var token
    let index: Int
    @State private var shown = true

    /// How far a block starts below its place, in points.
    private let rise: CGFloat = 54
    /// Pause between one block and the next, in seconds.
    private let step = 0.055

    func body(content: Content) -> some View {
        content
            .offset(y: shown ? 0 : rise)
            .opacity(shown ? 1 : 0)
            .onChange(of: token) { _, _ in replay() }
    }

    private func replay() {
        guard Motion.enabled else { return }
        withTransaction(Transaction(animation: nil)) { shown = false }
        let delay = Double(min(index, 9)) * step
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(delay)) { shown = true }
        }
    }
}

extension View {
    /// Part of the tab-switch cascade. `index` is the block's place from the top (0 comes first).
    func cascadeIn(_ index: Int) -> some View { modifier(CascadeIn(index: index)) }
}
