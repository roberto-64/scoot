import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.locale) private var locale
    @Environment(\.appAccent) private var accent
    @AppStorage("userName") private var userName = ""
    @AppStorage("language") private var language = "it"
    @AppStorage("selectedVehicle") private var selectedID = ""
    @AppStorage("hideChecklist") private var hideChecklist = false
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    var onAdd: () -> Void

    @State private var showVehicleForm = false
    @State private var showImport = false
    @State private var deadlineSheet: DeadlineRoute? = nil
    /// Month bar being held (index into the six bars); nil means the current month.
    @State private var heldMonth: Int? = nil
    /// Last month that was held. The legend keeps showing it while it slides away.
    @State private var legendMonth: Int = 0
    /// Width of the bars row, to know how many lines the legend needs.
    @State private var barsWidth: CGFloat = 0
    /// How far the cards below the bars are pushed down while a month is held (they slide with an offset,
    /// which animates smoothly; the page itself does not change height).
    @State private var slideAmount: CGFloat = 0

    private var vehicle: Vehicle? { selectedVehicle(vehicles, id: selectedID) }
    private var hasEntries: Bool { vehicles.contains(where: { $0.entryCount > 0 }) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale))).eyebrow()
                    greeting
                        .font(AppFont.serif(32))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, Space.s1)

                    if vehicles.isEmpty {
                        firstLaunch
                    } else {
                        statusLine
                        if !hasEntries && !hideChecklist { checklist }
                        spendSection
                        if let v = vehicle {
                            vehicleCard(v)
                                .offset(y: slideAmount)
                                .animation(Motion.spring, value: slideAmount)
                        }
                        recentSection
                            .offset(y: slideAmount)
                            .animation(Motion.spring, value: slideAmount)
                    }
                }
                .padding(.horizontal, Space.s2)
                .padding(.top, Space.s2)
                .padding(.bottom, Space.s2)
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: Space.s8 + Space.s2) }
            .screenBackground(glow: true)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showVehicleForm) {
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
            .backupImporter(isPresented: $showImport)
        }
    }

    // MARK: pieces

    @ViewBuilder
    private var greeting: some View {
        if userName.isEmpty { Text("Ciao") } else { Text("Ciao, \(userName)") }
    }

    private var firstLaunch: some View {
        VStack(spacing: Space.s3) {
            VStack(spacing: Space.s3) {
                ScooterIcon(width: 160).foregroundStyle(accent)
                Text("Aggiungi il tuo primo veicolo")
                    .font(AppFont.serif(22)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
                Text("Registra rifornimenti, manutenzioni e scadenze. Niente account e niente targa: i dati restano su questo telefono.")
                    .font(AppFont.sans(15)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                PrimaryButton(title: "Aggiungi veicolo") { showVehicleForm = true }
            }
            .padding(.vertical, Space.s2)
            .card(padding: Space.s3)

            Button { showImport = true } label: {
                HStack(spacing: Space.s1) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Ho già un backup: importa")
                }
                .font(AppFont.sans(15, .semibold))
                .foregroundStyle(accent)
            }
            .buttonStyle(PressStyle())
            .frame(maxWidth: .infinity)
        }
        .padding(.top, Space.s4)
    }

    private var upcoming: [UpcomingItem] { Upcoming.items(for: vehicles, lang: language) }

    private var statusLine: some View {
        let late = upcoming.filter { $0.isOverdue }.count
        let soon = upcoming.filter { $0.isComingUp }.count
        return HStack(spacing: Space.s1) {
            Image(systemName: late > 0 ? "exclamationmark.circle.fill" : (soon == 0 ? "checkmark.circle" : "exclamationmark.circle"))
            statusText(late: late, soon: soon)
        }
        .font(AppFont.sans(15, .semibold))
        .foregroundStyle(late > 0 ? Theme.ink : accent)
        .padding(.vertical, Space.s1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Hairline() }
        .overlay(alignment: .bottom) { Hairline() }
        .padding(.top, Space.s2)
    }

    /// "In regola", or what is overdue and what is coming up, with the right singular for one.
    private func statusText(late: Int, soon: Int) -> Text {
        let comingUp: Text = soon == 1 ? Text("1 scadenza in arrivo") : Text("\(soon) scadenze in arrivo")
        if late == 0 && soon == 0 { return Text("Il tuo garage è in regola") }
        let overdue: Text = late == 1 ? Text("1 scaduta") : Text("\(late) scadute")
        if late > 0 && soon == 0 { return overdue }
        if late == 0 { return comingUp }
        let short: Text = soon == 1 ? Text("1 in arrivo") : Text("\(soon) in arrivo")
        return overdue + Text(verbatim: " · ") + short
    }

    private var checklist: some View {
        let hasVehicle = !vehicles.isEmpty
        let hasDeadlines = vehicles.contains(where: { !$0.deadlines.isEmpty })
        let done = 1 + (hasEntries ? 1 : 0) + (hasDeadlines ? 1 : 0)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionTitle(title: "Per iniziare")
                Spacer()
                Text("\(done) di 3").eyebrow()
            }
            .padding(.bottom, Space.s2)
            checkRow("Aggiungi il veicolo", done: hasVehicle, hint: nil, action: {})
            checkRow("Registra il primo rifornimento", done: hasEntries, hint: "Serve per vedere i consumi", action: onAdd)
            checkRow("Imposta le scadenze", done: hasDeadlines, hint: "RCA, Bollo e Revisione") {
                if let v = vehicle { deadlineSheet = DeadlineRoute(vehicle: v, kind: .rca) }
            }
            Button { hideChecklist = true } label: {
                Text("Nascondi").font(AppFont.sans(13, .semibold)).foregroundStyle(Theme.muted)
            }
            .padding(.top, Space.s1)
        }
        .card()
        .padding(.top, Space.s3)
    }

    private func checkRow(_ title: String, done: Bool, hint: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Space.s2) {
                ZStack {
                    Circle().fill(done ? accent : Color.clear)
                    Circle().stroke(done ? accent : Theme.muted, lineWidth: 1.5)
                    if done { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.surface) }
                }
                .frame(width: Space.s3, height: Space.s3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(title))
                        .font(AppFont.serif(17))
                        .foregroundStyle(done ? Theme.muted : Theme.ink)
                        .strikethrough(done)
                    if let h = hint, !done { Text(LocalizedStringKey(h)).font(AppFont.sans(13)).foregroundStyle(Theme.muted) }
                }
                Spacer()
                if !done { Image(systemName: "chevron.right").foregroundStyle(Theme.muted) }
            }
            .padding(.vertical, Space.s2)
            .contentShape(Rectangle())
            .overlay(alignment: .top) { Hairline() }
        }
        .buttonStyle(.plain)
    }

    private var spendSection: some View {
        let summary = StatsEngine.summary(vehicles: vehicles, range: .m6, spread: false)
        let lastIndex = max(summary.months.count - 1, 0)
        let sel = min(heldMonth ?? lastIndex, lastIndex)
        let shown: MonthBucket? = summary.months.indices.contains(sel) ? summary.months[sel] : nil
        let thisMonth = shown?.total ?? 0
        let shownDate = shown?.id ?? Date()
        let chartHeight: CGFloat = 88
        let unit = SpendScale.unit(summary.months, cap: chartHeight)
        // Legend of the held month, and how far the cards below slide down to make room for it.
        let legendIndex = min(legendMonth, lastIndex)
        let legendBucket: MonthBucket? = summary.months.indices.contains(legendIndex) ? summary.months[legendIndex] : nil
        let legendWidth = barsWidth > 0 ? barsWidth : 361
        let legendItems = legendBucket.map {
            MonthLegend.items(for: $0, language: language, locale: locale, width: legendWidth)
        } ?? []
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Spesa di \(shownDate.formatted(.dateTime.month(.wide).locale(locale)))").eyebrow()
                Spacer()
                NavigationLink { StatsView() } label: {
                    HStack(spacing: 2) { Text("Riepilogo"); Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)) }
                        .font(AppFont.sans(13, .semibold)).foregroundStyle(accent)
                }
            }
            .padding(.top, Space.s3)
            HStack(alignment: .firstTextBaseline, spacing: Space.s1) {
                Text(thisMonth.decimal(2, locale))
                    .font(AppFont.serif(56))
                    .foregroundStyle(thisMonth > 0 ? Theme.ink : Theme.muted)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(verbatim: "€").font(AppFont.serif(32)).foregroundStyle(Theme.muted)
            }
            .padding(.top, Space.s1)
            .animation(Motion.spring, value: thisMonth)
            if thisMonth == 0 && !hasEntries {
                Text("Qui comparirà quello che spendi ogni mese.").eyebrow().padding(.top, Space.s1)
            }
            HStack(alignment: .bottom, spacing: Space.s1) {
                ForEach(Array(summary.months.enumerated()), id: \.offset) { i, m in
                    let current = i == sel
                    VStack(spacing: Space.s1) {
                        SpendColumn(
                            bucket: m, unit: unit, cap: chartHeight,
                            everyday: current ? Theme.ink : Theme.line,
                            yearly: (heldMonth == i) ? accent : accent.opacity(0.55))
                        Text(verbatim: m.id.formatted(.dateTime.month(.narrow).locale(locale)))
                            .font(AppFont.sans(11, .semibold))
                            .foregroundStyle(current ? Theme.ink : Theme.muted)
                            .frame(height: 14)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: chartHeight + Space.s1 + 14, alignment: .bottom)
            .background(
                GeometryReader { g in
                    Color.clear
                        .onAppear { barsWidth = g.size.width }
                        .onChange(of: g.size.width) { _, w in barsWidth = w }
                }
            )
            .background(
                ColumnScrub(
                    count: summary.months.count,
                    onSelect: { i in
                        Haptics.tick()
                        legendMonth = i
                        let items = MonthLegend.items(for: summary.months[i], language: language,
                                                      locale: locale, width: legendWidth)
                        let rows = MonthLegend.rows(of: items, width: legendWidth, locale: locale)
                        let depth: CGFloat = rows == 0 ? 0 : Space.s2 + MonthLegend.height(rows: rows)
                        withAnimation(Motion.spring) {
                            heldMonth = i
                            slideAmount = depth
                        }
                    },
                    onEnd: {
                        withAnimation(Motion.bounce) {
                            heldMonth = nil
                            slideAmount = 0
                        }
                    }
                )
            )
            .blocksSwipeBack()
            .padding(.top, Space.s1)
            .animation(Motion.spring, value: sel)
            .animation(Motion.spring, value: thisMonth)
            // Breakdown of the held month. It takes no room of its own: it sits behind the vehicle card,
            // which slides down (see `slideAmount`) and uncovers it.
            Color.clear
                .frame(height: 0)
                .overlay(alignment: .topLeading) {
                    MonthLegendView(items: legendItems)
                        .padding(.top, Space.s2)
                        .opacity(heldMonth == nil ? 0 : 1)
                        .animation(Motion.fade, value: heldMonth == nil)
                }
                .accessibilityHidden(heldMonth == nil)
        }
    }

    private func vehicleCard(_ v: Vehicle) -> some View {
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
                }
            }
            .card()
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .padding(.top, Space.s3)
    }

    private var recentSection: some View {
        let recent = HistoryEntry.recent(vehicles, limit: 5)
        return VStack(alignment: .leading, spacing: 0) {
            if !recent.isEmpty {
                Text("Attività recente").eyebrow().padding(.top, Space.s3)
                ForEach(Array(recent.enumerated()), id: \.element.id) { i, e in
                    HistoryRow(entry: e, showVehicle: vehicles.count > 1, previousID: i > 0 ? recent[i - 1].id : nil).rowTransition()
                }
            }
        }
        .animation(Motion.bounce, value: recent.map { $0.id })
    }
}

struct DeadlineRoute: Identifiable {
    let id = UUID()
    let vehicle: Vehicle
    let kind: DeadlineKind
}

/// Accent square with the custom scooter, used on vehicle cards.
struct VehicleBadge: View {
    @Environment(\.appAccent) private var accent
    var body: some View {
        ScooterIcon(width: Space.s4)
            .foregroundStyle(Theme.surface)
            .frame(width: Space.s6, height: Space.s6)
            .background(accent, in: RoundedRectangle(cornerRadius: Radius.base, style: .continuous))
    }
}
