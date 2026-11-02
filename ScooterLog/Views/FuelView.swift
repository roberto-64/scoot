import SwiftUI
import SwiftData

struct FuelView: View {
    @Environment(\.locale) private var locale
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @AppStorage("statRange") private var rangeRaw = "m6"
    @AppStorage("statVehicle") private var scope = "all"
    @AppStorage("tankMargin") private var margin = 0.5
    @State private var mode = 0

    var body: some View {
        let vs = scopedVehicles(vehicles, selection: scope)
        let range = StatRange.from(rangeRaw)
        let f = FuelStats.summary(vehicles: vs, range: range, marginLiters: margin)
        let fills = HistoryEntry.recentFuel(vs, range: range)

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Carburante").font(AppFont.serif(32)).foregroundStyle(Theme.ink)
                    Spacer()
                    VehiclePill(vehicles: vehicles, selection: $scope)
                }
                if vehicles.isEmpty {
                    Text("Aggiungi un veicolo dal garage per iniziare.")
                        .font(AppFont.sans(15)).foregroundStyle(Theme.muted).padding(.top, Space.s3)
                } else {
                    RangeChips(raw: $rangeRaw).padding(.top, Space.s3)
                    hero(f).padding(.top, Space.s3)
                    StatGrid(cells: [
                        StatCellData(title: "Prezzo medio", value: f.avgPrice.map { "\($0.decimal(2, locale)) €/L" } ?? "—", available: f.avgPrice != nil),
                        StatCellData(title: "Carburante al km", value: f.fuelCostPerKm.map { $0.money(locale) } ?? "—", available: f.fuelCostPerKm != nil),
                        StatCellData(title: "Litri per sosta", value: f.litersPerStop.map { "\($0.decimal(1, locale)) L" } ?? "—", available: f.litersPerStop != nil),
                        StatCellData(title: "Km tra le soste", value: f.kmBetweenStops.map { "\(Int($0.rounded()).grouped(locale)) km" } ?? "—", available: f.kmBetweenStops != nil)
                    ])
                    .padding(.top, Space.s3)

                    Segmented(options: [SegmentOption(value: 0, label: "Consumo"), SegmentOption(value: 1, label: "Prezzo al litro")], selection: $mode)
                        .padding(.top, Space.s4)
                    chart(f).padding(.top, Space.s3)

                    if !fills.isEmpty {
                        HStack {
                            Text("Rifornimenti").eyebrow()
                            Text(verbatim: String(fills.count)).eyebrow()
                        }
                        .padding(.top, Space.s4)
                        ForEach(fills) { e in HistoryRow(entry: e, showVehicle: vehicles.count > 1).rowTransition() }
                    }
                }
            }
            .animation(Motion.bounce, value: fills.map { $0.id })
            .padding(.horizontal, Space.s2)
            .padding(.top, Space.s2)
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: Space.s8 + Space.s2) }
        .screenBackground(glow: true)
    }

    @ViewBuilder
    private func hero(_ f: FuelSummary) -> some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Text("Consumo medio").eyebrow()
            if let k = f.kmPerL {
                HStack(alignment: .firstTextBaseline, spacing: Space.s1) {
                    Text(k.decimal(1, locale)).font(AppFont.serif(56)).foregroundStyle(Theme.ink).monospacedDigit()
                        .contentTransition(.numericText())
                    Text(verbatim: "km/L").font(AppFont.sans(17)).foregroundStyle(Theme.muted)
                }
                .animation(Motion.spring, value: k)
                if let m = f.margin { (Text(verbatim: "± \(Int((m * 100).rounded()))%, ") + Text("stima")).eyebrow() }
            } else {
                Text(verbatim: "—").font(AppFont.serif(56)).foregroundStyle(Theme.muted)
                Text("Servono almeno due rifornimenti.").eyebrow()
            }
        }
    }

    @ViewBuilder
    private func chart(_ f: FuelSummary) -> some View {
        if mode == 0 {
            if f.points.count >= 2 {
                ConsumptionChart(points: f.points, average: f.kmPerL)
                Text("Media mobile su almeno 400 km. Trascina il dito per leggere. Linea tratteggiata: media.")
                    .eyebrow().padding(.top, Space.s1)
            } else {
                ChartPlaceholder(title: "Il grafico arriva con più rifornimenti",
                                 hint: "Servono almeno 400 km tra due rifornimenti. Aggiungili con il tasto +.")
            }
        } else {
            if f.pricePoints.count >= 2 {
                PriceChart(points: f.pricePoints)
                Text("Prezzo pagato a ogni rifornimento. Trascina il dito per leggere.").eyebrow().padding(.top, Space.s1)
            } else {
                ChartPlaceholder(title: "Il grafico arriva col secondo rifornimento",
                                 hint: "Ne manca almeno 1. Aggiungilo con il tasto +.")
            }
        }
    }
}

extension HistoryEntry {
    static func recentFuel(_ vs: [Vehicle], range: StatRange) -> [HistoryEntry] {
        var out: [HistoryEntry] = []
        for v in vs {
            for f in v.fuelEntries where range.contains(f.date) { out.append(.fuel(f)) }
        }
        return out.sorted { $0.date > $1.date }
    }
}
