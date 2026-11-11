import Foundation
import SwiftData

/// Daily automatic backups into Scoot's own folder in Files (outside the database, so a database
/// wipe like the one of 11 Nov 2026 leaves them intact). One file per day ("scoot-auto-2026-11-11.json"), the last 30 are kept.
/// An empty app is never backed up, so a wipe can never push good backups out.
enum AutoBackup {
    static let enabledKey = "autoBackup"
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

    /// Scoot's own folder, visible in Files under "Sul mio iPhone › Scoot › Backup automatici".
    /// (Picking a folder elsewhere, e.g. iCloud Drive, did not work: iPhone never handed the folder over.)
    static func folderURL() -> URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let folder = docs.appendingPathComponent("Backup automatici", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// On unless the user switched it off.
    static var isOn: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }

    // MARK: Writing

    /// Writes today's backup if automatic backups are on and none was written today.
    @discardableResult
    static func runIfDue(vehicles: [Vehicle], now: Date = Date()) -> Bool {
        let d = UserDefaults.standard
        guard isOn, entryCount(vehicles) > 0 else { return false }
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
        let target = folder.appendingPathComponent(prefix + now.formatted(.iso8601.year().month().day()) + ".json")
        var ok = false
        var coordError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: target, options: .forReplacing, error: &coordError) { url in
            ok = (try? json.write(to: url, options: .atomic)) != nil
        }
        guard ok else { return false }
        // Not counted as "Ultimo backup": that one (and its weekly reminder) is for copies kept off the phone.
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: lastKey)
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
