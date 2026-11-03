import SwiftUI
import Charts

struct StatCellData {
    let title: LocalizedStringKey
    let value: String
    var available: Bool = true
}

struct StatGrid: View {
    let cells: [StatCellData]

    var body: some View {
        let cols = [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)]
        LazyVGrid(columns: cols, spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { i, c in
                VStack(alignment: .leading, spacing: Space.s1) {
                    Text(c.title).eyebrow()
                    Text(verbatim: c.value)
                        .font(AppFont.serif(22))
                        .foregroundStyle(c.available ? Theme.ink : Theme.muted)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Space.s2)
                .padding(.leading, i % 2 == 1 ? Space.s2 : 0)
                .overlay(alignment: .top) { Hairline() }
                .overlay(alignment: .leading) {
                    if i % 2 == 1 { Rectangle().fill(Theme.line).frame(width: 1) }
                }
            }
        }
    }
}

struct ConsumptionChart: View {
    @Environment(\.appAccent) private var accent
    @Environment(\.locale) private var locale
    let points: [ConsumptionPoint]
    let average: Double?
    @State private var selected: Date? = nil

    private var nearest: ConsumptionPoint? {
        guard let s = selected else { return nil }
        return points.min(by: { abs($0.date.timeIntervalSince(s)) < abs($1.date.timeIntervalSince(s)) })
    }

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
            if let n = nearest {
                RuleMark(x: .value("Data", n.date))
                    .foregroundStyle(Theme.line)
                    .annotation(position: .top, alignment: .center) {
                        Text(verbatim: "\(n.kmPerL.decimal(1, locale)) km/L · \(n.date.dayMonth(locale))")
                            .font(AppFont.sans(13, .semibold)).foregroundStyle(Theme.ink)
                    }
            }
        }
        .chartYScale(domain: lo...hi)
        .chartXSelection(value: $selected)
        .blocksSwipeBack()
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
        .frame(height: 200)
        .onChange(of: nearest?.id) { _, _ in Haptics.tick() }
    }
}

struct PriceChart: View {
    @Environment(\.appAccent) private var accent
    @Environment(\.locale) private var locale
    let points: [PricePoint]
    @State private var selected: Date? = nil

    private var nearest: PricePoint? {
        guard let s = selected else { return nil }
        return points.min(by: { abs($0.date.timeIntervalSince(s)) < abs($1.date.timeIntervalSince(s)) })
    }

    var body: some View {
        let vals = points.map { $0.price }
        let lo = (vals.min() ?? 1) * 0.98
        let hi = max((vals.max() ?? 2) * 1.02, lo + 0.01)
        Chart {
            ForEach(points) { p in
                LineMark(x: .value("Data", p.date), y: .value("€/L", p.price))
                    .foregroundStyle(accent)
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Data", p.date), y: .value("€/L", p.price))
                    .foregroundStyle(accent)
            }
            if let n = nearest {
                RuleMark(x: .value("Data", n.date))
                    .foregroundStyle(Theme.line)
                    .annotation(position: .top, alignment: .center) {
                        Text(verbatim: "\(n.price.decimal(3, locale)) €/L · \(n.date.dayMonth(locale))")
                            .font(AppFont.sans(13, .semibold)).foregroundStyle(Theme.ink)
                    }
            }
        }
        .chartYScale(domain: lo...hi)
        .chartXSelection(value: $selected)
        .blocksSwipeBack()
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
        .frame(height: 200)
        .onChange(of: nearest?.id) { _, _ in Haptics.tick() }
    }
}

/// Stacked monthly bars: variable spending in accent, yearly items in a lighter tint.
struct MonthlyBars: View {
    @Environment(\.appAccent) private var accent
    @Environment(\.locale) private var locale
    let months: [MonthBucket]
    /// Bar being held (press and hold, then drag); nil when the finger is up.
    @State private var held: Int? = nil

    private var readout: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let i = held, months.indices.contains(i) {
                let m = months[i]
                Text(verbatim: "\(m.id.formatted(.dateTime.month(.wide).year().locale(locale))) · \(m.total.money(locale))")
                    .font(AppFont.sans(15, .semibold)).foregroundStyle(Theme.ink).monospacedDigit()
                if m.annual > 0 {
                    Text("di cui \(m.annual.money(locale)) annuali").eyebrow()
                }
            } else {
                Text("Tieni premuto un mese per leggerlo.").eyebrow()
            }
        }
        .frame(height: Space.s5, alignment: .topLeading)
    }

    var body: some View {
        let maxV = max(months.map { $0.total }.max() ?? 1, 1)
        VStack(alignment: .leading, spacing: Space.s1) {
            readout
            HStack(alignment: .bottom, spacing: Space.s1) {
                ForEach(Array(months.enumerated()), id: \.offset) { i, m in
                    VStack(spacing: Space.s1) {
                        VStack(spacing: 2) {
                            if m.annual > 0 {
                                RoundedRectangle(cornerRadius: Radius.base, style: .continuous)
                                    .fill(accent.opacity(0.55))
                                    .frame(height: CGFloat(m.annual / maxV) * 96)
                            }
                            RoundedRectangle(cornerRadius: Radius.base, style: .continuous)
                                .fill(accent)
                                .frame(height: max(Space.s1, CGFloat(m.variable / maxV) * 96))
                        }
                        Text(verbatim: m.id.formatted(.dateTime.month(.narrow).locale(locale)))
                            .font(AppFont.sans(11, .semibold))
                            .foregroundStyle(held == i ? Theme.ink : Theme.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(held == nil || held == i ? 1 : 0.35)
                }
            }
            .frame(height: 128, alignment: .bottom)
            .background(
                ColumnScrub(
                    count: months.count,
                    onSelect: { i in
                        Haptics.tick()
                        withAnimation(Motion.spring) { held = i }
                    },
                    onEnd: { withAnimation(Motion.bounce) { held = nil } }
                )
            )
            .blocksSwipeBack()
        }
    }
}

struct SplitBar: View {
    @Environment(\.appAccent) private var accent
    @Environment(\.locale) private var locale
    let slices: [SplitSlice]

    private func tint(_ i: Int) -> Color {
        switch i {
        case 0: return accent
        case 1: return accent.opacity(0.55)
        default: return accent.opacity(0.28)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
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
            VStack(alignment: .leading, spacing: Space.s1) {
                ForEach(slices) { s in
                    HStack(spacing: Space.s1) {
                        Circle().fill(tint(s.tint)).frame(width: Space.s1, height: Space.s1)
                        Text(LocalizedStringKey(s.title)).font(AppFont.sans(15)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text(verbatim: "\(Int((s.share * 100).rounded()))%")
                            .font(AppFont.sans(15, .semibold)).foregroundStyle(Theme.ink).monospacedDigit()
                        Text(s.amount.money(locale)).font(AppFont.sans(13)).foregroundStyle(Theme.muted).monospacedDigit()
                    }
                }
            }
        }
    }
}
