import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The system Files picker, presented directly by UIKit. It hands Scoot a copy of the picked file,
/// so no access permission is involved (folder access was never granted on this phone, builds 21-22).
/// Used by "Importa backup" and by "Scegli un altro file" in the missing-data alarm.
enum FilesPicker {
    /// Keeps the delegate alive while the picker is open.
    private static var current: Delegate?

    static func present(types: [UTType], onPick: @escaping (URL) -> Void) {
        guard let top = topViewController() else { return }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = false
        let delegate = Delegate { url in
            current = nil
            if let url { onPick(url) }
        }
        current = delegate
        picker.delegate = delegate
        top.present(picker, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow } ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let next = top?.presentedViewController, !next.isBeingDismissed { top = next }
        return top
    }

    private final class Delegate: NSObject, UIDocumentPickerDelegate {
        let done: (URL?) -> Void
        init(done: @escaping (URL?) -> Void) { self.done = done }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            done(urls.first)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            done(nil)
        }
    }
}
