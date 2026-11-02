import SwiftUI
import SwiftData

struct GarageView: View {
    @Environment(\.locale) private var locale
    @AppStorage("language") private var language = "it"
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @State private var showNew = false
    @State private var deadlineSheet: DeadlineRoute? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s3) {
                    HStack {
                        Text("Il mio garage").font(AppFont.serif(32)).foregroundStyle(Theme.ink)
                        Spacer()
                        Button { showNew = true } label: { IconSquare(systemName: "plus", filled: true) }
                            .buttonStyle(PressStyle())
                    }
                    if vehicles.isEmpty {
                        Text("Nessun veicolo. Tocca + per aggiungerne uno.")
                            .font(AppFont.sans(15)).foregroundStyle(Theme.muted)
                    }
                    ForEach(vehicles) { v in garageCard(v) }
                    upcomingSection
                }
                .padding(.horizontal, Space.s2)
                .padding(.top, Space.s2)
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: Space.s8 + Space.s2) }
            .screenBackground(glow: true)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showNew) {
                VehicleFormView()
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
    }

    private func garageCard(_ v: Vehicle) -> some View {
        VStack(spacing: 0) {
            NavigationLink {
                VehicleDetailView(vehicle: v)
            } label: {
                VStack(alignment: .leading, spacing: Space.s3) {
                    HStack(spacing: Space.s2) {
                        VehicleBadge()
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: "\(v.make) \(v.model)").font(AppFont.sans(13)).foregroundStyle(Theme.muted)
                            Text(verbatim: v.displayName).font(AppFont.serif(22)).foregroundStyle(Theme.ink)
                        }
                        Spacer()
                    }
                    HStack(alignment: .firstTextBaseline, spacing: Space.s1) {
                        Text(v.currentOdometer.grouped(locale)).font(AppFont.serif(40)).foregroundStyle(Theme.ink).monospacedDigit()
                        Text(verbatim: "km").font(AppFont.sans(15)).foregroundStyle(Theme.muted)
                        Spacer()
                        Text(verbatim: String(v.year)).font(AppFont.sans(15)).foregroundStyle(Theme.muted)
                    }
                }
                .padding(Space.s2)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PressStyle())
            Hairline()
            DeadlineCells(vehicle: v) { kind in deadlineSheet = DeadlineRoute(vehicle: v, kind: kind) }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.base, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.base, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .cardShadow()
    }

    @ViewBuilder
    private var upcomingSection: some View {
        let items = Upcoming.items(for: vehicles, lang: language)
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("In arrivo").eyebrow().padding(.bottom, Space.s1)
                ForEach(items) { it in
                    HStack(alignment: .top, spacing: Space.s2) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: it.title).font(AppFont.serif(17)).foregroundStyle(Theme.ink)
                            if vehicles.count > 1 {
                                Text(verbatim: it.vehicleName).font(AppFont.sans(13)).foregroundStyle(Theme.muted)
                            }
                            Text(verbatim: it.subtitle).font(AppFont.sans(13)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        countdown(it)
                    }
                    .padding(.vertical, Space.s2)
                    .overlay(alignment: .top) { Hairline() }
                }
            }
        }
    }

    @ViewBuilder
    private func countdown(_ it: UpcomingItem) -> some View {
        if let d = it.days {
            Text(verbatim: d < 0 ? Loc.tr("Scaduta", language) : "\(d) \(Loc.tr("gg", language))")
                .font(AppFont.serif(17)).foregroundStyle(d < 0 ? Theme.ink : Theme.ink).monospacedDigit()
        } else if let k = it.kmLeft {
            Text(verbatim: "\(max(k, 0).grouped(locale)) km").font(AppFont.serif(17)).foregroundStyle(Theme.ink).monospacedDigit()
        }
    }
}
