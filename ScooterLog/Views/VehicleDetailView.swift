import SwiftUI
import SwiftData

struct MonthGroup: Identifiable {
    let id: Date
    let entries: [HistoryEntry]
    var total: Double { entries.reduce(0) { $0 + $1.amount } }
}

struct VehicleDetailView: View {
    let vehicle: Vehicle
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @Environment(\.appAccent) private var accent
    @AppStorage("tankMargin") private var margin = 0.5
    @State private var showEdit = false
    @State private var confirmDelete = false
    @State private var deadlineSheet: DeadlineRoute? = nil

    private var groups: [MonthGroup] {
        let all = HistoryEntry.all(vehicle)
        let dict = Dictionary(grouping: all) { $0.date.startOfMonth }
        return dict.keys.sorted(by: >).map { MonthGroup(id: $0, entries: dict[$0] ?? []) }
    }

    var body: some View {
        let stats = StatsEngine.summary(vehicles: [vehicle], range: .all, spread: false)
        let fuel = FuelStats.summary(vehicles: [vehicle], range: .all, marginLiters: margin)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                Text(verbatim: "“\(vehicle.displayName)”")
                    .font(AppFont.serif(32)).foregroundStyle(Theme.ink)
                    .padding(.top, Space.s3)
                HStack(spacing: Space.s2) {
                    Text(verbatim: String(vehicle.year)).font(AppFont.sans(17, .medium)).foregroundStyle(Theme.ink)
                    Rectangle().fill(Theme.line).frame(width: 1, height: Space.s2)
                    Text(LocalizedStringKey(FuelKind(rawValue: vehicle.fuelKey)?.title ?? "Benzina 95"))
                        .font(AppFont.sans(17, .medium)).foregroundStyle(Theme.ink)
                }
                .padding(.top, Space.s1)

                Hairline().padding(.top, Space.s3)
                Text("Contachilometri").eyebrow().padding(.top, Space.s2)
                HStack(alignment: .firstTextBaseline, spacing: Space.s1) {
                    Text(vehicle.currentOdometer.grouped(locale))
                        .font(AppFont.serif(40)).foregroundStyle(Theme.ink).monospacedDigit()
                    Text(verbatim: "km").font(AppFont.sans(15)).foregroundStyle(Theme.muted)
                }
                .padding(.top, Space.s1)

                Hairline().padding(.top, Space.s2)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Space.s1) {
                        Text("Costo / mese").eyebrow()
                        Text(stats.perMonth.money(locale)).font(AppFont.serif(28)).foregroundStyle(Theme.ink).monospacedDigit()
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: Space.s1) {
                        Text("Consumo medio").eyebrow()
                        if let k = fuel.kmPerL {
                            Text(verbatim: "\(k.decimal(1, locale)) km/L").font(AppFont.serif(28)).foregroundStyle(Theme.ink).monospacedDigit()
                            if let m = fuel.margin { Text(verbatim: "± \(Int((m * 100).rounded()))%").eyebrow() }
                        } else {
                            Text(verbatim: "—").font(AppFont.serif(28)).foregroundStyle(Theme.muted)
                        }
                    }
                    Spacer()
                }
                .padding(.top, Space.s2)

                Hairline().padding(.top, Space.s2)
                Text("Scadenze").eyebrow().padding(.top, Space.s2)
                DeadlineCells(vehicle: vehicle) { kind in deadlineSheet = DeadlineRoute(vehicle: vehicle, kind: kind) }
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.base, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.base, style: .continuous).stroke(Theme.line, lineWidth: 1))
                    .cardShadow()
                    .padding(.top, Space.s1)

                HStack {
                    Text("Storico").eyebrow()
                    Text(verbatim: String(vehicle.entryCount)).eyebrow()
                }
                .padding(.top, Space.s4)
                if groups.isEmpty {
                    Text("Nessuna registrazione.").font(AppFont.sans(15)).foregroundStyle(Theme.muted).padding(.top, Space.s2)
                }
                ForEach(groups) { g in
                    HStack {
                        Text(verbatim: g.id.monthYear(locale)).font(AppFont.sans(15, .semibold)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text(g.total.money(locale)).font(AppFont.sans(13)).foregroundStyle(Theme.muted)
                    }
                    .padding(.top, Space.s3)
                    ForEach(g.entries) { e in HistoryRow(entry: e).rowTransition() }
                }
            }
            .animation(Motion.bounce, value: groups.flatMap { $0.entries.map { $0.id } })
            .padding(.horizontal, Space.s2)
            .padding(.top, Space.s2)
            .padding(.bottom, Space.s4)
        }
        .screenBackground(glow: true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showEdit) {
            VehicleFormView(vehicle: vehicle, onDeleted: { dismiss() })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(Radius.base)
                .presentationBackground(Theme.bg)
        }
        .sheet(item: $deadlineSheet) { r in
            DeadlineSheet(vehicle: r.vehicle, kind: r.kind)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(Radius.base)
                .presentationBackground(Theme.bg)
        }
    }

    private var header: some View {
        HStack(spacing: Space.s2) {
            Button { dismiss() } label: { IconSquare(systemName: "chevron.left") }
                .buttonStyle(PressStyle())
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: vehicle.make).eyebrow()
                Text(verbatim: vehicle.model).font(AppFont.serif(22)).foregroundStyle(Theme.ink)
            }
            Spacer()
            Button { showEdit = true } label: { IconSquare(systemName: "slider.horizontal.3") }
                .buttonStyle(PressStyle())
        }
    }
}
