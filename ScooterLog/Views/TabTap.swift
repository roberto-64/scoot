import SwiftUI
import UIKit

/// Tapping the tab you are already on: go back one page if you are inside a sub-page,
/// otherwise scroll the page to the top.
enum TabTap {
    static let name = Notification.Name("scoot.tabTap")

    static func send(_ tab: AppTab) {
        NotificationCenter.default.post(name: name, object: nil, userInfo: ["tab": tab.rawValue])
    }
}

/// Put it in the background of a tab's main page (inside its scroll view). It listens for taps on its own tab.
struct TabTapHelper: UIViewRepresentable {
    let tab: AppTab

    func makeUIView(context: Context) -> TabTapView {
        let v = TabTapView()
        v.tab = tab
        return v
    }

    func updateUIView(_ v: TabTapView, context: Context) {
        v.tab = tab
    }
}

final class TabTapView: UIView {
    var tab: AppTab = .home
    private var token: NSObjectProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        token = NotificationCenter.default.addObserver(forName: TabTap.name, object: nil, queue: .main) { [weak self] n in
            guard let self = self, (n.userInfo?["tab"] as? Int) == self.tab.rawValue else { return }
            self.handle()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        if let t = token { NotificationCenter.default.removeObserver(t) }
    }

    private func controller() -> UIViewController? {
        var r: UIResponder? = self
        while let n = r?.next {
            if let vc = n as? UIViewController { return vc }
            r = n
        }
        return nil
    }

    private func handle() {
        if let nav = controller()?.navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
            return
        }
        var v: UIView? = superview
        while let x = v {
            if let s = x as? UIScrollView {
                s.setContentOffset(CGPoint(x: s.contentOffset.x, y: -s.adjustedContentInset.top), animated: true)
                return
            }
            v = x.superview
        }
    }
}
