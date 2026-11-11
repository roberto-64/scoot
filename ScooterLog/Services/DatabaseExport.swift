import Foundation
import SwiftData

/// Diagnostics: copies the raw database files as they are on the phone (nothing is opened or changed)
/// plus a short report (file sizes and dates, app version, a few settings), and zips them to share.
enum DatabaseExport {
    static func makeZip(container: ModelContainer) -> URL? {
        let fm = FileManager.default
        guard let storeURL = container.configurations.first?.url else { return nil }
        let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
            .replacingOccurrences(of: ":", with: "-")
        let dir = fm.temporaryDirectory.appendingPathComponent("scoot-database-\(stamp)", isDirectory: true)
        try? fm.removeItem(at: dir)
        do { try fm.createDirectory(at: dir, withIntermediateDirectories: true) } catch { return nil }

        // The store and its companions: default.store, default.store-wal, default.store-shm and the
        // hidden folder for photos kept outside the database (.default_SUPPORT).
        let folder = storeURL.deletingLastPathComponent()
        let base = storeURL.lastPathComponent
        let stem = (base as NSString).deletingPathExtension
        let names = (try? fm.contentsOfDirectory(atPath: folder.path)) ?? []
        for name in names where name.hasPrefix(base) || name.hasPrefix("." + stem) {
            try? fm.copyItem(at: folder.appendingPathComponent(name), to: dir.appendingPathComponent(name))
        }

        let report = makeReport(storeURL: storeURL)
        try? report.data(using: .utf8)?.write(to: dir.appendingPathComponent("report.txt"))

        // The system zips a folder when it is read "for uploading".
        var zipURL: URL?
        var coordError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: dir, options: .forUploading, error: &coordError) { tmp in
            let dest = fm.temporaryDirectory.appendingPathComponent("\(dir.lastPathComponent).zip")
            try? fm.removeItem(at: dest)
            if (try? fm.copyItem(at: tmp, to: dest)) != nil { zipURL = dest }
        }
        return zipURL
    }

    private static func makeReport(storeURL: URL) -> String {
        let fm = FileManager.default
        let info = Bundle.main.infoDictionary
        var lines: [String] = []
        lines.append("Scoot database report")
        lines.append("Created: \(Date().formatted(.iso8601))")
        lines.append("Version: \(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))")
        lines.append("Bundle: \(Bundle.main.bundleIdentifier ?? "?")")
        lines.append("Store: \(storeURL.path)")
        lines.append("")

        let keys: [URLResourceKey] = [.fileSizeKey, .creationDateKey, .contentModificationDateKey, .isDirectoryKey]
        var roots: [URL] = []
        roots += fm.urls(for: .libraryDirectory, in: .userDomainMask)
        roots += fm.urls(for: .documentDirectory, in: .userDomainMask)
        for root in roots {
            lines.append("== \(root.path)")
            let walker = fm.enumerator(at: root, includingPropertiesForKeys: keys, options: [])
            while let url = walker?.nextObject() as? URL {
                if url.path.contains("/Caches/") { continue }
                let v = try? url.resourceValues(forKeys: Set(keys))
                let size = v?.fileSize.map { "\($0) B" } ?? (v?.isDirectory == true ? "dir" : "?")
                let created = v?.creationDate.map { $0.formatted(.iso8601) } ?? "?"
                let modified = v?.contentModificationDate.map { $0.formatted(.iso8601) } ?? "?"
                let rel = url.path.replacingOccurrences(of: root.path, with: "")
                lines.append("\(rel) | \(size) | created \(created) | modified \(modified)")
            }
            lines.append("")
        }

        lines.append("== Settings")
        let d = UserDefaults.standard
        for k in ["lastBackup", "recapSeen", "tankSeen", "tankArmed", "language", "accent", "faceID", "tankMargin"] {
            if let v = d.object(forKey: k) {
                if k == "lastBackup", let t = v as? Double, t > 0 {
                    lines.append("\(k): \(Date(timeIntervalSince1970: t).formatted(.iso8601))")
                } else {
                    lines.append("\(k): \(v)")
                }
            } else {
                lines.append("\(k): (not set)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
