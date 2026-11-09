import SwiftUI
import SwiftData
import Charts

// MARK: - Text helpers

enum RecapText {
    static func monthName(_ d: Date, _ locale: Locale) -> String {
        d.formatted(.dateTime.month(.wide).locale(locale))
    }

    static func monthTitle(_ d: Date, _ locale: Locale) -> String {
        monthName(d, locale).capitalized(with: locale)
    }

    private static func sign(_ v: Double) -> String { v > 0 ? "+" : (v < 0 ? "−" : "") }

    static func km(_ delta: Int, _ locale: Locale) -> String {
        "\(sign(Double(delta)))\(abs(delta).grouped(locale))\u{00A0}km"
    }

    static func money(_ delta: Double, _ locale: Locale) -> String {
        let text = abs(delta).money(locale).replacingOccurrences(of: " ", with: "\u{00A0}")
        return "\(sign(delta))\(text)"
    }

    static func kmPerL(_ delta: Double, _ locale: Locale) -> String {
        "\(sign(delta))\(abs(delta).decimal(1, locale))\u{00A0}km/L"
    }

    static func percent(_ p: Int) -> String {
        "\(sign(Double(p)))\(abs(p))%"
    }

    /// "Ottobre 2026", with " · in corso" while the month is still running.
    static func heading(_ month: Date, _ locale: Locale, _ language: String) -> String {
        var t = monthTitle(month, locale) + " " + month.formatted(.dateTime.year().locale(locale))
        if month == Date().startOfMonth { t += " · " + Loc.tr("in corso", language) }
        return t
    }

    /// "5–11" (a single day when the week has only one day inside the month).
    static func weekLabel(_ w: RecapWeek, _ locale: Locale) -> String {
        let a = w.id.formatted(.dateTime.day().locale(locale))
        let b = w.end.formatted(.dateTime.day().locale(locale))
        return a == b ? a : "\(a)–\(b)"
    }

    /// "Il tuo ottobre con Filippo" needs the vehicle name only when a single vehicle is in scope.
    static func vehicleName(_ vehicles: [Vehicle]) -> String? {
        vehicles.count == 1 ? vehicles.first?.displayName : nil
    }
}

struct RecapShareFile: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Pieces

/// The scooter from the app, large and almost invisible, behind the text.
struct RecapWatermark: View {
    var width: CGFloat
    var opacity: Double = 0.04

    var body: some View {
        Image("Scooter")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .foregroundStyle(Theme.ink.opacity(opacity))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Km per week of the month, with the km written inside each bar. The best week is drawn in full colour.
struct RecapWeekBars: View {
    @Environment(\.appAccent) private var accent
    @Environment(\.locale) private var locale
    let weeks: [RecapWeek]
    let best: Int?
    var cap: CGFloat = 88
    var gap: CGFloat = Space.s1

    var body: some View {
        let top = max(weeks.map { $0.km }.max() ?? 0, 1)
        VStack(spacing: Space.s1) {
            HStack(alignment: .bottom, spacing: gap) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { i, w in
                    let h: CGFloat = w.km > 0 ? max(22, cap * CGFloat(w.km / top)) : 4
                    let fill: Color = w.km > 0 ? (i == best ? accent : accent.opacity(0.78)) : Theme.line
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(fill)
                        .frame(height: h)
                        .overlay(alignment: .bottom) {
                            if w.km > 0 {
                                Text(verbatim: Int(w.km.rounded()).grouped(locale))
                                    .font(AppFont.sans(11, .semibold))
                                    .foregroundStyle(Theme.surface)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .padding(.bottom, 6)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: cap, alignment: .bottom)
                }
            }
            HStack(spacing: gap) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, w in
                    Text(verbatim: RecapText.weekLabel(w, locale))
                        .font(AppFont.sans(10, .semibold))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

/// "−20 km", "+6,10 €", "+0,4 km/L": what changed since the month before.
struct RecapPills: View {
    @Environment(\.appAccent) private var accent
    @Environment(\.locale) private var locale
    let recap: MonthRecap

    private var texts: [String] {
        var out: [String] = []
        if let d = recap.kmDelta { out.append(RecapText.km(d, locale)) }
        if let d = recap.spentDelta { out.append(RecapText.money(d, locale)) }
        if let d = recap.kmPerLDelta { out.append(RecapText.kmPerL(d, locale)) }
        return out
    }

    var body: some View {
        FlowLayout(hSpacing: Space.s1, vSpacing: Space.s1) {
            ForEach(Array(texts.enumerated()), id: \.offset) { _, t in
                Text(verbatim: t)
                    .font(AppFont.sans(13, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(accent.opacity(0.14), in: Capsule())
            }
        }
    }
}

/// Consumption through the month (same look as the one in Summary, without touch reading).
struct RecapConsumptionChart: View {
    @Environment(\.appAccent) private var accent
    let points: [ConsumptionPoint]
    let average: Double?

    var body: some View {
        let vals = points.map { $0.kmPerL }
        let lo = (vals.min() ?? 0) * 0.9
        let hi = max((vals.max() ?? 1) * 1.1, lo + 1)
        Chart {
            ForEach(points) { p in
                LineMark(x: .value("Data", p.date), y: .value("km/L", p.kmPerL))
                    .foregroundStyle(accent)
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Data", p.date), y: .value("km/L", p.kmPerL))
                    .foregroundStyle(accent)
            }
            if let a = average {
                RuleMark(y: .value("Media", a))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Theme.muted)
            }
        }
        .chartYScale(domain: lo...hi)
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(Theme.line)
                AxisValueLabel().foregroundStyle(Theme.muted)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(Theme.line)
                AxisValueLabel().foregroundStyle(Theme.muted)
            }
        }
        .frame(height: 160)
    }
}

// MARK: - The pop-up

/// Full recap of one finished month. Opens by itself on the first launch of a new month, and from
/// Settings > Riepiloghi mensili for any past month. It scrolls; Share and Close stay at the bottom.
struct RecapSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.appAccent) private var accent
    @AppStorage("language") private var language = "it"
    @AppStorage("tankMargin") private var margin = 0.5
    let vehicles: [Vehicle]
    let month: Date
    @State private var shareItem: RecapShareFile?
    @State private var failed = false

    var body: some View {
        let r = MonthRecap.make(vehicles: vehicles, month: month, margin: margin)
        ZStack(alignment: .top) {
            Theme.bg
            // An overlay, so the wide scooter never makes the sheet wider than the screen.
            Color.clear.overlay(alignment: .top) {
                RecapWatermark(width: 470).offset(x: -20, y: 240)
            }
            ScrollView {
                content(r)
                    .padding(.horizontal, Space.s2)
                    .padding(.top, Space.s5)
                    .padding(.bottom, Space.s3)
            }
            .scrollIndicators(.hidden)
        }
        .clipped()
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: { IconSquare(systemName: "xmark") }
                .buttonStyle(PressStyle())
                .padding(.trailing, Space.s2)
                .padding(.top, Space.s3)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Space.s1) {
                PrimaryButton(title: "Condividi") { share(r) }
                Button { dismiss() } label: {
                    Text("Chiudi")
                        .font(AppFont.sans(17, .semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: Space.s5)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
            }
            .padding(.horizontal, Space.s2)
            .padding(.top, Space.s1)
            .padding(.bottom, Space.s1)
            .background(Theme.bg.ignoresSafeArea())
            .overlay(alignment: .top) {
                // Soft edge so the content slides under the buttons instead of being cut.
                LinearGradient(colors: [Theme.bg.opacity(0), Theme.bg], startPoint: .top, endPoint: .bottom)
                    .frame(height: Space.s4)
                    .offset(y: -Space.s4)
                    .allowsHitTesting(false)
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(url: item.url)
                .presentationDetents([.medium, .large])
        }
        .alert("Impossibile creare l’immagine", isPresented: $failed) {
            Button("OK", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func content(_ r: MonthRecap) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: RecapText.heading(r.month, locale, language))
                .eyebrow()
            title(r).padding(.top, Space.s1)

            if r.km > 0 {
                HStack(alignment: .firstTextBaseline, spacing: Space.s1) {
                    Text(verbatim: Int(r.km.rounded()).grouped(locale))
                        .font(AppFont.serif(72)).foregroundStyle(Theme.ink).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(verbatim: "km").font(AppFont.sans(22)).foregroundStyle(Theme.muted)
                }
                .padding(.top, Space.s4)
                subtitle(r).padding(.top, 4)
            }

            if let best = r.bestWeekIndex {
                SectionTitle(title: "Km per settimana").padding(.top, Space.s3)
                RecapWeekBars(weeks: r.weeks, best: best).padding(.top, Space.s2)
                bestWeek(r, best).eyebrow().padding(.top, Space.s1)
            }

            StatGrid(cells: [
                StatCellData(title: "Speso", value: r.spent.money(locale)),
                StatCellData(title: "Carburante", value: r.liters > 0 ? "\(r.liters.decimal(1, locale)) L" : "—", available: r.liters > 0),
                StatCellData(title: "Consumo medio", value: r.kmPerL.map { "\($0.decimal(1, locale)) km/L" } ?? "—", available: r.kmPerL != nil),
                StatCellData(title: "Rifornimenti", value: "\(r.fills)")
            ])
            .padding(.top, Space.s3)

            if r.hasComparison {
                comparison(r).padding(.top, Space.s3)
            }

            if !r.split.isEmpty {
                SectionTitle(title: "Dove sono andati i soldi").padding(.top, Space.s3)
                SplitBar(slices: r.split).padding(.top, Space.s2)
                Text("Senza assicurazione, bollo e revisione").eyebrow().padding(.top, Space.s1)
            }

            if r.points.count >= 2 {
                SectionTitle(title: "Consumo, km/L").padding(.top, Space.s4)
                RecapConsumptionChart(points: r.points, average: r.kmPerL).padding(.top, Space.s2)
                Text("Linea tratteggiata: media del mese").eyebrow().padding(.top, Space.s1)
            }
        }
    }

    private func title(_ r: MonthRecap) -> some View {
        let name = RecapText.monthName(r.month, locale)
        return Group {
            if let v = RecapText.vehicleName(vehicles) {
                Text("Il tuo \(name) con \(v)")
            } else {
                Text("Il tuo \(name)")
            }
        }
        .font(AppFont.serif(40)).foregroundStyle(Theme.ink)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func subtitle(_ r: MonthRecap) -> some View {
        var t = Text("percorsi")
        if let p = r.prevKm, p > 0 {
            let name = RecapText.monthName(r.previousMonth, locale)
            t = t + Text(verbatim: " · \(name): \(Int(p.rounded()).grouped(locale)) km")
        }
        return t.eyebrow()
    }

    private func bestWeek(_ r: MonthRecap, _ i: Int) -> Text {
        let w = r.weeks[i]
        let mon = w.id.formatted(.dateTime.month(.abbreviated).locale(locale))
        return Text("Settimana migliore:")
            + Text(verbatim: " \(RecapText.weekLabel(w, locale)) \(mon), \(Int(w.km.rounded()).grouped(locale)) km")
    }

    private func comparison(_ r: MonthRecap) -> some View {
        let name = RecapText.monthName(r.previousMonth, locale)
        var parts: [String] = []
        if let p = r.kmPercent { parts.append("\(Loc.tr("Km", language)) \(RecapText.percent(p))") }
        if let p = r.spentPercent { parts.append("\(Loc.tr("Spesa", language)) \(RecapText.percent(p))") }
        if let p = r.kmPerLPercent { parts.append("\(Loc.tr("Consumo", language)) \(RecapText.percent(p))") }
        return VStack(alignment: .leading, spacing: Space.s1) {
            SectionTitle(title: "Rispetto a \(name)")
            RecapPills(recap: r).padding(.top, Space.s1)
            if !parts.isEmpty {
                Text(verbatim: parts.joined(separator: " · ")).eyebrow()
            }
        }
    }

    @MainActor
    private func share(_ r: MonthRecap) {
        let card = RecapShareCard(recap: r, vehicleName: RecapText.vehicleName(vehicles))
            .environment(\.locale, locale)
            .environment(\.appAccent, accent)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        guard let data = renderer.uiImage?.pngData(),
              let url = BackupService.tempFile(named: "scoot-\(RecapKey.string(r.month)).png", data: data) else {
            failed = true
            return
        }
        Haptics.tick()
        shareItem = RecapShareFile(url: url)
    }
}

// MARK: - The image that gets shared

/// Vertical card drawn off-screen and saved as a PNG (360 pt wide, drawn at 3x = 1080 px).
struct RecapShareCard: View {
    @Environment(\.appAccent) private var accent
    @Environment(\.locale) private var locale
    let recap: MonthRecap
    let vehicleName: String?

    var body: some View {
        let r = recap
        let name = RecapText.monthName(r.month, locale)
        VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: RecapText.heading(r.month, locale, locale.identifier))
                    .eyebrow()
                Group {
                    if let v = vehicleName {
                        Text("Il mio \(name) con \(v)")
                    } else {
                        Text("Il mio \(name)")
                    }
                }
                .font(AppFont.serif(30)).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

                if r.km > 0 {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(verbatim: Int(r.km.rounded()).grouped(locale))
                            .font(AppFont.serif(56)).foregroundStyle(Theme.ink).monospacedDigit()
                        Text(verbatim: "km").font(AppFont.sans(22)).foregroundStyle(Theme.muted)
                    }
                    .padding(.top, Space.s2)
                }

                if let best = r.bestWeekIndex {
                    RecapWeekBars(weeks: r.weeks, best: best, cap: 64, gap: 6).padding(.top, Space.s2)
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.s3), GridItem(.flexible())],
                          alignment: .leading, spacing: Space.s2) {
                    cell("Speso", r.spent.money(locale))
                    cell("Carburante", r.liters > 0 ? "\(r.liters.decimal(1, locale)) L" : "—")
                    cell("Consumo medio", r.kmPerL.map { "\($0.decimal(1, locale)) km/L" } ?? "—")
                    cell("Rifornimenti", "\(r.fills)")
                }
                .padding(.top, Space.s3)

                if r.hasComparison {
                    let prev = RecapText.monthName(r.previousMonth, locale)
                    Text("Rispetto a \(prev)").eyebrow().padding(.top, Space.s3)
                    RecapPills(recap: r).padding(.top, Space.s1)
                }

                if !r.split.isEmpty {
                    splitBar(r.split).padding(.top, Space.s3)
                }

                HStack(spacing: 6) {
                    ScooterIcon(width: 12)
                        .foregroundStyle(Theme.surface)
                        .frame(width: 20, height: 20)
                        .background(accent, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    Text(verbatim: "Scoot")
                        .font(AppFont.sans(12, .semibold)).foregroundStyle(Theme.ink)
                }
                .opacity(0.85)
                .padding(.top, Space.s3)
        }
        .padding(Space.s3)
        .frame(width: 360, alignment: .topLeading)
        .background(alignment: .topLeading) {
            // Drawn behind the content, so the wide scooter never changes the size of the image.
            ZStack(alignment: .topLeading) {
                Theme.bg
                RadialGradient(colors: [accent.opacity(0.24), accent.opacity(0)],
                               center: .topLeading, startRadius: 0, endRadius: 320)
                    .frame(height: 300)
                Color.clear.overlay(alignment: .topLeading) {
                    RecapWatermark(width: 420).offset(x: -30, y: 170)
                }
            }
        }
        .clipped()
    }

    private func cell(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).eyebrow()
            Text(verbatim: value)
                .font(AppFont.serif(20)).foregroundStyle(Theme.ink).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tint(_ i: Int) -> Color {
        switch i {
        case 0: return accent
        case 1: return accent.opacity(0.55)
        default: return accent.opacity(0.28)
        }
    }

    private func splitBar(_ slices: [SplitSlice]) -> some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(slices) { s in
                        RoundedRectangle(cornerRadius: Radius.base, style: .continuous)
                            .fill(tint(s.tint))
                            .frame(width: max(4, geo.size.width * CGFloat(s.share) - 2))
                    }
                }
            }
            .frame(height: Space.s2)
            HStack(spacing: Space.s2) {
                ForEach(slices) { s in
                    HStack(spacing: 6) {
                        Circle().fill(tint(s.tint)).frame(width: 6, height: 6)
                        (Text(LocalizedStringKey(s.title)) + Text(verbatim: " \(Int((s.share * 100).rounded()))%"))
                            .font(AppFont.sans(11)).foregroundStyle(Theme.ink)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

// MARK: - List of past recaps (Settings)

struct RecapListView: View {
    @Environment(\.locale) private var locale
    @Environment(\.appAccent) private var accent
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @AppStorage("tankMargin") private var margin = 0.5
    @AppStorage("language") private var language = "it"
    @State private var open: RecapRef?

    var body: some View {
        let months = MonthRecap.months(vehicles: vehicles, includeCurrent: true)
        let days = KmStats.perDay(vehicles, since: RecapStart.date)
        let years = Array(Set(months.map { Calendar.current.component(.year, from: $0) })).sorted(by: >)

        ScrollView {
            VStack(alignment: .leading, spacing: Space.s3) {
                BackHeader(title: "Riepiloghi mensili")
                if months.isEmpty {
                    ChartPlaceholder(title: "Ancora nessun riepilogo",
                                     hint: "Il primo arriva a fine mese, quando hai registrato qualcosa.")
                } else {
                    ForEach(years, id: \.self) { y in
                        yearBlock(y, months: months, days: days)
                    }
                    Text("Compaiono solo i mesi con dati. Tocca un mese per rivedere il riepilogo completo.").eyebrow()
                }
            }
            .padding(.horizontal, Space.s2)
            .padding(.top, Space.s2)
            .padding(.bottom, Space.s4)
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: Space.s8 + Space.s2) }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $open) { ref in
            RecapSheet(vehicles: vehicles, month: ref.month)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(Radius.base)
                .presentationBackground(Theme.bg)
        }
    }

    private func yearBlock(_ year: Int, months: [Date], days: [Date: Double]) -> some View {
        let inYear = months.filter { Calendar.current.component(.year, from: $0) == year }
        return VStack(alignment: .leading, spacing: Space.s1) {
            Text(verbatim: String(year)).eyebrow()
            VStack(spacing: 0) {
                ForEach(Array(inYear.enumerated()), id: \.offset) { i, m in
                    if i > 0 { Hairline() }
                    row(m, days: days)
                }
            }
            .card(padding: Space.s2)
        }
    }

    private func row(_ month: Date, days: [Date: Double]) -> some View {
        let r = MonthRecap.make(vehicles: vehicles, month: month, margin: margin,
                                perDay: days, withPrevious: false)
        var parts: [String] = []
        if month == Date().startOfMonth { parts.append(Loc.tr("in corso", language)) }
        if r.km > 0 { parts.append("\(Int(r.km.rounded()).grouped(locale)) km") }
        if r.spent > 0 { parts.append(r.spent.money(locale)) }
        return Button { open = RecapRef(month: month) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: RecapText.monthTitle(month, locale))
                        .font(AppFont.sans(17)).foregroundStyle(Theme.ink)
                    if !parts.isEmpty {
                        Text(verbatim: parts.joined(separator: " · "))
                            .font(AppFont.sans(13)).foregroundStyle(Theme.muted).monospacedDigit()
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accent)
            }
            .padding(.vertical, Space.s1)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}
