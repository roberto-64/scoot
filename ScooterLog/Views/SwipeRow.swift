import SwiftUI
import UIKit

/// Connects a list row to the page's scroll view so the row can be swiped sideways the way
/// WhatsApp rows are: while the row is being dragged sideways the page cannot scroll, and
/// scrolling the page or tapping somewhere else slides an open row back.
struct SwipeBridge: UIViewRepresentable {
    var isOpen: Bool
    var onBegan: () -> Void
    var onChanged: (CGFloat) -> Void
    /// Final sideways distance and speed (points per second, negative = leftwards).
    var onEnded: (CGFloat, CGFloat) -> Void
    var onClose: () -> Void

    func makeUIView(context: Context) -> SwipeBridgeView {
        let v = SwipeBridgeView()
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ v: SwipeBridgeView, context: Context) {
        v.onBegan = onBegan
        v.onChanged = onChanged
        v.onEnded = onEnded
        v.onClose = onClose
        v.isOpen = isOpen
    }
}

final class SwipeBridgeView: UIView, UIGestureRecognizerDelegate {
    var onBegan: () -> Void = {}
    var onChanged: (CGFloat) -> Void = { _ in }
    var onEnded: (CGFloat, CGFloat) -> Void = { _, _ in }
    var onClose: () -> Void = {}

    var isOpen = false {
        didSet {
            guard isOpen != oldValue else { return }
            if isOpen { startWatchingOutside() } else { stopWatchingOutside() }
        }
    }

    private static let all = NSHashTable<SwipeBridgeView>.weakObjects()
    private weak var scroll: UIScrollView?
    private var pan: UIPanGestureRecognizer?
    private var tap: UITapGestureRecognizer?
    private var lockedScrolling = false
    private var dragging = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { attach() } else { detach() }
    }

    private func attach() {
        guard pan == nil else { return }
        var v: UIView? = superview
        while let x = v, !(x is UIScrollView) { v = x.superview }
        guard let sv = v as? UIScrollView else { return }
        scroll = sv
        let p = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        p.delegate = self
        p.maximumNumberOfTouches = 1
        sv.addGestureRecognizer(p)
        pan = p
        Self.all.add(self)
        if isOpen { startWatchingOutside() }
    }

    private func detach() {
        stopWatchingOutside()
        if lockedScrolling { scroll?.isScrollEnabled = true; lockedScrolling = false }
        if let p = pan { p.view?.removeGestureRecognizer(p) }
        pan = nil
        scroll = nil
        Self.all.remove(self)
    }

    deinit {
        if lockedScrolling { scroll?.isScrollEnabled = true }
    }

    // MARK: sideways drag

    // UIView already has a method with this name, so this one must say `override`.
    // It also answers the same question when our pan or tap asks its delegate.
    override func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        guard window != nil else { return false }
        if g === tap { return true }
        guard let pan = g as? UIPanGestureRecognizer else { return false }
        guard bounds.contains(pan.location(in: self)) else { return false }
        let v = pan.velocity(in: self)
        guard abs(v.x) > abs(v.y) * 1.5 else { return false }
        return isOpen || v.x < 0
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        switch g.state {
        case .began:
            dragging = true
            // Lock the page: it must not scroll while a row is being dragged sideways.
            if let sv = scroll, sv.isScrollEnabled { sv.isScrollEnabled = false; lockedScrolling = true }
            // Only one row open at a time.
            for other in Self.all.allObjects where other !== self && other.isOpen { other.onClose() }
            onBegan()
        case .changed:
            onChanged(g.translation(in: self).x)
        case .ended, .cancelled, .failed:
            if lockedScrolling { scroll?.isScrollEnabled = true; lockedScrolling = false }
            if dragging {
                dragging = false
                onEnded(g.translation(in: self).x, g.velocity(in: self).x)
            }
        default:
            break
        }
    }

    // MARK: slide back when the person touches or scrolls elsewhere

    private func startWatchingOutside() {
        guard let sv = scroll else { return }
        if tap == nil {
            let t = UITapGestureRecognizer(target: self, action: #selector(handleOutsideTap(_:)))
            t.cancelsTouchesInView = false
            t.delegate = self
            sv.addGestureRecognizer(t)
            tap = t
        }
        sv.panGestureRecognizer.addTarget(self, action: #selector(handleScroll(_:)))
    }

    private func stopWatchingOutside() {
        if let t = tap { t.view?.removeGestureRecognizer(t) }
        tap = nil
        scroll?.panGestureRecognizer.removeTarget(self, action: #selector(handleScroll(_:)))
    }

    @objc private func handleOutsideTap(_ g: UITapGestureRecognizer) {
        guard g.state == .ended, isOpen else { return }
        // A tap on the open row itself is handled by the row (its trash block or its own tap).
        if !bounds.contains(g.location(in: self)) { onClose() }
    }

    @objc private func handleScroll(_ g: UIPanGestureRecognizer) {
        guard isOpen, !dragging, g.state == .began || g.state == .changed else { return }
        let t = g.translation(in: g.view)
        if abs(t.y) > abs(t.x) && abs(t.y) > 4 { onClose() }
    }
}
