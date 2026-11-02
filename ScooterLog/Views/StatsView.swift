import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.locale) private var locale
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @AppStorage("statRange") private var rangeRaw = "m6"
    @AppStorage("statVehicle") private var scope = "all"
    @AppStorage("tankMargin") private var margin = 0.5
    @AppStorage("spreadAnnual") private var spread = false

    var body: some View {
        let vs = scopedVehicles(vehicles, selection: scope)
        let range = StatRange.from(rangeRaw)
        let s = StatsEngine.summary(vehicles: vs, range: range, spread: spread)
        let f = FuelStats.summary(vehicles: vs, range: range, marginLiters: margin)
        let estimate = StatsEngine.annualEstimate(vehicles: vs)

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Space.s2) {
                    BackHeader(title: "Riepilogo")
                    VehiclePill(vehicles: vehicles, selection: $scope)
                }
                RangeChips(raw: $rangeRaw).padding(.top, Space.s3)

                if !s.hasData {
                    ChartPlaceholder(title: "Nessun dato in questo periodo",
                                     hint: "Aggiungi una registrazione con il tasto + oppure scegli un periodo più ampio.")
                        .padding(.top, Space.s3)
                } else {
                    Text("Spesa totale").eyebrow().padding(.top, Space.s3)
                    HStack(alignment: .firstTextBaseline, spacing: Space.s1) {
                        Text(s.total.decimal(2, locale)).font(AppFont.serif(56)).foregroundStyle(Theme.ink).monospacedDigit()
                            .contentTransition(.numericText())
                        Text(verbatim: "€").font(AppFont.serif(32)).foregroundStyle(Theme.muted)
                    }
                    .padding(.top, Space.s1)
                    .animation(Motion.spring, value: s.total)

                    StatGrid(cells: [
                        StatCellData(title: "Al mese", value: s.perMonth.money(locale)),
                        StatCellData(title: "Al km", value: s.perKm.map { $0.money(locale) } ?? "—", available: s.perKm != nil),
                        StatCellData(title: "Distanza", value: s.distance.map { "\($0.grouped(locale)) km" } ?? "—", available: s.distance != nil),
                        StatCellData(title: "Consumo medio",
                                     value: f.kmPerL.map { "\($0.decimal(1, locale)) km/L" } ?? "—", available: f.kmPerL != nil)
                    ])
                    .padding(.top, Space.s3)
                    if let m = f.margin, f.kmPerL != nil {
                        (Text(verbatim: "± \(Int((m * 100).rounded()))%, ") + Text("stima")).eyebrow().padding(.top, Space.s1)
                    }

                    SectionTitle(title: "Spesa mensile").padding(.top, Space.s4)
                    MonthlyBars(months: s.months).padding(.top, Space.s2)
                    Toggle(isOn: $spread) {
                        Text("Ripartisci assicurazione e bollo sui mesi coperti")
                            .font(AppFont.sans(15)).foregroundStyle(Theme.ink)
                    }
                    .toggleStyle(AccentToggleStyle())
                    .padding(.top, Space.s2)

                    if !s.split.isEmpty {
                        SectionTitle(title: "Dove vanno i soldi").padding(.top, Space.s4)
                        SplitBar(slices: s.split).padding(.top, Space.s2)
                    }

                    SectionTitle(title: "Consumo, km/L").padding(.top, Space.s4)
                    if f.points.count >= 2 {
                        ConsumptionChart(points: f.points, average: f.kmPerL).padding(.top, Space.s2)
                        Text("Media mobile su almeno 400 km. Trascina il dito per leggere. Linea tratteggiata: media.")
                            .eyebrow().padding(.top, Space.s1)
                        StatGrid(cells: [
                            StatCellData(title: "Miglior tratto", value: f.best.map { "\($0.decimal(1, locale)) km/L" } ?? "—", available: f.best != nil),
                            StatCellData(title: "Peggior tratto", value: f.worst.map { "\($0.decimal(1, locale)) km/L" } ?? "—", available: f.worst != nil)
                        ])
                        .padding(.top, Space.s2)
                    } else {
                        ChartPlaceholder(title: "Il grafico arriva con più rifornimenti",
                                         hint: "Servono almeno 400 km tra due rifornimenti.")
                            .padding(.top, Space.s2)
                    }

                    if let e = estimate {
                        VStack(alignment: .leading, spacing: Space.s1) {
                            Text("Stima annua").eyebrow()
                            Text("≈ \((e.recurring + e.variable).money(locale))")
                                .font(AppFont.serif(32)).foregroundStyle(Theme.ink).monospacedDigit()
                            Text("\(e.recurring.money(locale)) di costi annuali + \(e.variable.money(locale)) di spese variabili (media mensile × 12)")
                                .eyebrow()
                        }
                        .card()
                        .padding(.top, Space.s4)
                    }
                }
            }
            .padding(.horizontal, Space.s2)
            .padding(.top, Space.s2)
            .padding(.bottom, Space.s4)
        }
        .screenBackground(glow: true)
        .toolbar(.hidden, for: .navigationBar)
    }
}
