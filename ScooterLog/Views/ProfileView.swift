import SwiftUI
import SwiftData

/// Profile tab: name card, yearly activity, vehicles list and backup card.
/// The gear at the top right opens Settings.
struct ProfileView: View {
    @Environment(\.appAccent) private var accent
    @Environment(\.locale) private var locale
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]

    @AppStorage("userName") private var userName = ""
    @AppStorage("lastBackup") private var lastBackup: Double = 0

    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var showNewVehicle = false
    @State private var editName = false
    @State private var draftName = ""
    @State private var shareURL: ShareItem?
    @State private var exportFailed = false

    private struct ShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s3) {
                    header
                    nameCard
                    activitySection
                    vehiclesSection
                    backupCard
                }
                .padding(.horizontal, Space.s2)
                .padding(.top, Space.s2)
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: Space.s8 + Space.s2) }
            .screenBackground(glow: true)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showNewVehicle) {
                VehicleFormView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(Radius.base)
                    .presentationBackground(Theme.bg)
            }
            .sheet(item: $shareURL) { item in
                ShareSheet(url: item.url) { completed in
                    if completed { lastBackup = Date().timeIntervalSince1970 }
                }
                .presentationDetents([.medium, .large])
            }
            .alert("Il tuo nome", isPresented: $editName) {
                TextField("Nome", text: $draftName)
                Button("Salva") {
                    userName = draftName.trimmingCharacters(in: .whitespaces)
                }
                Button("Annulla", role: .cancel) {}
            }
            .alert("Esportazione non riuscita", isPresented: $exportFailed) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    // MARK: Header and name card

    private var header: some View {
        HStack {
            Text("Profilo").font(AppFont.serif(32)).foregroundStyle(Theme.ink)
            Spacer()
            NavigationLink { SettingsView() } label: { IconSquare(systemName: "gearshape") }
                .buttonStyle(PressStyle())
        }
    }

    private var nameCard: some View {
        let all = StatsEngine.summary(vehicles: vehicles, range: .all, spread: false)
        let shape = RoundedRectangle(cornerRadius: Radius.base, style: .continuous)
        return Button {
            draftName = userName
            editName = true
        } label: {
            HStack(spacing: Space.s2) {
                ZStack {
                    shape.fill(accent)
                    if let first = userName.trimmingCharacters(in: .whitespaces).first {
                        Text(verbatim: String(first).uppercased())
                            .font(AppFont.serif(28))
                            .foregroundStyle(Theme.surface)
                    } else {
                        Image(systemName: "person")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.surface)
                    }
                }
                .frame(width: Space.s7, height: Space.s7)

                VStack(alignment: .leading, spacing: 2) {
                    if userName.isEmpty {
                        Text("Il tuo nome").font(AppFont.serif(22)).foregroundStyle(Theme.muted)
                    } else {
                        Text(verbatim: userName).font(AppFont.serif(22)).foregroundStyle(Theme.ink)
                    }
                    subtitle(count: all.entryCount)
                        .font(AppFont.sans(13)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .card()
            .cardShadow()
        }
        .buttonStyle(PressStyle())
    }

    private func subtitle(count: Int) -> Text {
        if count == 0 { return Text("Nessuna registrazione") }
        let countText = count == 1 ? Text("1 registrazione") : Text("\(count) registrazioni")
        guard let since = vehicles.map({ $0.createdAt }).min() else { return countText }
        return countText + Text(verbatim: " · ") + Text("dal") + Text(verbatim: " " + since.short(locale))
    }

    // MARK: Activity

    private var years: [Int] {
        let cal = Calendar.current
        var set = Set(StatsEngine.items(vehicles).map { cal.component(.year, from: $0.date) })
        set.insert(cal.component(.year, from: Date()))
        return set.sorted(by: >)
    }

    private var activitySection: some View {
        let s = StatsEngine.summary(vehicles: vehicles, range: .year(year), spread: false)
        return VStack(alignment: .leading, spacing: Space.s2) {
            HStack {
                SectionTitle(title: "La tua attività")
                Spacer()
                yearChip
            }
            StatGrid(cells: [
                StatCellData(title: "Registrazioni", value: String(s.entryCount)),
                StatCellData(title: "Spesa", value: s.total.money(locale)),
                StatCellData(title: "Distanza",
                             value: s.distance.map { $0.grouped(locale) + " km" } ?? "–",
                             available: s.distance != nil),
                StatCellData(title: "Costo / mese", value: s.perMonth.money(locale))
            ])
            if !s.split.isEmpty {
                Text("Dove vanno i soldi").eyebrow().padding(.top, Space.s1)
                SplitBar(slices: s.split)
            }
            NavigationLink { StatsView() } label: {
                HStack {
                    Text("Vedi il riepilogo completo")
                        .font(AppFont.sans(15, .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(accent)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .padding(.top, Space.s1)
        }
    }

    private var yearChip: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.base, style: .continuous)
        return Menu {
            ForEach(years, id: \.self) { y in
                Button {
                    year = y
                    Haptics.tick()
                } label: {
                    Text(verbatim: String(y))
                }
            }
        } label: {
            HStack(spacing: Space.s1) {
                Text(verbatim: String(year)).font(AppFont.sans(13, .semibold)).monospacedDigit()
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, Space.s2)
            .frame(height: Space.s4)
            .background(Theme.surface, in: shape)
            .overlay(shape.stroke(Theme.line, lineWidth: 1))
            .cardShadow()
        }
    }

    // MARK: Vehicles

    private var vehiclesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionTitle(title: "I tuoi veicoli")
                Spacer()
                Text(verbatim: String(vehicles.count)).eyebrow()
            }
            .padding(.bottom, Space.s1)

            ForEach(vehicles) { v in
                NavigationLink { VehicleDetailView(vehicle: v) } label: {
                    HStack(alignment: .center, spacing: Space.s2) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: v.displayName).font(AppFont.sans(17, .semibold)).foregroundStyle(Theme.ink)
                            Text(verbatim: "\(v.make) \(v.model)").font(AppFont.sans(13)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Text(verbatim: v.currentOdometer.grouped(locale) + " km")
                            .font(AppFont.sans(17)).foregroundStyle(Theme.ink).monospacedDigit()
                    }
                    .padding(.vertical, Space.s2)
                    .overlay(alignment: .top) { Hairline() }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
            }

            Button { showNewVehicle = true } label: {
                HStack(spacing: Space.s1) {
                    Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                    Text("Aggiungi veicolo").font(AppFont.sans(15, .semibold))
                    Spacer()
                }
                .foregroundStyle(accent)
                .padding(.vertical, Space.s2)
                .overlay(alignment: .top) { Hairline() }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
        }
    }

    // MARK: Backup

    private var backupCard: some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Text("Backup dei dati").font(AppFont.serif(17)).foregroundStyle(Theme.ink)
            if lastBackup > 0 {
                (Text("Ultimo backup:") + Text(verbatim: " " + Date(timeIntervalSince1970: lastBackup).short(locale)))
                    .eyebrow()
            } else {
                Text("Ultimo backup: mai").eyebrow()
            }
            Text("I dati restano solo su questo telefono. Se l’app va reinstallata, senza un backup li perdi.")
                .eyebrow()
            PrimaryButton(title: "Esporta ora") { exportNow() }
                .padding(.top, Space.s1)
        }
        .card()
    }

    private func exportNow() {
        let day = Date().formatted(.iso8601.year().month().day())
        if let data = BackupService.makeJSON(vehicles),
           let url = BackupService.tempFile(named: "scoot-\(day).json", data: data) {
            Haptics.tick()
            shareURL = ShareItem(url: url)
        } else {
            exportFailed = true
        }
    }
}
