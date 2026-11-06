import SwiftUI

/// "Km percorsi": km per month or per week. Hold and drag to read a bar, like the spending bars.
struct KmBars: View {
    @Environment(\.appAccent) private var accent
    @Environment(\.locale) private var locale
    @AppStorage("language") private var language = "it"
    let months: [KmBucket]
    let weeks: [KmBucket]
    /// 0 = months, 1 = weeks.
    @State private var mode = 0
    @State private var held: Int? = nil

    private var buckets: [KmBucket] { mode == 0 ? months : weeks }

    private func weekLabel(_ b: KmBucket) -> String {
        let cal = Calendar.current
        let same = cal.component(.month, from: b.id) == cal.component(.month, from: b.end)
        var text = same
            ? "\(b.id.formatted(.dateTime.day().locale(locale)))–\(b.end.dayMonth(locale))"
            : "\(b.id.dayMonth(locale)) – \(b.end.dayMonth(locale))"
        if b.id == weeks.last?.id { text += " (\(Loc.tr("in corso", language)))" }
        return text
    }

    private var readout: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let i = held, buckets.indices.contains(i) {
                let b = buckets[i]
                let name = mode == 0
                    ? b.id.formatted(.dateTime.month(.wide).year().locale(locale))
                    : "\(Loc.tr("Settimana", language)) \(weekLabel(b))"
                Text(verbatim: "\(name) · \(Int(b.km.rounded()).grouped(locale)) km")
                    .font(AppFont.sans(15, .semibold)).foregroundStyle(Theme.ink).monospacedDigit()
            } else {
                Text(mode == 0 ? LocalizedStringKey("Tieni premuto un mese per leggerlo.")
                               : LocalizedStringKey("Tieni premuta una settimana per leggerla."))
                    .eyebrow()
            }
        }
        .frame(height: Space.s5, alignment: .topLeading)
    }

    /// Finished periods only: the one still running would pull the average and the record down.
    private var finished: [KmBucket] {
        let b = buckets
        return b.count > 1 ? Array(b.dropLast()) : b
    }

    var body: some View {
        let cap: CGFloat = 96
        let data = buckets
        let tallest = max(data.map { $0.km }.max() ?? 0, 1)
        let unit = cap / CGFloat(tallest)
        let avg = finished.isEmpty ? 0 : finished.reduce(0) { $0 + $1.km } / Double(finished.count)
        let best = finished.map { $0.km }.max() ?? 0
        VStack(alignment: .leading, spacing: 0) {
            Segmented(options: [SegmentOption(value: 0, label: "Mese"), SegmentOption(value: 1, label: "Settimana")],
                      selection: $mode)
            if (months + weeks).allSatisfy({ $0.km <= 0 }) {
                ChartPlaceholder(title: "Il grafico arriva con più letture",
                                 hint: "Servono almeno due letture del contachilometri.")
                    .padding(.top, Space.s2)
            } else {
                readout.padding(.top, Space.s2)
                HStack(alignment: .bottom, spacing: mode == 0 ? Space.s1 : 6) {
                    ForEach(Array(data.enumerated()), id: \.offset) { i, b in
                        VStack(spacing: Space.s1) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(accent)
                                .frame(height: max(Space.s1, CGFloat(b.km) * unit))
                                .frame(height: cap, alignment: .bottom)
                            Group {
                                if mode == 0 {
                                    Text(verbatim: b.id.formatted(.dateTime.month(.narrow).locale(locale)))
                                } else {
                                    Text(verbatim: b.id.formatted(.dateTime.day().locale(locale)))
                                }
                            }
                            .font(AppFont.sans(mode == 0 ? 11 : 10, .semibold))
                            .foregroundStyle(held == i ? Theme.ink : Theme.muted)
                            .frame(height: 14)
                        }
                        .frame(maxWidth: .infinity)
                        .opacity(held == nil || held == i ? 1 : 0.35)
                    }
                }
                .frame(height: cap + Space.s1 + 14, alignment: .bottom)
                .background(
                    ColumnScrub(
                        count: data.count,
                        onSelect: { i in
                            Haptics.tick()
                            withAnimation(Motion.spring) { held = i }
                        },
                        onEnd: { withAnimation(Motion.bounce) { held = nil } }
                    )
                )
                .blocksSwipeBack()
                .padding(.top, Space.s1)
                .animation(Motion.spring, value: mode)

                Text(mode == 0
                     ? LocalizedStringKey("Km tra una lettura del contachilometri e l’altra, divisi sui giorni.")
                     : LocalizedStringKey("Ultime 12 settimane. Il numero sotto è il lunedì. Tra due letture i km sono divisi sui giorni, quindi è una stima."))
                    .eyebrow().padding(.top, Space.s1)

                StatGrid(cells: [
                    StatCellData(title: mode == 0 ? "Media al mese" : "Media a settimana",
                                 value: "\(Int(avg.rounded()).grouped(locale)) km"),
                    StatCellData(title: mode == 0 ? "Mese migliore" : "Settimana migliore",
                                 value: "\(Int(best.rounded()).grouped(locale)) km")
                ])
                .padding(.top, Space.s2)
            }
        }
        .onChange(of: mode) { _, _ in held = nil }
    }
}
