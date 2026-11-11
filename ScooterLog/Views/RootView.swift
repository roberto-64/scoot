import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum AppTab: Int, Hashable {
    case home, garage, fuel, profile
}

enum NewRoute: Hashable {
    case fuel, maintenance, expense, odometer
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appLocked) private var locked
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @AppStorage("language") private var language = "it"
    @AppStorage("alerts") private var alerts = true
    @AppStorage("lastBackup") private var lastBackup: Double = 0
    /// Month ("2026-10") whose recap pop-up has already been shown.
    @AppStorage("recapSeen") private var recapSeen = ""
    @State private var recapRef: RecapRef? = nil
    /// Fill-up whose "last two tanks" pop-up has already been shown, and the one that was in the app when it
    /// last went to the background (the pop-up waits for the next open, not the moment of saving).
    @AppStorage("tankSeen") private var tankSeen = ""
    @AppStorage("tankArmed") private var tankArmed = ""
    @AppStorage("tankMargin") private var tankMargin = 0.5
    @State private var tankRecap: TankRecap? = nil
    /// Missing-data alarm: how many entries the app had when it last left the screen.
    @Environment(\.modelContext) private var context
    @AppStorage("knownEntryCount") private var knownCount = 0
    @State private var wipeAlarm: WipeAlarm? = nil
    @State private var showAlarmPicker = false
    @State private var alarmRestoreFailed = false
    @State private var tab: AppTab = .home
    @State private var showNew = false
    /// Form to open straight away when the sheet comes from Shortcuts or the icon menu.
    @State private var openRoute: NewRoute? = nil
    @ObservedObject private var quick = QuickRoute.shared
    /// Bumped for the tab that is coming in, so its blocks replay the bounce-in (see Cascade.swift).
    @State private var cascadeTokens = [0, 0, 0, 0]

    var body: some View {
        ZStack(alignment: .bottom) {
            // All four screens stay alive, so switching never has to build anything (no hiccup) and each
            // tab remembers where you were. The chosen one sits on top and fades in over the others.
            tabScreen(.home) { HomeView(onAdd: { showNew = true }) }
            tabScreen(.garage) { GarageView() }
            tabScreen(.fuel) { FuelView() }
            tabScreen(.profile) { ProfileView() }
            FloatingBar(tab: $tab, onNew: { showNew = true })
                .zIndex(10)
        }
        .sheet(isPresented: $showNew, onDismiss: { openRoute = nil }) {
            NewEntrySheet(initialRoute: openRoute)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(Radius.base)
                .presentationBackground(Theme.bg)
        }
        .background(
            // Own host view, so it never competes with the new-entry sheet above.
            Color.clear.sheet(item: $recapRef) { ref in
                RecapSheet(vehicles: vehicles, month: ref.month)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(Radius.base)
                    .presentationBackground(Theme.bg)
            }
        )
        .background(
            Color.clear.sheet(isPresented: $showAlarmPicker) {
                DocumentPicker(types: [.json, .data]) { url in restoreFromFile(url) }
                    .ignoresSafeArea()
            }
        )
        .alert("File non valido", isPresented: $alarmRestoreFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Questo file non è un backup di Scoot.")
        }
        .overlay {
            if let a = wipeAlarm {
                WipeAlarmCard(alarm: a,
                              onRestore: { f in restore(f.data, count: f.count) },
                              onPickFile: {
                                  withAnimation(Motion.spring) { wipeAlarm = nil }
                                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showAlarmPicker = true }
                              },
                              onLater: { withAnimation(Motion.spring) { wipeAlarm = nil } })
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    .zIndex(30)
            }
        }
        .overlay {
            if let t = tankRecap {
                TankRecapCard(recap: t) { withAnimation(Motion.spring) { tankRecap = nil } }
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    .zIndex(20)
            }
        }
        .onChange(of: tab) { _, new in cascadeTokens[new.rawValue] += 1 }
        .onAppear { reschedule(); takeQuickRoute(); checkWipe(); AutoBackup.runIfDue(vehicles: vehicles); checkRecap(); checkTank() }
        .onChange(of: quick.pending) { _, _ in takeQuickRoute() }
        .onChange(of: scenePhase) { _, p in
            if p == .active {
                reschedule(); checkWipe(); AutoBackup.runIfDue(vehicles: vehicles); checkRecap(); checkTank()
            } else if p == .background {
                armTank()
                // While the alarm is up the app is empty on purpose: keep the old count so it can come back.
                if wipeAlarm == nil { knownCount = AutoBackup.entryCount(vehicles) }
            }
        }
        .onChange(of: locked) { _, nowLocked in
            if nowLocked {
                recapRef = nil
                // Closed by the lock before it was read: let it come back after unlocking.
                if tankRecap != nil { tankRecap = nil; tankSeen = "" }
            } else {
                checkWipe(); checkRecap(); checkTank()
            }
        }
        .onChange(of: language) { _, _ in reschedule() }
        .onChange(of: alerts) { _, on in
            if on { Notifier.requestAuthorization() }
            reschedule()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataChanged)) { _ in reschedule() }
    }

    private func tabScreen<Content: View>(_ t: AppTab, @ViewBuilder content: () -> Content) -> some View {
        let on = tab == t
        return content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(on ? 1 : 0)
            .animation(on ? Motion.tabIn : Motion.tabOut, value: on)
            .zIndex(on ? 1 : 0)
            .allowsHitTesting(on)
            .accessibilityHidden(!on)
            .environment(\.cascadeToken, cascadeTokens[t.rawValue])
    }

    private func takeQuickRoute() {
        guard let r = quick.pending else { return }
        quick.pending = nil
        openRoute = r
        showNew = true
    }

    /// On the first open of a new month, shows the recap of the month that just ended (once).
    /// Nothing opens while the Face ID lock is up, over another sheet, or when the month has no data.
    /// If Scoot had entries when it last left the screen and now opens empty, something wiped it:
    /// show the alarm with the newest automatic backup (looked up off the main thread, it may download).
    private func checkWipe() {
        guard !locked, wipeAlarm == nil, knownCount > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard !locked, wipeAlarm == nil, knownCount > 0, AutoBackup.entryCount(vehicles) == 0 else { return }
            let known = knownCount
            DispatchQueue.global(qos: .userInitiated).async {
                let found = AutoBackup.latest()
                DispatchQueue.main.async {
                    guard wipeAlarm == nil, AutoBackup.entryCount(vehicles) == 0 else { return }
                    recapRef = nil
                    tankRecap = nil
                    Haptics.warning()
                    withAnimation(Motion.spring) { wipeAlarm = WipeAlarm(knownCount: known, found: found) }
                }
            }
        }
    }

    private func restore(_ data: Data, count: Int) {
        if BackupService.restore(data, into: context) {
            Haptics.success()
            DataSignal.fire()
            knownCount = count
            withAnimation(Motion.spring) { wipeAlarm = nil }
        } else {
            alarmRestoreFailed = true
        }
    }

    private func restoreFromFile(_ url: URL) {
        let opened = url.startAccessingSecurityScopedResource()
        defer { if opened { url.stopAccessingSecurityScopedResource() } }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: url),
              let file = try? decoder.decode(BackupFile.self, from: data) else {
            alarmRestoreFailed = true
            return
        }
        restore(data, count: AutoBackup.entryCount(file))
    }

    private func checkRecap() {
        guard !locked, !showNew, recapRef == nil, wipeAlarm == nil, scenePhase != .background else { return }
        let previous = Date().startOfMonth.addingMonths(-1)
        let key = RecapKey.string(previous)
        guard previous >= RecapStart.date, recapSeen != key else { return }
        let days = KmStats.perDay(vehicles, since: RecapStart.date)
        guard MonthRecap.hasData(vehicles: vehicles, month: previous, perDay: days) else { return }
        recapSeen = key
        // A short wait so the app has finished appearing (or unlocking) before the sheet slides up.
        let ref = RecapRef(month: previous)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            if !locked { recapRef = ref }
        }
    }

    /// When the app leaves the screen, remembers the latest fill-up. The next time the app opens, the
    /// pop-up for that fill-up shows once (so it does not appear right after saving).
    private func armTank() {
        if let r = TankRecap.make(vehicles: vehicles, marginLiters: tankMargin) { tankArmed = r.key }
    }

    /// On the first open after a fill-up, shows the last two tanks (once per fill-up).
    private func checkTank() {
        guard !locked, !showNew, recapRef == nil, tankRecap == nil, wipeAlarm == nil, scenePhase != .background else { return }
        guard let r = TankRecap.make(vehicles: vehicles, marginLiters: tankMargin),
              r.key == tankArmed, r.key != tankSeen else { return }
        // A short wait so the app has finished appearing, and the monthly recap (if any) goes first.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            guard !locked, !showNew, recapRef == nil, tankRecap == nil, tankSeen != r.key else { return }
            tankSeen = r.key
            withAnimation(Motion.spring) { tankRecap = r }
        }
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
            if tab == t { TabTap.send(t) } else { withAnimation(Motion.spring) { tab = t } }
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
    var initialRoute: NewRoute? = nil
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
        .onAppear {
            if let r = initialRoute, route == nil {
                DispatchQueue.main.async { route = r }
            }
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
