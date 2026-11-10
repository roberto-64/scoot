import Foundation
import SwiftUI

/// One slice of the month: a Monday-to-Sunday week cut to the days that fall inside the month.
struct RecapWeek: Identifiable {
    let id: Date        // first day inside the month
    let end: Date       // last day inside the month
    let km: Double
}

/// Recaps count real use only. The entries before this date were tests, so they are ignored:
/// no recap for those months, and no km spread over the gap between an old reading and the first real one.
enum RecapStart {
    static let date: Date = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 1)) ?? .distantPast
}

/// Wrapper so a month can drive `.sheet(item:)`.
struct RecapRef: Identifiable {
    let month: Date
    var id: Date { month }
}

/// What the monthly recap says about one finished calendar month, for the vehicles in scope.
struct MonthRecap {
    let month: Date
    var km: Double = 0
    /// Everyday spending (fuel, maintenance, small expenses). Insurance, road tax and inspection are left out.
    var spent: Double = 0
    var liters: Double = 0
    var fills: Int = 0
    var kmPerL: Double? = nil
    var points: [ConsumptionPoint] = []
    var weeks: [RecapWeek] = []
    var split: [SplitSlice] = []
    var entryCount: Int = 0
    var prevKm: Double? = nil
    var prevSpent: Double? = nil
    var prevKmPerL: Double? = nil

    var hasData: Bool { entryCount > 0 || km > 0 }
    var bestWeekIndex: Int? {
        guard let top = weeks.map({ $0.km }).max(), top > 0 else { return nil }
        return weeks.firstIndex(where: { $0.km == top })
    }
    var previousMonth: Date { month.addingMonths(-1) }

    // MARK: Comparison with the month before

    /// Km difference, rounded to whole km. Nil when the month before has nothing to compare.
    var kmDelta: Int? {
        guard let p = prevKm, p > 0 else { return nil }
        return Int(km.rounded()) - Int(p.rounded())
    }
    var kmPercent: Int? {
        guard let p = prevKm, p > 0 else { return nil }
        return Int(((km - p) / p * 100).rounded())
    }
    var spentDelta: Double? {
        guard let p = prevSpent, p > 0 else { return nil }
        return (spent * 100).rounded() / 100 - (p * 100).rounded() / 100
    }
    var spentPercent: Int? {
        guard let p = prevSpent, p > 0 else { return nil }
        return Int(((spent - p) / p * 100).rounded())
    }
    var kmPerLDelta: Double? {
        guard let a = kmPerL, let b = prevKmPerL else { return nil }
        return (a * 10).rounded() / 10 - (b * 10).rounded() / 10
    }
    var kmPerLPercent: Int? {
        guard let a = kmPerL, let b = prevKmPerL, b > 0 else { return nil }
        return Int(((a - b) / b * 100).rounded())
    }
    var hasComparison: Bool { kmDelta != nil || spentDelta != nil || kmPerLDelta != nil }

    // MARK: Building

    /// Months (newest first) with something to show, from `RecapStart` on. The running month is
    /// included only when `includeCurrent` is true (the list shows it as "in corso", the pop-up never opens for it).
    static func months(vehicles: [Vehicle], includeCurrent: Bool = false, now: Date = Date()) -> [Date] {
        let current = now.startOfMonth
        var found = Set<Date>()
        for it in StatsEngine.items(vehicles) where it.date >= RecapStart.date { found.insert(it.date.startOfMonth) }
        for v in vehicles {
            for r in v.readings where r.date >= RecapStart.date { found.insert(r.date.startOfMonth) }
        }
        for (d, km) in KmStats.perDay(vehicles, since: RecapStart.date) where km > 0 { found.insert(d.startOfMonth) }
        return found.filter { includeCurrent ? $0 <= current : $0 < current }.sorted(by: >)
    }

    static func hasData(vehicles: [Vehicle], month: Date, perDay: [Date: Double]) -> Bool {
        let start = month.startOfMonth
        guard start >= RecapStart.date else { return false }
        if StatsEngine.items(vehicles).contains(where: { $0.date.startOfMonth == start }) { return true }
        for v in vehicles where v.readings.contains(where: { $0.date.startOfMonth == start }) { return true }
        for (d, km) in perDay where km > 0 && d.startOfMonth == start { return true }
        return false
    }

    static func make(vehicles: [Vehicle], month: Date, margin: Double,
                     perDay: [Date: Double]? = nil, withPrevious: Bool = true, now: Date = Date()) -> MonthRecap {
        let start = month.startOfMonth
        let end = start.endOfMonth
        let days = perDay ?? KmStats.perDay(vehicles, since: RecapStart.date)
        var r = MonthRecap(month: start)

        // Cost lines of the month.
        let inMonth = StatsEngine.items(vehicles).filter { $0.date.startOfMonth == start }
        let everyday = inMonth.filter { !$0.cat.isAnnual }
        r.spent = everyday.reduce(0) { $0 + $1.amount }
        r.split = StatsEngine.split(items: everyday)
        var readings = 0
        for v in vehicles { readings += v.readings.filter { $0.date.startOfMonth == start }.count }
        r.entryCount = inMonth.count + readings

        // Fuel.
        let cal = Calendar.current
        for v in vehicles {
            for f in v.fuelEntries where cal.isDate(f.date, equalTo: start, toGranularity: .month) {
                r.liters += f.liters
                r.fills += 1
            }
        }
        let fuel = FuelStats.summary(vehicles: vehicles, range: .month(start), marginLiters: margin, now: now)
        r.kmPerL = fuel.kmPerL
        r.points = fuel.points

        // Km, week by week (the estimate spreads the km between two readings over the days between them).
        var order: [Date] = []
        var firstDay: [Date: Date] = [:]
        var lastDay: [Date: Date] = [:]
        var sums: [Date: Double] = [:]
        var d = start
        while d <= end {
            let ws = KmStats.weekStart(d)
            if firstDay[ws] == nil {
                firstDay[ws] = d
                order.append(ws)
            }
            lastDay[ws] = d
            sums[ws, default: 0] += days[d] ?? 0
            d = d.addingDays(1)
        }
        var weeks = order.map { ws in
            RecapWeek(id: firstDay[ws] ?? start, end: lastDay[ws] ?? end, km: sums[ws] ?? 0)
        }
        // A Monday-to-Sunday week cut by the month edge can be just a day or two. Under 4 days it joins its
        // neighbour (the first one the next week, the last one the week before), so no tiny bars.
        func dayCount(_ w: RecapWeek) -> Int {
            (cal.dateComponents([.day], from: w.id, to: w.end).day ?? 0) + 1
        }
        if weeks.count > 1, dayCount(weeks[0]) < 4 {
            let a = weeks[0], b = weeks[1]
            weeks.replaceSubrange(0...1, with: [RecapWeek(id: a.id, end: b.end, km: a.km + b.km)])
        }
        if weeks.count > 1, let last = weeks.last, dayCount(last) < 4 {
            let a = weeks[weeks.count - 2]
            weeks.replaceSubrange((weeks.count - 2)..., with: [RecapWeek(id: a.id, end: last.end, km: a.km + last.km)])
        }
        r.weeks = weeks
        r.km = r.weeks.reduce(0) { $0 + $1.km }
        if r.km <= 0 {
            // No day-by-day estimate (for instance all readings on one day): fall back to the
            // distance between the lowest and highest odometer reading of the month.
            var dist = 0
            for v in vehicles {
                let kms = v.odometerPoints
                    .filter { $0.date.startOfMonth == start && $0.date >= RecapStart.date }
                    .map { $0.km }
                if let top = kms.max(), let low = kms.min() { dist += top - low }
            }
            r.km = Double(dist)
        }

        if withPrevious && start.addingMonths(-1) >= RecapStart.date {
            let prev = make(vehicles: vehicles, month: start.addingMonths(-1), margin: margin,
                            perDay: days, withPrevious: false, now: now)
            if prev.hasData {
                r.prevKm = prev.km
                r.prevSpent = prev.spent
                r.prevKmPerL = prev.kmPerL
            }
        }
        return r
    }
}

/// "2026-10": remembers which month's recap has already been shown.
enum RecapKey {
    static func string(_ month: Date) -> String {
        let c = Calendar.current
        return "\(c.component(.year, from: month))-\(c.component(.month, from: month))"
    }
}

private struct AppLockedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True while the Face ID lock screen is up (the recap must not open over it).
    var appLocked: Bool {
        get { self[AppLockedKey.self] }
        set { self[AppLockedKey.self] = newValue }
    }
}
