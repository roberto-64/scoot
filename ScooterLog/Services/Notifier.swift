import Foundation
import UserNotifications

struct PlannedNotification {
    let id: String
    let title: String
    let body: String
    let fire: Date
}

enum Notifier {
    static let prefix = "sl."

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private static func nineAM(on day: Date) -> Date? {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: day)
    }

    private static func body(daysLeft: Int, lang: String) -> String {
        if daysLeft <= 0 { return Loc.tr("Scade oggi", lang) }
        if daysLeft == 1 { return Loc.tr("Scade domani", lang) }
        return String(format: Loc.tr("Scade tra %ld giorni", lang), daysLeft)
    }

    /// Plans everything on the main thread (SwiftData objects), then hands plain values to the system.
    static func reschedule(vehicles: [Vehicle], lang: String, enabled: Bool, backupReminder: Date?) {
        let now = Date()
        var planned: [PlannedNotification] = []

        if enabled {
            for v in vehicles {
                for d in v.deadlines where d.alertsOn {
                    for off in d.kind.alertOffsets {
                        guard let fire = nineAM(on: d.dueDate.addingDays(-off)), fire > now else { continue }
                        planned.append(PlannedNotification(
                            id: "\(prefix)dl.\(v.uid).\(d.kindRaw).\(off)",
                            title: "\(v.displayName): \(Loc.tr(d.kind.title, lang))",
                            body: body(daysLeft: off, lang: lang), fire: fire))
                    }
                }
            }
            for item in Upcoming.items(for: vehicles, lang: lang, now: now) where !item.isDeadline {
                guard let due = item.dueDate else { continue }
                for off in [30, 7, 1] {
                    guard let fire = nineAM(on: due.addingDays(-off)), fire > now else { continue }
                    planned.append(PlannedNotification(
                        id: "\(prefix)sv.\(item.id).\(off)",
                        title: "\(item.vehicleName): \(item.title)",
                        body: body(daysLeft: off, lang: lang), fire: fire))
                }
            }
        }
        if let b = backupReminder, b > now {
            planned.append(PlannedNotification(
                id: "\(prefix)backup",
                title: Loc.tr("Backup dei dati", lang),
                body: Loc.tr("Sono passati 30 giorni dall’ultimo backup. Esportali ora.", lang),
                fire: b))
        }
        planned.sort { $0.fire < $1.fire }
        let limited = Array(planned.prefix(60))

        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            let old = reqs.map { $0.identifier }.filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)
            for p in limited {
                let content = UNMutableNotificationContent()
                content.title = p.title
                content.body = p.body
                content.sound = .default
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: p.fire)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                center.add(UNNotificationRequest(identifier: p.id, content: content, trigger: trigger))
            }
        }
    }
}
