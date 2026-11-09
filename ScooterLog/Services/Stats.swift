import Foundation

enum StatRange: Hashable {
    case m3, m6, y1, all, year(Int), month(Date)

    /// Interval start (nil = from the beginning) and an exclusive end.
    func interval(now: Date = Date()) -> (start: Date?, end: Date) {
        let cal = Calendar.current
        let endNow = cal.startOfDay(for: now).addingDays(1)
        switch self {
        case .m3: return (now.addingMonths(-3), endNow)
        case .m6: return (now.addingMonths(-6), endNow)
        case .y1: return (now.addingMonths(-12), endNow)
        case .all: return (nil, endNow)
        case .year(let y):
            let s = cal.date(from: DateComponents(year: y, month: 1, day: 1))
            let e = cal.date(from: DateComponents(year: y + 1, month: 1, day: 1)) ?? endNow
            return (s, min(e, endNow))
        case .month(let d):
            let s = d.startOfMonth
            return (s, min(s.addingMonths(1), endNow))
        }
    }

    func contains(_ d: Date, now: Date = Date()) -> Bool {
        let iv = interval(now: now)
        if let s = iv.start, d < s { return false }
        return d < iv.end
    }
}

enum CostCat: String, Hashable {
    case fuel, maintenance, rca, bollo, revisione, other
    var isAnnual: Bool { self == .rca || self == .bollo || self == .revisione }
    var title: String {
        switch self {
        case .fuel: return "Carburante"
        case .maintenance: return "Manutenzione"
        case .rca: return "Assicurazione"
        case .bollo: return "Bollo"
        case .revisione: return "Revisione"
        case .other: return "Altro"
        }
    }
}

struct CostItem {
    let date: Date
    let amount: Double
    let cat: CostCat
    let cover: Int
    /// Name shown in the held-month legend (e.g. "Parcheggio"); falls back to the category name.
    var label: String? = nil
    var legendTitle: String { label ?? cat.title }
}

/// One line of a month's breakdown: a category name and what it added up to.
struct MonthPart: Identifiable {
    let title: String
    var amount: Double
    let annual: Bool
    var id: String { (annual ? "a." : "v.") + title }
}

struct MonthBucket: Identifiable {
    let id: Date
    var variable: Double
    var annual: Double
    var parts: [MonthPart] = []
    var total: Double { variable + annual }

    mutating func add(_ title: String, _ amount: Double, annual isAnnual: Bool) {
        if isAnnual { annual += amount } else { variable += amount }
        if let i = parts.firstIndex(where: { $0.title == title && $0.annual == isAnnual }) {
            parts[i].amount += amount
        } else {
            parts.append(MonthPart(title: title, amount: amount, annual: isAnnual))
        }
    }
}

struct SplitSlice: Identifiable {
    let id: String
    let title: String
    let amount: Double
    let share: Double
    let tint: Int
}

struct ConsumptionPoint: Identifiable {
    let id = UUID()
    let date: Date
    let kmPerL: Double
}

struct PricePoint: Identifiable {
    let id = UUID()
    let date: Date
    let price: Double
}

struct StatsSummary {
    var total: Double = 0
    var perMonth: Double = 0
    var distance: Int? = nil
    var perKm: Double? = nil
    var entryCount: Int = 0
    var months: [MonthBucket] = []
    var split: [SplitSlice] = []
    var hasData: Bool { entryCount > 0 }
}

struct FuelSummary {
    var kmPerL: Double? = nil
    var margin: Double? = nil
    var points: [ConsumptionPoint] = []
    var best: Double? = nil
    var worst: Double? = nil
    var avgPrice: Double? = nil
    var fuelCostPerKm: Double? = nil
    var litersPerStop: Double? = nil
    var kmBetweenStops: Double? = nil
    var pricePoints: [PricePoint] = []
    var fillsInRange: Int = 0
    /// True when the consumption figures come from reserve-light to reserve-light stretches.
    var usesReserve: Bool = false
}

enum StatsEngine {
    static let windowKm = 400

    static func items(_ vs: [Vehicle]) -> [CostItem] {
        var out: [CostItem] = []
        for v in vs {
            for f in v.fuelEntries { out.append(CostItem(date: f.date, amount: f.total, cat: .fuel, cover: 1)) }
            for m in v.maintenance { out.append(CostItem(date: m.date, amount: m.total, cat: .maintenance, cover: 1)) }
            for e in v.expenses {
                let cat: CostCat
                switch e.category {
                case .rca: cat = .rca
                case .bollo: cat = .bollo
                case .revisione: cat = .revisione
                default: cat = .other
                }
                out.append(CostItem(date: e.date, amount: e.amount, cat: cat, cover: max(1, e.coverMonths),
                                    label: cat == .other ? e.category.title : nil))
            }
        }
        return out
    }

    /// Calendar months from `first` to `now`, counting both ends (March to October = 8).
    static func monthsSpan(from first: Date, to now: Date = Date()) -> Int {
        let c = Calendar.current
        let y = c.component(.year, from: now) - c.component(.year, from: first)
        let m = c.component(.month, from: now) - c.component(.month, from: first)
        return max(1, y * 12 + m + 1)
    }

    static func summary(vehicles: [Vehicle], range: StatRange, spread: Bool, now: Date = Date()) -> StatsSummary {
        let all = items(vehicles)
        let inRange = all.filter { range.contains($0.date, now: now) }
        var s = StatsSummary()
        s.entryCount = inRange.count
        s.total = inRange.reduce(0) { $0 + $1.amount }

        if let firstAll = all.map({ $0.date }).min() {
            let iv = range.interval(now: now)
            let from = max(iv.start ?? firstAll, firstAll)
            let to = min(iv.end.addingDays(-1), now)
            s.perMonth = s.total / Double(monthsSpan(from: from, to: max(to, from)))
        }

        var dist = 0
        let iv = range.interval(now: now)
        for v in vehicles {
            let pts = v.odometerPoints.sorted { $0.date < $1.date }
            let inside = pts.filter { range.contains($0.date, now: now) }
            guard let top = inside.map({ $0.km }).max() else { continue }
            var base = inside.map({ $0.km }).min() ?? top
            if let st = iv.start, let before = pts.last(where: { $0.date < st }) { base = min(base, before.km) }
            dist += max(0, top - base)
        }
        if dist > 0 {
            s.distance = dist
            if s.total > 0 { s.perKm = s.total / Double(dist) }
        }
        s.months = monthBuckets(items: all, range: range, spread: spread, now: now)
        s.split = split(items: inRange)
        return s
    }

    static func monthBuckets(items: [CostItem], range: StatRange, spread: Bool, now: Date = Date()) -> [MonthBucket] {
        let cal = Calendar.current
        let nowMonth = now.startOfMonth
        var starts: [Date] = []
        switch range {
        case .year(let y):
            for m in 1...12 {
                if let d = cal.date(from: DateComponents(year: y, month: m, day: 1)) { starts.append(d) }
            }
        default:
            var n = 6
            switch range {
            case .m3: n = 3
            case .m6: n = 6
            case .y1: n = 12
            default:
                if let first = items.map({ $0.date }).min() { n = min(monthsSpan(from: first, to: now), 12) }
                else { n = 6 }
            }
            var k = n - 1
            while k >= 0 {
                starts.append(nowMonth.addingMonths(-k))
                k -= 1
            }
        }
        let frozen = starts
        var buckets: [MonthBucket] = frozen.map { MonthBucket(id: $0, variable: 0, annual: 0) }
        for it in items {
            if spread && it.cat.isAnnual && it.cover > 1 {
                let per = it.amount / Double(it.cover)
                for k in 0..<it.cover {
                    let m = it.date.startOfMonth.addingMonths(k)
                    if let i = frozen.firstIndex(of: m) { buckets[i].add(it.legendTitle, per, annual: true) }
                }
            } else if let i = frozen.firstIndex(of: it.date.startOfMonth) {
                buckets[i].add(it.legendTitle, it.amount, annual: it.cat.isAnnual)
            }
        }
        return buckets
    }

    static func split(items: [CostItem]) -> [SplitSlice] {
        var sums: [CostCat: Double] = [:]
        for it in items { sums[it.cat, default: 0] += it.amount }
        let total = sums.values.reduce(0, +)
        guard total > 0 else { return [] }
        let sorted = sums.sorted { $0.value > $1.value }
        var out: [SplitSlice] = []
        for (i, e) in sorted.enumerated() where i < 3 && (sorted.count <= 3 || i < 2) {
            out.append(SplitSlice(id: e.key.rawValue, title: e.key.title, amount: e.value, share: e.value / total, tint: i))
        }
        if sorted.count > 3 {
            let rest = sorted.dropFirst(2).reduce(0) { $0 + $1.value }
            out.append(SplitSlice(id: "rest", title: "Altro", amount: rest, share: rest / total, tint: 2))
        }
        return out
    }

    /// Recurring yearly costs plus average variable spending times 12. Needs at least 3 months of data.
    static func annualEstimate(vehicles: [Vehicle], now: Date = Date()) -> (recurring: Double, variable: Double)? {
        let all = items(vehicles)
        guard let first = all.map({ $0.date }).min() else { return nil }
        let months = monthsSpan(from: first, to: now)
        guard months >= 3 else { return nil }
        var recurring = 0.0
        for cat in [CostCat.rca, CostCat.bollo, CostCat.revisione] {
            if let last = all.filter({ $0.cat == cat }).max(by: { $0.date < $1.date }) {
                recurring += cat == .revisione ? last.amount / 2 : last.amount
            }
        }
        let variable = all.filter { !$0.cat.isAnnual }.reduce(0) { $0 + $1.amount } / Double(months) * 12
        if recurring == 0 && variable == 0 { return nil }
        return (recurring, variable)
    }
}

enum FuelStats {
    static func summary(vehicles: [Vehicle], range: StatRange, marginLiters: Double, now: Date = Date()) -> FuelSummary {
        var out = FuelSummary()
        var totalDist = 0
        var totalLiters = 0.0
        var costAfterFirst = 0.0
        var gaps = 0
        var gapDist = 0
        var allLiters = 0.0
        var allCost = 0.0
        var stops = 0
        var reservePoints: [ConsumptionPoint] = []
        var reserveDist = 0
        var reserveLiters = 0.0

        for v in vehicles {
            let fills = v.fuelEntries.sorted { $0.odometer < $1.odometer }

            // Reserve-light stretches: from one fill-up made with the light on to the next one.
            // Litres = the first marked fill-up plus every fill-up in between, not the closing one
            // (the tank was back at reserve level just before the closing fill-up).
            let marked = fills.indices.filter { fills[$0].reserveLight }
            if marked.count >= 2 {
                for m in 1..<marked.count {
                    let a = marked[m - 1], b = marked[m]
                    guard range.contains(fills[b].date, now: now) else { continue }
                    var liters = 0.0
                    for k in a..<b { liters += fills[k].liters }
                    let dist = fills[b].odometer - fills[a].odometer
                    if liters > 0 && dist > 0 {
                        reservePoints.append(ConsumptionPoint(date: fills[b].date, kmPerL: Double(dist) / liters))
                        reserveDist += dist
                        reserveLiters += liters
                    }
                }
            }

            // Rolling windows of at least `windowKm`, ending at each fill.
            if fills.count >= 2 {
                for j in 1..<fills.count {
                    var i = j - 1
                    var found = false
                    while i >= 0 {
                        if fills[j].odometer - fills[i].odometer >= StatsEngine.windowKm { found = true; break }
                        i -= 1
                    }
                    guard found, range.contains(fills[j].date, now: now) else { continue }
                    var liters = 0.0
                    for k in (i + 1)...j { liters += fills[k].liters }
                    let dist = fills[j].odometer - fills[i].odometer
                    if liters > 0 && dist > 0 {
                        out.points.append(ConsumptionPoint(date: fills[j].date, kmPerL: Double(dist) / liters))
                    }
                }
            }

            let inside = fills.filter { range.contains($0.date, now: now) }
            for f in inside {
                allLiters += f.liters
                allCost += f.total
                stops += 1
                out.pricePoints.append(PricePoint(date: f.date, price: f.pricePerLiter))
            }
            if inside.count >= 2, let first = inside.first, let last = inside.last {
                let dist = last.odometer - first.odometer
                let liters = inside.dropFirst().reduce(0.0) { $0 + $1.liters }
                if dist > 0 && liters > 0 {
                    totalDist += dist
                    totalLiters += liters
                    costAfterFirst += inside.dropFirst().reduce(0.0) { $0 + $1.total }
                    gaps += inside.count - 1
                    gapDist += dist
                }
            }
        }

        // With at least one reserve-light stretch in range, those replace the 400 km windows.
        if !reservePoints.isEmpty && reserveLiters > 0 {
            out.points = reservePoints
            out.usesReserve = true
        }
        out.points.sort { $0.date < $1.date }
        out.pricePoints.sort { $0.date < $1.date }
        out.fillsInRange = stops
        if totalLiters > 0 {
            out.kmPerL = Double(totalDist) / totalLiters
            out.margin = min(marginLiters / totalLiters, 0.99)
            if totalDist > 0 { out.fuelCostPerKm = costAfterFirst / Double(totalDist) }
        }
        if out.usesReserve {
            out.kmPerL = Double(reserveDist) / reserveLiters
            out.margin = min(marginLiters / reserveLiters, 0.99)
        }
        if allLiters > 0 { out.avgPrice = allCost / allLiters }
        if stops > 0 { out.litersPerStop = allLiters / Double(stops) }
        if gaps > 0 { out.kmBetweenStops = Double(gapDist) / Double(gaps) }
        out.best = out.points.map { $0.kmPerL }.max()
        out.worst = out.points.map { $0.kmPerL }.min()
        return out
    }
}

/// One period of the km chart: a calendar month or a week (Monday to Sunday).
struct KmBucket: Identifiable {
    let id: Date        // first day
    let end: Date       // last day
    let km: Double
}

enum KmStats {
    private static var weekCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = Calendar.current.timeZone
        c.firstWeekday = 2
        c.minimumDaysInFirstWeek = 4
        return c
    }

    /// Monday of the week that contains `d`.
    static func weekStart(_ d: Date) -> Date {
        weekCalendar.dateInterval(of: .weekOfYear, for: d)?.start ?? Calendar.current.startOfDay(for: d)
    }

    /// Km driven on each day. The odometer is only read now and then, so the km between two readings
    /// are spread evenly over the days between them. It is an estimate for any single day or week.
    /// With `since`, readings before that date are ignored (so a long gap before it is not spread forward).
    static func perDay(_ vehicles: [Vehicle], since: Date? = nil) -> [Date: Double] {
        let cal = Calendar.current
        var out: [Date: Double] = [:]
        for v in vehicles {
            var byDay: [Date: Int] = [:]
            for p in v.odometerPoints where since == nil || p.date >= since! {
                let d = cal.startOfDay(for: p.date)
                byDay[d] = max(byDay[d] ?? 0, p.km)
            }
            var prevDay: Date? = nil
            var prevKm = 0
            for d in byDay.keys.sorted() {
                let km = byDay[d] ?? 0
                if let pd = prevDay {
                    let gain = km - prevKm
                    if gain > 0 {
                        let n = max(1, daysBetween(pd, d))
                        let each = Double(gain) / Double(n)
                        var day = pd.addingDays(1)
                        for _ in 0..<n {
                            out[day, default: 0] += each
                            day = day.addingDays(1)
                        }
                    }
                    prevKm = max(prevKm, km)
                } else {
                    prevKm = km
                }
                prevDay = d
            }
        }
        return out
    }

    /// One bucket per month start given (oldest first).
    static func months(vehicles: [Vehicle], starts: [Date]) -> [KmBucket] {
        let days = perDay(vehicles)
        var sums: [Date: Double] = [:]
        for (d, km) in days { sums[d.startOfMonth, default: 0] += km }
        return starts.map { KmBucket(id: $0, end: $0.endOfMonth, km: sums[$0] ?? 0) }
    }

    /// The last `count` weeks, the current one last.
    static func weeks(vehicles: [Vehicle], count: Int, now: Date = Date()) -> [KmBucket] {
        let days = perDay(vehicles)
        var sums: [Date: Double] = [:]
        for (d, km) in days { sums[weekStart(d), default: 0] += km }
        let thisWeek = weekStart(now)
        var out: [KmBucket] = []
        var k = count - 1
        while k >= 0 {
            let s = thisWeek.addingDays(-7 * k)
            out.append(KmBucket(id: s, end: s.addingDays(6), km: sums[s] ?? 0))
            k -= 1
        }
        return out
    }

    /// Total km in the calendar year (same estimate), and the first day with any km counted.
    static func year(vehicles: [Vehicle], year: Int) -> (km: Double, first: Date?) {
        let cal = Calendar.current
        var km = 0.0
        var first: Date? = nil
        for (d, v) in perDay(vehicles) where cal.component(.year, from: d) == year {
            km += v
            if first == nil || d < first! { first = d }
        }
        return (km, first)
    }
}
