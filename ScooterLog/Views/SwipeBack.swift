import SwiftUI
import UIKit
import ObjectiveC

/// Marks an area where the "swipe anywhere to go back" gesture must not start
/// (charts you drag across, a list row that is swiped open).
struct SwipeBackBlocker: UIViewRepresentable {
    var active: Bool = true

    func makeUIView(context: Context) -> BlockerView {
        let v = BlockerView()
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        v.active = active
        return v
    }

    func updateUIView(_ v: BlockerView, context: Context) {
        v.active = active
    }
}

final class BlockerView: UIView {
    var active = true
    private static let registry = NSHashTable<BlockerView>.weakObjects()

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { Self.registry.add(self) } else { Self.registry.remove(self) }
    }

    static func blocks(_ touch: UITouch) -> Bool {
        for v in registry.allObjects where v.active {
            guard let w = v.window, touch.window === w else { continue }
            if v.bounds.contains(touch.location(in: v)) { return true }
        }
        return false
    }
}

extension View {
    /// Keeps the swipe-anywhere-to-go-back gesture away from this view.
    func blocksSwipeBack(_ active: Bool = true) -> some View {
        background(SwipeBackBlocker(active: active))
    }
}

// MARK: - Swipe anywhere to go back (from left to right, like Apollo)

let fullSwipeBackName = "sl.fullSwipeBack"

extension UINavigationController: UIGestureRecognizerDelegate {
    // The navigation bar is hidden on every screen, which switches off the built-in edge swipe,
    // so the delegate below turns it back on. On top of that a second recogniser that works
    // from anywhere on the screen drives the same back transition.
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
        installFullSwipeBack()
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard viewControllers.count > 1 else { return false }
        if gestureRecognizer.name == fullSwipeBackName, let pan = gestureRecognizer as? UIPanGestureRecognizer {
            let v = pan.velocity(in: view)
            return v.x > 0 && abs(v.x) > abs(v.y) * 1.5
        }
        return true
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer.name == fullSwipeBackName { return !BlockerView.blocks(touch) }
        return true
    }

    private func installFullSwipeBack() {
        if (view.gestureRecognizers ?? []).contains(where: { $0.name == fullSwipeBackName }) { return }
        guard let edge = interactivePopGestureRecognizer, let target = Self.popTarget(of: edge) else { return }
        let pan = UIPanGestureRecognizer(target: target, action: Selector(("handleNavigationTransition:")))
        pan.name = fullSwipeBackName
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        view.addGestureRecognizer(pan)
    }

    /// The object the built-in edge swipe sends its events to. Looked up defensively:
    /// if the internal names ever change, the full-width swipe is skipped and nothing else breaks.
    private static func popTarget(of recognizer: UIGestureRecognizer) -> NSObject? {
        guard class_getInstanceVariable(UIGestureRecognizer.self, "_targets") != nil,
              let targets = recognizer.value(forKey: "_targets") as? [NSObject],
              let first = targets.first,
              class_getInstanceVariable(type(of: first), "_target") != nil,
              let target = first.value(forKey: "target") as? NSObject,
              target.responds(to: Selector(("handleNavigationTransition:")))
        else { return nil }
        return target
    }
}
