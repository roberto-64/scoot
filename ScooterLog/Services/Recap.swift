import Foundation
import SwiftUI

/// One slice of the month: a Monday-to-Sunday week cut to the days that fall inside the month.
struct RecapWeek: Identifiable {
    let id: Date        // first day inside the month
    let end: Date       // last day inside the month
    let km: Double
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

    /// Months (newest first) that already ended and have something to show.
    static func months(vehicles: [Vehicle], now: Date = Date()) -> [Date] {
        let current = now.startOfMonth
        var found = Set<Date>()
        for it in StatsEngine.items(vehicles) { found.insert(it.date.startOfMonth) }
        for v in vehicles {
            for r in v.readings { found.insert(r.date.startOfMonth) }
        }
        for (d, km) in KmStats.perDay(vehicles) where km > 0 { found.insert(d.startOfMonth) }
        return found.filter { $0 < current }.sorted(by: >)
    }

    static func hasData(vehicles: [Vehicle], month: Date, perDay: [Date: Double]) -> Bool {
        let start = month.startOfMonth
        if StatsEngine.items(vehicles).contains(where: { $0.date.startOfMonth == start }) { return true }
        for v in vehicles where v.readings.contains(where: { $0.date.startOfMonth == start }) { return true }
        for (d, km) in perDay where km > 0 && d.startOfMonth == start { return true }
        return false
    }

    static func make(vehicles: [Vehicle], month: Date, margin: Double,
                     perDay: [Date: Double]? = nil, withPrevious: Bool = true, now: Date = Date()) -> MonthRecap {
        let start = month.startOfMonth
        let end = start.endOfMonth
        let days = perDay ?? KmStats.perDay(vehicles)
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
        r.weeks = order.map { ws in
            RecapWeek(id: firstDay[ws] ?? start, end: lastDay[ws] ?? end, km: sums[ws] ?? 0)
        }
        r.km = r.weeks.reduce(0) { $0 + $1.km }

        if withPrevious {
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
