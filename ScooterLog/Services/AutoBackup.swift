import Foundation
import SwiftData

/// Daily automatic backups to a folder the user picked once (usually in iCloud Drive), so the data
/// also lives outside the app. One file per day ("scoot-auto-2026-11-11.json"), the last 30 are kept.
/// An empty app is never backed up, so a wipe can never push good backups out.
enum AutoBackup {
    static let enabledKey = "autoBackup"
    static let folderKey = "autoBackupFolder"   // security-scoped bookmark of the folder
    static let lastKey = "lastAutoBackup"       // time of the last automatic backup
    static let keep = 30
    static let prefix = "scoot-auto-"

    /// A backup found in the folder, ready to restore.
    struct Found {
        let date: Date
        let count: Int
        let data: Data
    }

    /// Everything the user logged: vehicles plus all their entries.
    static func entryCount(_ vehicles: [Vehicle]) -> Int {
        vehicles.reduce(0) {
            $0 + 1 + $1.fuelEntries.count + $1.maintenance.count + $1.expenses.count + $1.readings.count + $1.deadlines.count
        }
    }

    static func entryCount(_ file: BackupFile) -> Int {
        file.vehicles.reduce(0) {
            $0 + 1 + $1.fuel.count + $1.maintenance.count + $1.expenses.count + $1.readings.count + $1.deadlines.count
        }
    }

    // MARK: Folder

    static var hasFolder: Bool { UserDefaults.standard.data(forKey: folderKey) != nil }

    /// Remembers the folder picked in the system folder picker.
    static func saveFolder(_ url: URL) -> Bool {
        let opened = url.startAccessingSecurityScopedResource()
        defer { if opened { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else {
            return false
        }
        UserDefaults.standard.set(data, forKey: folderKey)
        return true
    }

    static func folderURL() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: folderKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else {
            return nil
        }
        if stale {
            let opened = url.startAccessingSecurityScopedResource()
            if let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(fresh, forKey: folderKey)
            }
            if opened { url.stopAccessingSecurityScopedResource() }
        }
        return url
    }

    static func folderName() -> String? { folderURL()?.lastPathComponent }

    // MARK: Writing

    /// Writes today's backup if automatic backups are on and none was written today.
    @discardableResult
    static func runIfDue(vehicles: [Vehicle], now: Date = Date()) -> Bool {
        let d = UserDefaults.standard
        guard d.bool(forKey: enabledKey), hasFolder, entryCount(vehicles) > 0 else { return false }
        let last = d.double(forKey: lastKey)
        if last > 0, Calendar.current.isDate(Date(timeIntervalSince1970: last), inSameDayAs: now) { return false }
        return write(vehicles: vehicles, now: now)
    }

    /// Writes (or replaces) today's backup file now.
    @discardableResult
    static func write(vehicles: [Vehicle], now: Date = Date()) -> Bool {
        guard entryCount(vehicles) > 0, let folder = folderURL(), let json = BackupService.makeJSON(vehicles) else {
            return false
        }
        let opened = folder.startAccessingSecurityScopedResource()
        defer { if opened { folder.stopAccessingSecurityScopedResource() } }
        let target = folder.appendingPathComponent(prefix + now.formatted(.iso8601.year().month().day()) + ".json")
        var ok = false
        var coordError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: target, options: .forReplacing, error: &coordError) { url in
            ok = (try? json.write(to: url, options: .atomic)) != nil
        }
        guard ok else { return false }
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: lastKey)
        // An automatic backup also counts as a backup for the "Ultimo backup" line and the reminder.
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "lastBackup")
        prune(folder)
        return true
    }

    /// Keeps the newest `keep` automatic backups and deletes the older ones.
    private static func prune(_ folder: URL) {
        let files = backupFiles(in: folder)
        guard files.count > keep else { return }
        for old in files.dropFirst(keep) {
            var coordError: NSError?
            NSFileCoordinator().coordinate(writingItemAt: old, options: .forDeleting, error: &coordError) { url in
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    /// Automatic backup files in the folder, newest first. Files in iCloud that are not on the phone
    /// show up as ".scoot-auto-….json.icloud"; they are mapped back to their real name (reading them downloads them).
    private static func backupFiles(in folder: URL) -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        var real = Set<String>()
        for n in names {
            var name = n
            if name.hasPrefix("."), name.hasSuffix(".icloud") {
                name = String(name.dropFirst().dropLast(".icloud".count))
            }
            if name.hasPrefix(prefix), name.hasSuffix(".json") { real.insert(name) }
        }
        return real.sorted(by: >).map { folder.appendingPathComponent($0) }
    }

    // MARK: Reading

    /// The newest valid automatic backup, or nil. Can take a moment (it may download from iCloud),
    /// so call it off the main thread.
    static func latest() -> Found? {
        guard let folder = folderURL() else { return nil }
        let opened = folder.startAccessingSecurityScopedResource()
        defer { if opened { folder.stopAccessingSecurityScopedResource() } }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        for file in backupFiles(in: folder) {
            var data: Data?
            var coordError: NSError?
            NSFileCoordinator().coordinate(readingItemAt: file, options: [], error: &coordError) { url in
                data = try? Data(contentsOf: url)
            }
            if let data, let decoded = try? decoder.decode(BackupFile.self, from: data), entryCount(decoded) > 0 {
                return Found(date: decoded.exportedAt, count: entryCount(decoded), data: data)
            }
        }
        return nil
    }
}
