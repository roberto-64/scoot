import SwiftUI
import SwiftData

/// What the summary says about one calendar year, for the vehicles in scope.
struct YearSummary {
    var year: Int
    var km: Double = 0
    var spent: Double = 0
    var liters: Double = 0
    var fills: Int = 0
    var kmPerL: Double? = nil
    var best: Double? = nil
    var months: [MonthBucket] = []
    /// First day logged in this year, only when logging started this year (so the year is partial).
    var startedOn: Date? = nil

    var perKm: Double? { km > 0 && spent > 0 ? spent / km : nil }

    /// Month with the highest everyday spending. Insurance, road tax and inspection do not count:
    /// they are paid in the same month every year and would always win.
    var priciestIndex: Int? {
        guard let top = months.map({ $0.variable }).max(), top > 0 else { return nil }
        return months.firstIndex(where: { $0.variable == top })
    }

    static func make(vehicles: [Vehicle], year: Int, margin: Double, now: Date = Date()) -> YearSummary {
        let cal = Calendar.current
        var y = YearSummary(year: year)
        let range = StatRange.year(year)
        let s = StatsEngine.summary(vehicles: vehicles, range: range, spread: false, now: now)
        y.spent = s.total
        y.months = s.months
        y.km = KmStats.year(vehicles: vehicles, year: year).km
        let f = FuelStats.summary(vehicles: vehicles, range: range, marginLiters: margin, now: now)
        y.kmPerL = f.kmPerL
        y.best = f.best
        for v in vehicles {
            for e in v.fuelEntries where cal.component(.year, from: e.date) == year {
                y.liters += e.liters
                y.fills += 1
            }
        }
        var dates: [Date] = []
        for v in vehicles {
            dates += v.fuelEntries.map { $0.date }
            dates += v.maintenance.map { $0.date }
            dates += v.expenses.map { $0.date }
            dates += v.readings.map { $0.date }
        }
        if let first = dates.min(),
           let jan1 = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
           first >= jan1, cal.component(.year, from: first) == year {
            y.startedOn = first
        }
        return y
    }
}

/// "2026 · dal 2 novembre" (the second part only when logging started that year).
struct YearSubtitle: View {
    @Environment(\.locale) private var locale
    let summary: YearSummary

    var body: some View {
        let year = String(summary.year)
        if let d = summary.startedOn {
            Text("\(year) · dal \(d.formatted(.dateTime.day().month(.wide).locale(locale)))")
        } else {
            Text(verbatim: year)
        }
    }
}

/// Card at the bottom of the stats screen that opens the yearly summary.
struct YearCard: View {
    @Environment(\.appAccent) private var accent
    @AppStorage("tankMargin") private var margin = 0.5
    let vehicles: [Vehicle]

    var body: some View {
        let year = Calendar.current.component(.year, from: Date())
        let y = YearSummary.make(vehicles: vehicles, year: year, margin: margin)
        NavigationLink {
            YearView(vehicles: vehicles)
        } label: {
            HStack(spacing: Space.s2) {
                VStack(alignment: .leading, spacing: Space.s1) {
                    YearTitle(vehicles: vehicles, size: 22)
                    YearSubtitle(summary: y).eyebrow()
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accent)
            }
            .card()
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

/// "Il tuo anno con Filippo" (the vehicle's name when a single vehicle is in scope).
struct YearTitle: View {
    let vehicles: [Vehicle]
    let size: CGFloat

    var body: some View {
        Group {
            if vehicles.count == 1, let v = vehicles.first {
                Text("Il tuo anno con \(v.displayName)")
            } else {
                Text("Il tuo anno")
            }
        }
        .font(AppFont.serif(size)).foregroundStyle(Theme.ink)
        .multilineTextAlignment(.leading)
    }
}

struct YearView: View {
    @Environment(\.locale) private var locale
    @Environment(\.appAccent) private var accent
    @AppStorage("tankMargin") private var margin = 0.5
    let vehicles: [Vehicle]

    var body: some View {
        let year = Calendar.current.component(.year, from: Date())
        let y = YearSummary.make(vehicles: vehicles, year: year, margin: margin)
        let cap: CGFloat = 72
        let unit = SpendScale.unit(y.months, cap: cap)
        let top = y.priciestIndex

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BackHeader(title: "Il tuo anno")
                YearSubtitle(summary: y).eyebrow().padding(.top, Space.s3)

                HStack(alignment: .firstTextBaseline, spacing: Space.s1) {
                    Text(Int(y.km.rounded()).grouped(locale))
                        .font(AppFont.serif(56)).foregroundStyle(Theme.ink).monospacedDigit()
                    Text(verbatim: "km").font(AppFont.sans(17)).foregroundStyle(Theme.muted)
                }
                .padding(.top, Space.s1)
                Group {
                    if vehicles.count == 1, let v = vehicles.first {
                        Text("percorsi con \(v.displayName)")
                    } else {
                        Text("percorsi")
                    }
                }
                .eyebrow().padding(.top, Space.s1)

                StatGrid(cells: [
                    StatCellData(title: "Speso", value: y.spent.money(locale)),
                    StatCellData(title: "Al km", value: y.perKm.map { $0.money(locale) } ?? "—", available: y.perKm != nil),
                    StatCellData(title: "Litri", value: y.liters > 0 ? "\(y.liters.decimal(1, locale)) L" : "—", available: y.liters > 0),
                    StatCellData(title: "Rifornimenti", value: "\(y.fills)"),
                    StatCellData(title: "Consumo medio", value: y.kmPerL.map { "\($0.decimal(1, locale)) km/L" } ?? "—", available: y.kmPerL != nil),
                    StatCellData(title: "Miglior tratto", value: y.best.map { "\($0.decimal(1, locale)) km/L" } ?? "—", available: y.best != nil)
                ])
                .padding(.top, Space.s3)

                SectionTitle(title: "Mese per mese").padding(.top, Space.s4)
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(y.months.enumerated()), id: \.offset) { i, m in
                        let has = m.variable > 0 || m.annual > 0
                        SpendColumn(bucket: m, unit: unit, cap: cap,
                                    everyday: i == top ? Theme.ink : (has ? accent : Theme.line),
                                    yearly: accent.opacity(0.55))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: cap, alignment: .bottom)
                .padding(.top, Space.s2)
                HStack(spacing: 6) {
                    ForEach(Array(y.months.enumerated()), id: \.offset) { i, m in
                        Text(verbatim: m.id.formatted(.dateTime.month(.narrow).locale(locale)))
                            .font(AppFont.sans(11, .semibold))
                            .foregroundStyle(i == top ? Theme.ink : Theme.muted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, Space.s1)
                if let i = top, y.months.indices.contains(i) {
                    let m = y.months[i]
                    HStack(alignment: .firstTextBaseline) {
                        Text("Mese più caro").eyebrow()
                        Spacer()
                        Text(verbatim: "\(m.id.formatted(.dateTime.month(.wide).locale(locale))) · \(m.variable.money(locale))")
                            .font(AppFont.serif(17)).foregroundStyle(Theme.ink).monospacedDigit()
                    }
                    .padding(.top, Space.s2)
                    Text("Senza assicurazione, bollo e revisione").eyebrow().padding(.top, Space.s1)
                }
            }
            .padding(.horizontal, Space.s2)
            .padding(.top, Space.s2)
            .padding(.bottom, Space.s4)
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: Space.s8 + Space.s2) }
        .screenBackground(glow: true)
        .toolbar(.hidden, for: .navigationBar)
    }
}
