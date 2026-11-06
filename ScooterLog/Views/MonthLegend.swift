import SwiftUI
import UIKit

/// Lays its children out left to right and wraps to a new line when one does not fit.
struct FlowLayout: Layout {
    var hSpacing: CGFloat
    var vSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineH: CGFloat = 0
        var widest: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0 && x + hSpacing + size.width > maxW {
                y += lineH + vSpacing
                x = 0
                lineH = 0
            }
            x += (x > 0 ? hSpacing : 0) + size.width
            lineH = max(lineH, size.height)
            widest = max(widest, x)
        }
        return CGSize(width: widest, height: y + lineH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineH: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += lineH + vSpacing
                x = bounds.minX
                lineH = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + hSpacing
            lineH = max(lineH, size.height)
        }
    }
}

struct LegendItem: Identifiable {
    let id: String
    let title: String
    let amount: Double
    let annual: Bool
}

enum MonthLegend {
    static let swatch: CGFloat = 10
    static let textGap: CGFloat = 6
    static let itemGap: CGFloat = Space.s2
    static let lines = 2
    /// One line of 13 pt text.
    static let rowHeight: CGFloat = 16

    /// Height of `rows` lines with the gap between them.
    static func height(rows: Int) -> CGFloat {
        rows <= 0 ? 0 : CGFloat(rows) * rowHeight + CGFloat(rows - 1) * Space.s1
    }

    /// How many lines these items take at this width (same measure that picked them).
    static func rows(of items: [LegendItem], width: CGFloat, locale: Locale) -> Int {
        items.isEmpty ? 0 : lineCount(items, width: max(0, width - 4), locale: locale)
    }

    private static func textWidth(_ s: String, weight: UIFont.Weight) -> CGFloat {
        ceil((s as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 13, weight: weight)]).width)
    }

    private static func itemWidth(_ it: LegendItem, locale: Locale) -> CGFloat {
        swatch + textGap + textWidth(it.title, weight: .regular) + textGap
            + textWidth(it.amount.money(locale), weight: .semibold) + 2
    }

    private static func lineCount(_ items: [LegendItem], width: CGFloat, locale: Locale) -> Int {
        var lines = 1
        var x: CGFloat = 0
        for it in items {
            let w = itemWidth(it, locale: locale)
            if x == 0 {
                x = w
            } else if x + itemGap + w <= width {
                x += itemGap + w
            } else {
                lines += 1
                x = w
            }
        }
        return lines
    }

    /// The biggest categories that fit on two lines, then "Altre voci" with the total of the rest,
    /// so what is listed always adds up to the number shown above the bars.
    static func items(for bucket: MonthBucket, language: String, locale: Locale, width: CGFloat) -> [LegendItem] {
        let sorted = bucket.parts
            .filter { $0.amount > 0.004 }
            .sorted { $0.amount > $1.amount }
            .map { LegendItem(id: $0.id, title: Loc.tr($0.title, language), amount: $0.amount, annual: $0.annual) }
        guard !sorted.isEmpty else { return [] }
        let room = max(0, width - 4)
        var k = sorted.count
        while k >= 0 {
            var candidate = Array(sorted.prefix(k))
            if k < sorted.count {
                let rest = sorted.suffix(sorted.count - k)
                candidate.append(LegendItem(
                    id: "rest",
                    title: Loc.tr("Altre voci", language),
                    amount: rest.reduce(0) { $0 + $1.amount },
                    annual: rest.allSatisfy { $0.annual }))
            }
            if lineCount(candidate, width: room, locale: locale) <= lines { return candidate }
            k -= 1
        }
        return []
    }
}

/// Small breakdown shown while a month bar is held. The caller works out the items and the height.
struct MonthLegendView: View {
    @Environment(\.appAccent) private var accent
    @Environment(\.locale) private var locale
    let items: [LegendItem]

    var body: some View {
        FlowLayout(hSpacing: MonthLegend.itemGap, vSpacing: Space.s1) {
            ForEach(items) { it in
                HStack(spacing: MonthLegend.textGap) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(it.annual ? accent : Theme.ink)
                        .frame(width: MonthLegend.swatch, height: MonthLegend.swatch)
                    Text(verbatim: it.title)
                        .font(AppFont.sans(13)).foregroundStyle(Theme.muted)
                    Text(verbatim: it.amount.money(locale))
                        .font(AppFont.sans(13, .semibold)).foregroundStyle(Theme.ink)
                }
                .fixedSize()
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
