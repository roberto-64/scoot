import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Settings: colour, language, alerts, Face ID, animations, haptics,
/// tank margin, backup (export / import) and version.
/// Opened from the gear at the top right of Profile.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccent) private var accent
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @Query private var vehicles: [Vehicle]

    @AppStorage("accent") private var accentId = "amber"
    @AppStorage("language") private var language = "it"
    @AppStorage("alerts") private var alerts = true
    @AppStorage("faceID") private var faceID = false
    @AppStorage("animations") private var animations = true
    @AppStorage("haptics") private var haptics = true
    @AppStorage("tankMargin") private var margin = 0.5
    @AppStorage("lastBackup") private var lastBackup: Double = 0
    @AppStorage(AutoBackup.enabledKey) private var autoBackup = false
    @State private var pickFolder = false
    @State private var folderName: String? = nil
    @State private var autoFailed = false

    @State private var shareItem: ShareItem?
    /// The raw database for diagnostics (kept apart so it does not count as a backup).
    @State private var dbShare: ShareItem?
    @State private var showImport = false
    @State private var exportFailed = false

    private struct ShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s3) {
                BackHeader(title: "Impostazioni")

                colourSection
                languageSection
                switchesSection
                marginSection
                recapSection
                backupSection
                salesSection
                versionRow
            }
            .padding(.horizontal, Space.s2)
            .padding(.top, Space.s2)
            .padding(.bottom, Space.s4)
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: Space.s8 + Space.s2) }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $shareItem) { item in
            ShareSheet(url: item.url) { completed in
                if completed { lastBackup = Date().timeIntervalSince1970 }
            }
            .presentationDetents([.medium, .large])
        }
        .backupImporter(isPresented: $showImport)
        .alert("Esportazione non riuscita", isPresented: $exportFailed) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: Sections

    private var colourSection: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            SectionTitle(title: "Colore principale")
            HStack(spacing: Space.s2) {
                ForEach(Accents.all, id: \.id) { p in
                    swatch(p)
                }
            }
        }
    }

    private func swatch(_ p: AccentPreset) -> some View {
        let on = p.id == accentId
        let shape = RoundedRectangle(cornerRadius: Radius.base, style: .continuous)
        return Button {
            withAnimation(Motion.spring) { accentId = p.id }
            Haptics.tick()
        } label: {
            shape.fill(p.color)
                .frame(width: Space.s5, height: Space.s5)
                .overlay {
                    if on {
                        Image(systemName: "checkmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.surface)
                    }
                }
                .overlay(shape.stroke(Theme.ink, lineWidth: on ? 2 : 0).padding(-4))
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(Text(LocalizedStringKey(p.name)))
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            SectionTitle(title: "Lingua")
            Segmented(options: [
                SegmentOption(value: "it", label: "Italiano"),
                SegmentOption(value: "en", label: "English")
            ], selection: $language)
        }
    }

    private var switchesSection: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Toggle(isOn: $alerts) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Avvisi").font(AppFont.sans(17)).foregroundStyle(Theme.ink)
                    Text("Scadenze e promemoria del backup, alle 9:00")
                        .font(AppFont.sans(13)).foregroundStyle(Theme.muted)
                }
            }
            .toggleStyle(AccentToggleStyle())

            Toggle(isOn: $faceID) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Face ID").font(AppFont.sans(17)).foregroundStyle(Theme.ink)
                    Text("Chiede Face ID ogni volta che apri l’app")
                        .font(AppFont.sans(13)).foregroundStyle(Theme.muted)
                }
            }
            .toggleStyle(AccentToggleStyle())

            Toggle(isOn: $animations) {
                Text("Animazioni").font(AppFont.sans(17)).foregroundStyle(Theme.ink)
            }
            .toggleStyle(AccentToggleStyle())

            Toggle(isOn: $haptics) {
                Text("Vibrazioni").font(AppFont.sans(17)).foregroundStyle(Theme.ink)
            }
            .toggleStyle(AccentToggleStyle())
        }
    }

    private var marginSection: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            SectionTitle(title: "Margine serbatoio")
            Segmented(options: [0.25, 0.5, 1.0].map { v in
                SegmentOption(value: v, label: LocalizedStringKey(v.decimal(v == 1 ? 0 : (v == 0.5 ? 1 : 2), locale) + " L"))
            }, selection: $margin)
            Text("Quanto può variare il livello del serbatoio a ogni rifornimento. Serve a stimare il margine dei consumi.")
                .eyebrow()
        }
    }

    private var recapSection: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            SectionTitle(title: "Riepiloghi")
            NavigationLink { RecapListView() } label: {
                HStack {
                    Text("Riepiloghi mensili").font(AppFont.sans(17)).foregroundStyle(Theme.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(accent)
                }
                .padding(.vertical, Space.s1)
                .contentShape(Rectangle())
                .card(padding: Space.s2)
            }
            .buttonStyle(PressStyle())
        }
    }

    private var backupSection: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            SectionTitle(title: "Backup dei dati")
            if lastBackup > 0 {
                (Text("Ultimo backup:") + Text(verbatim: " " + Date(timeIntervalSince1970: lastBackup).short(locale)))
                    .eyebrow()
            }
            autoBackupRows
            VStack(spacing: 0) {
                actionRow("Esporta JSON", symbol: "square.and.arrow.up") { export(json: true) }
                actionRow("Esporta CSV", symbol: "tablecells") { export(json: false) }
                actionRow("Importa backup", symbol: "square.and.arrow.down") { showImport = true }
                actionRow("Esporta database (diagnostica)", symbol: "stethoscope") { exportDatabase() }
            }
            .card(padding: Space.s2)
        }
        .sheet(item: $dbShare) { item in
            ShareSheet(url: item.url)
                .presentationDetents([.medium, .large])
        }
    }

    /// Automatic daily backup to a folder picked once (iCloud Drive), outside the app.
    private var autoBackupRows: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Toggle(isOn: Binding(get: { autoBackup }, set: { on in
                if !on {
                    autoBackup = false
                } else if AutoBackup.hasFolder {
                    autoBackup = true
                    backUpNow()
                } else {
                    pickFolder = true
                }
            })) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Backup automatico").font(AppFont.sans(17)).foregroundStyle(Theme.ink)
                    Text("Ogni giorno, quando apri l’app. Tiene gli ultimi 30.")
                        .font(AppFont.sans(13)).foregroundStyle(Theme.muted)
                }
            }
            .toggleStyle(AccentToggleStyle())

            if autoBackup {
                Button { pickFolder = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Cartella").font(AppFont.sans(17)).foregroundStyle(Theme.ink)
                            if let name = folderName {
                                Text(verbatim: name).font(AppFont.sans(13)).foregroundStyle(Theme.muted)
                            } else {
                                Text("Nessuna cartella").font(AppFont.sans(13)).foregroundStyle(Theme.muted)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
            }
        }
        .onAppear { folderName = AutoBackup.folderName() }
        .sheet(isPresented: $pickFolder) {
            DocumentPicker(types: [.folder]) { url in
                if AutoBackup.saveFolder(url) {
                    folderName = AutoBackup.folderName()
                    autoBackup = true
                    backUpNow()
                } else {
                    autoFailed = true
                }
            }
            .ignoresSafeArea()
        }
        .alert("Backup automatico non riuscito", isPresented: $autoFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Impossibile salvare nella cartella scelta. Scegline un’altra.")
        }
    }

    /// Writes today's automatic backup right away, so the user sees it works.
    private func backUpNow() {
        guard AutoBackup.entryCount(vehicles) > 0 else { return }
        if AutoBackup.write(vehicles: vehicles) {
            Haptics.success()
        } else {
            autoFailed = true
        }
    }

    private var salesSection: some View {
        NavigationLink { SalesHistoryView() } label: {
            HStack {
                Text("Storico per la vendita").font(AppFont.sans(17)).foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: "doc.richtext")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .padding(.vertical, Space.s1)
            .contentShape(Rectangle())
            .card(padding: Space.s2)
        }
        .buttonStyle(PressStyle())
    }

    private func actionRow(_ title: LocalizedStringKey, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(AppFont.sans(17)).foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .padding(.vertical, Space.s1)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }

    private var versionRow: some View {
        HStack {
            Text("Versione").font(AppFont.sans(13)).foregroundStyle(Theme.muted)
            Spacer()
            Text(verbatim: versionString).font(AppFont.sans(13)).foregroundStyle(Theme.muted).monospacedDigit()
        }
    }

    // MARK: Actions

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = info?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private func exportDatabase() {
        if let url = DatabaseExport.makeZip(container: context.container) {
            Haptics.tick()
            dbShare = ShareItem(url: url)
        } else {
            exportFailed = true
        }
    }

    private func export(json: Bool) {
        let day = Date().formatted(.iso8601.year().month().day())
        let data = json ? BackupService.makeJSON(vehicles) : BackupService.makeCSV(vehicles)
        let name = "scoot-\(day).\(json ? "json" : "csv")"
        if let data, let url = BackupService.tempFile(named: name, data: data) {
            Haptics.tick()
            shareItem = ShareItem(url: url)
        } else {
            exportFailed = true
        }
    }
}
