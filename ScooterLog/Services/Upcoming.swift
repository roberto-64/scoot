import Foundation

struct UpcomingItem: Identifiable {
    let id: String
    let vehicleUID: String
    let vehicleName: String
    let title: String
    let subtitle: String
    let days: Int?
    let kmLeft: Int?
    let dueDate: Date?
    let isDeadline: Bool
    /// True when the interval comes from the official Piaggio schedule.
    var isPiaggio: Bool = false
    var state: DueState { DueState.from(days: days) }

    /// Already past: the date has passed, or the distance has passed (even when the app cannot
    /// yet estimate days from the odometer history).
    var isOverdue: Bool {
        if let k = kmLeft, k < 0 { return true }
        if let d = days { return d < 0 }
        return false
    }

    /// Due within 30 days (or right now by distance), and not yet past.
    var isComingUp: Bool {
        if isOverdue { return false }
        if let d = days { return d <= 30 }
        if let k = kmLeft { return k <= 0 }
        return false
    }
}

enum Upcoming {
    static func kmPerDay(_ v: Vehicle) -> Double? {
        let pts = v.odometerPoints.sorted { $0.date < $1.date }
        guard let first = pts.first, let last = pts.last else { return nil }
        let days = daysBetween(first.date, last.date)
        let km = last.km - first.km
        guard days >= 14, km > 0 else { return nil }
        return Double(km) / Double(days)
    }

    /// What is due within the next `window` days, or already overdue. A job that depends only on
    /// distance appears once it is estimated to fall inside the window (or its distance has passed).
    static func dueSoon(_ items: [UpcomingItem], window: Int = 30) -> [UpcomingItem] {
        items.filter { it in
            if let d = it.days { return d <= window }
            if let k = it.kmLeft { return k <= 0 }
            return false
        }
    }

    static func items(for vehicles: [Vehicle], lang: String, now: Date = Date()) -> [UpcomingItem] {
        let locale = Loc.locale(lang)
        var out: [UpcomingItem] = []
        for v in vehicles {
            for d in v.deadlines {
                out.append(UpcomingItem(
                    id: "dl.\(v.uid).\(d.kindRaw)", vehicleUID: v.uid.uuidString, vehicleName: v.displayName,
                    title: Loc.tr(d.kind.title, lang), subtitle: d.dueDate.short(locale),
                    days: daysBetween(now, d.dueDate), kmLeft: nil, dueDate: d.dueDate, isDeadline: true))
            }
            let perDay = kmPerDay(v)
            var seen = Set<String>()
            for m in v.maintenance.sorted(by: { $0.date > $1.date }) {
                for j in m.jobs {
                    let key = j.jobKey.isEmpty ? "custom:" + j.customName : j.jobKey
                    if seen.contains(key) { continue }
                    seen.insert(key)
                    guard j.ruleKm > 0 || j.ruleMonths > 0 else { continue }
                    let dueDate: Date? = j.ruleMonths > 0 ? m.date.addingMonths(j.ruleMonths) : nil
                    let dueKm: Int? = j.ruleKm > 0 ? m.odometer + j.ruleKm : nil
                    var days: Int? = dueDate.map { daysBetween(now, $0) }
                    let kmLeft: Int? = dueKm.map { $0 - v.currentOdometer }
                    if let left = kmLeft, let pd = perDay {
                        let est = Int((Double(left) / pd).rounded())
                        days = days.map { min($0, est) } ?? est
                    }
                    var parts: [String] = []
                    if let dd = dueDate { parts.append(dd.short(locale)) }
                    if let dk = dueKm { parts.append("\(dk.grouped(locale)) km") }
                    out.append(UpcomingItem(
                        id: "sv.\(v.uid).\(key)", vehicleUID: v.uid.uuidString, vehicleName: v.displayName,
                        title: Catalog.displayName(jobKey: j.jobKey, custom: j.customName, lang: lang),
                        subtitle: parts.joined(separator: " " + Loc.tr("o", lang) + " "),
                        days: days, kmLeft: kmLeft, dueDate: dueDate, isDeadline: false,
                        isPiaggio: Catalog.job(j.jobKey)?.source == .piaggio))
                }
            }
        }
        return out.sorted { a, b in
            switch (a.days, b.days) {
            case let (x?, y?): return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.title < b.title
            }
        }
    }
}
