import SwiftUI
import SwiftData

enum AppTab: Int, Hashable {
    case home, garage, fuel, profile
}

enum NewRoute: Hashable {
    case fuel, maintenance, expense, odometer
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @AppStorage("language") private var language = "it"
    @AppStorage("alerts") private var alerts = true
    @AppStorage("lastBackup") private var lastBackup: Double = 0
    @State private var tab: AppTab = .home
    @State private var showNew = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .home: HomeView(onAdd: { showNew = true })
                case .garage: GarageView()
                case .fuel: FuelView()
                case .profile: ProfileView()
                }
            }
            .animation(Motion.fade, value: tab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            FloatingBar(tab: $tab, onNew: { showNew = true })
        }
        .sheet(isPresented: $showNew) {
            NewEntrySheet()
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(Radius.base)
                .presentationBackground(Theme.bg)
        }
        .onAppear { reschedule() }
        .onChange(of: scenePhase) { _, p in if p == .active { reschedule() } }
        .onChange(of: language) { _, _ in reschedule() }
        .onChange(of: alerts) { _, on in
            if on { Notifier.requestAuthorization() }
            reschedule()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataChanged)) { _ in reschedule() }
    }

    private func reschedule() {
        var reminder: Date? = nil
        if let first = vehicles.first {
            let base = lastBackup > 0 ? Date(timeIntervalSince1970: lastBackup) : first.createdAt
            reminder = base.addingDays(30)
        }
        Notifier.reschedule(vehicles: vehicles, lang: language, enabled: alerts, backupReminder: reminder)
    }
}

struct FloatingBar: View {
    @Environment(\.appAccent) private var accent
    @Binding var tab: AppTab
    var onNew: () -> Void
    @Namespace private var ns

    var body: some View {
        HStack(spacing: Space.s1) {
            HStack(spacing: 0) {
                tabButton(.home) { Image(systemName: "house").font(.system(size: 20, weight: .medium)) }
                tabButton(.garage) {
                    Image("CarFront").renderingMode(.template).resizable().scaledToFit()
                        .frame(width: Space.s3, height: Space.s3)
                }
                tabButton(.fuel) { Image(systemName: "fuelpump").font(.system(size: 20, weight: .medium)) }
                tabButton(.profile) { Image(systemName: "person").font(.system(size: 20, weight: .medium)) }
            }
            .padding(.horizontal, Space.s1)
            .frosted()

            Button(action: onNew) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Theme.surface)
                    .frame(width: Space.s7, height: Space.s7)
                    .background(accent, in: RoundedRectangle(cornerRadius: Radius.base, style: .continuous))
                    .barShadow()
            }
            .buttonStyle(PressStyle())
        }
        .padding(.horizontal, Space.s2)
        .padding(.bottom, Space.s1)
        .sensoryFeedback(.selection, trigger: tab)
    }

    private func tabButton<Icon: View>(_ t: AppTab, @ViewBuilder icon: () -> Icon) -> some View {
        let on = tab == t
        return Button {
            withAnimation(Motion.spring) { tab = t }
        } label: {
            icon()
                .foregroundStyle(on ? Theme.surface : Theme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: Space.s5)
                .background {
                    if on {
                        RoundedRectangle(cornerRadius: Radius.base, style: .continuous)
                            .fill(accent)
                            .matchedGeometryEffect(id: "pill", in: ns)
                    }
                }
                // The tap area is the whole quarter of the bar, top to bottom (56 pt), not just the icon.
                .padding(.vertical, Space.s1)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

private struct SheetHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct NewEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @AppStorage("selectedVehicle") private var selectedID = ""
    @State private var route: NewRoute? = nil
    /// Height of the title and cards (measured), so the sheet is only as tall as it needs to be.
    @State private var contentHeight: CGFloat = 440

    private var vehicle: Vehicle? { selectedVehicle(vehicles, id: selectedID) }

    /// Room under the cards: breathing space plus the home indicator strip at the bottom of the sheet.
    private var bottomAllowance: CGFloat { Space.s4 + 34 }

    /// Only as tall as the cards need; a form opened inside the sheet needs the full height.
    private var detents: Set<PresentationDetent> {
        route == nil ? [.height(contentHeight + bottomAllowance)] : [.large]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s4) {
                    HStack {
                        Text("Nuova registrazione").font(AppFont.serif(28)).foregroundStyle(Theme.ink)
                        Spacer()
                        Button { dismiss() } label: { IconSquare(systemName: "xmark") }
                            .buttonStyle(PressStyle())
                    }
                    if let v = vehicle {
                        if vehicles.count > 1 {
                            Menu {
                                ForEach(vehicles) { x in
                                    Button(x.displayName) { selectedID = x.uid.uuidString }
                                }
                            } label: {
                                HStack(spacing: Space.s1) {
                                    Text(verbatim: v.displayName).font(AppFont.sans(15, .semibold))
                                    Image(systemName: "chevron.down").font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(Theme.ink)
                            }
                        }
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.s2), GridItem(.flexible())], spacing: Space.s2) {
                            tile(.fuel, "fuelpump", "Rifornimento", last: v.fuelEntries.map { $0.date }.max())
                            tile(.maintenance, "wrench.and.screwdriver", "Manutenzione", last: v.maintenance.map { $0.date }.max())
                            tile(.expense, "receipt", "Spesa", last: v.expenses.map { $0.date }.max())
                            tile(.odometer, "gauge", "Aggiorna contachilometri", last: v.readings.map { $0.date }.max())
                        }
                    } else {
                        Text("Aggiungi prima un veicolo dal garage.")
                            .font(AppFont.serif(22)).foregroundStyle(Theme.ink)
                            .padding(.top, Space.s3)
                    }
                }
                .padding(.horizontal, Space.s2)
                .padding(.top, Space.s4)
                .background(
                    GeometryReader { g in
                        Color.clear.preference(key: SheetHeightKey.self, value: g.size.height)
                    }
                )
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $route) { r in
                if let v = vehicle {
                    destination(r, v)
                }
            }
        }
        .onPreferenceChange(SheetHeightKey.self) { h in
            if h > 0 { contentHeight = h }
        }
        .presentationDetents(detents)
    }

    @ViewBuilder
    private func destination(_ r: NewRoute, _ v: Vehicle) -> some View {
        switch r {
        case .fuel: FuelFormView(vehicle: v, onSaved: { dismiss() })
        case .maintenance: MaintenanceEntryView(vehicle: v, onSaved: { dismiss() })
        case .expense: ExpenseFormView(vehicle: v, onSaved: { dismiss() })
        case .odometer: OdometerFormView(vehicle: v, onSaved: { dismiss() })
        }
    }

    private func tile(_ r: NewRoute, _ symbol: String, _ title: String, last: Date?) -> some View {
        Button { route = r } label: {
            VStack(alignment: .leading, spacing: Space.s2) {
                TileIcon(symbol: symbol)
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(title)).font(AppFont.serif(17)).foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                    if let d = last {
                        Text("Ultimo: \(d.dayMonth(locale))").eyebrow()
                    } else {
                        Text("Ancora niente").eyebrow()
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
            .card()
        }
        .buttonStyle(PressStyle())
    }
}

struct TileIcon: View {
    @Environment(\.appAccent) private var accent
    let symbol: String
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(accent)
            .frame(width: Space.s6, height: Space.s6)
            .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: Radius.base, style: .continuous))
    }
}
