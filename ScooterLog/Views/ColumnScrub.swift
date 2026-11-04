import SwiftUI
import UIKit

/// Touch the bars and the month under the finger lights up at once (no waiting); drag sideways to move
/// across the `count` equal columns. Sideways movement locks the page so it does not scroll; a drag
/// that goes up or down instead hands the touch back to the page and the selection ends.
/// Lifting the finger ends the selection. Place it in the `.background` of the bars.
struct ColumnScrub: UIViewRepresentable {
    var count: Int
    var onSelect: (Int) -> Void
    var onEnd: () -> Void

    func makeUIView(context: Context) -> ColumnScrubView {
        let v = ColumnScrubView()
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ v: ColumnScrubView, context: Context) {
        v.count = count
        v.onSelect = onSelect
        v.onEnd = onEnd
    }
}

final class ColumnScrubView: UIView, UIGestureRecognizerDelegate {
    var count = 0
    var onSelect: (Int) -> Void = { _ in }
    var onEnd: () -> Void = {}

    private weak var scroll: UIScrollView?
    private var press: UILongPressGestureRecognizer?
    private var lockedScrolling = false
    private var lastIndex = -1
    private var startPoint = CGPoint.zero
    private var decided = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { attach() } else { detach() }
    }

    private func attach() {
        guard press == nil else { return }
        var v: UIView? = superview
        while let x = v, !(x is UIScrollView) { v = x.superview }
        guard let sv = v as? UIScrollView else { return }
        scroll = sv
        let g = UILongPressGestureRecognizer(target: self, action: #selector(handle(_:)))
        g.minimumPressDuration = 0
        g.cancelsTouchesInView = false
        g.delegate = self
        sv.addGestureRecognizer(g)
        press = g
    }

    private func detach() {
        if lockedScrolling { scroll?.isScrollEnabled = true; lockedScrolling = false }
        if let g = press { g.view?.removeGestureRecognizer(g) }
        press = nil
        scroll = nil
    }

    deinit {
        if lockedScrolling { scroll?.isScrollEnabled = true }
    }

    // UIView already has a method with this name, so this one must say `override`.
    override func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        guard window != nil, count > 0 else { return false }
        return bounds.contains(g.location(in: self))
    }

    /// The page's own scrolling may run alongside this touch until we know which way the finger goes.
    func gestureRecognizer(_ g: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        other === scroll?.panGestureRecognizer
    }

    @objc private func handle(_ g: UILongPressGestureRecognizer) {
        switch g.state {
        case .began:
            lastIndex = -1
            decided = false
            startPoint = g.location(in: nil)
            report(g)
        case .changed:
            if !decided {
                let p = g.location(in: nil)
                let dx = abs(p.x - startPoint.x)
                let dy = abs(p.y - startPoint.y)
                if dy > 8 && dy > dx {
                    // Going up or down: this is a scroll, not a selection.
                    decided = true
                    g.isEnabled = false
                    g.isEnabled = true
                    return
                } else if dx > 6 {
                    decided = true
                    if let sv = scroll, sv.isScrollEnabled { sv.isScrollEnabled = false; lockedScrolling = true }
                }
            }
            report(g)
        case .ended, .cancelled, .failed:
            if lockedScrolling { scroll?.isScrollEnabled = true; lockedScrolling = false }
            lastIndex = -1
            decided = false
            onEnd()
        default:
            break
        }
    }

    private func report(_ g: UILongPressGestureRecognizer) {
        guard count > 0, bounds.width > 0 else { return }
        let x = g.location(in: self).x
        let i = min(max(Int(x / (bounds.width / CGFloat(count))), 0), count - 1)
        if i != lastIndex {
            lastIndex = i
            onSelect(i)
        }
    }
}
