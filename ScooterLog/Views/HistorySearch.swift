import SwiftUI

/// The filter chips above the history.
enum HistoryFilter: String, CaseIterable, Identifiable {
    case all, fuel, maint, expense, km
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "Tutto"
        case .fuel: return "Rifornimenti"
        case .maint: return "Manutenzione"
        case .expense: return "Spese"
        case .km: return "Km"
        }
    }

    func allows(_ e: HistoryEntry) -> Bool {
        switch (self, e) {
        case (.all, _): return true
        case (.fuel, .fuel), (.maint, .maint), (.expense, .expense), (.km, .reading): return true
        default: return false
        }
    }
}

enum HistorySearch {
    /// Words typed in the box, without accents or capitals. Every word has to be found.
    static func tokens(_ query: String) -> [String] {
        query.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
    }

    /// Everything a person might type to find this entry: what it is, workshop, notes, jobs, the date
    /// as it is written on screen, the amount and the kilometres.
    static func haystack(_ e: HistoryEntry, language: String, locale: Locale) -> String {
        var f: [String] = []
        func add(_ s: String) { if !s.isEmpty { f.append(s) } }
        func addMoney(_ x: Double) {
            add(x.money(locale))
            add(x.decimal(2, locale))
            add(x.plain(locale, maxDigits: 2))
        }
        func addKm(_ km: Int) {
            guard km > 0 else { return }
            add(km.grouped(locale))
            add(String(km))
        }
        func addDate(_ d: Date) {
            add(d.short(locale))
            add(d.monthYear(locale))
            add(d.formatted(.dateTime.weekday(.wide).locale(locale)))
        }
        switch e {
        case .fuel(let x):
            add(Loc.tr("Rifornimento", language))
            add(Loc.tr(FuelKind(rawValue: x.vehicle?.fuelKey ?? "")?.title ?? "", language))
            add(x.liters.decimal(2, locale) + " L")
            add(x.pricePerLiter.decimal(3, locale))
            addMoney(x.total); addKm(x.odometer); addDate(x.date)
        case .maint(let x):
            add(Loc.tr("Manutenzione", language))
            for j in x.jobs {
                add(Catalog.displayName(jobKey: j.jobKey, custom: j.customName, lang: language))
                add(Catalog.category(j.categoryKey)?.name(language) ?? "")
            }
            add(x.workshop); add(x.note)
            addMoney(x.total); addKm(x.odometer); addDate(x.date)
        case .expense(let x):
            add(Loc.tr(x.category.title, language))
            add(x.title)
            addMoney(x.amount); addKm(x.odometer); addDate(x.date)
        case .reading(let x):
            add(Loc.tr("Contachilometri", language))
            addKm(x.odometer); addDate(x.date)
        }
        return f.joined(separator: " | ")
    }

    static func matches(_ e: HistoryEntry, tokens: [String], language: String, locale: Locale) -> Bool {
        guard !tokens.isEmpty else { return true }
        let h = haystack(e, language: language, locale: locale)
        return tokens.allSatisfy { h.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    /// The same text with the typed words marked.
    static func highlighted(_ text: String, tokens: [String], tint: Color) -> AttributedString {
        var a = AttributedString(text)
        for t in tokens {
            var from = text.startIndex
            while from < text.endIndex,
                  let r = text.range(of: t, options: [.caseInsensitive, .diacriticInsensitive], range: from..<text.endIndex) {
                if let lo = AttributedString.Index(r.lowerBound, within: a),
                   let hi = AttributedString.Index(r.upperBound, within: a) {
                    a[lo..<hi].backgroundColor = tint.opacity(0.22)
                    a[lo..<hi].foregroundColor = Theme.ink
                }
                from = r.upperBound
            }
        }
        return a
    }
}

/// Search box with a clear button.
struct HistorySearchField: View {
    @Binding var text: String
    var body: some View {
        HStack(spacing: Space.s1) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.muted)
            TextField("Cerca nello storico", text: $text)
                .font(AppFont.sans(17))
                .foregroundStyle(Theme.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.muted)
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel(Text("Cancella"))
            }
        }
        .padding(.horizontal, Space.s2)
        .frame(height: Space.s6)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.base, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.base, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .cardShadow()
    }
}

struct HistoryFilterChips: View {
    @Environment(\.appAccent) private var accent
    @Binding var filter: HistoryFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s1) {
                ForEach(HistoryFilter.allCases) { f in
                    let on = filter == f
                    Button {
                        Haptics.tick()
                        withAnimation(Motion.snap) { filter = f }
                    } label: {
                        Text(LocalizedStringKey(f.title))
                            .font(AppFont.sans(15, .semibold))
                            .foregroundStyle(on ? Theme.surface : Theme.muted)
                            .padding(.horizontal, Space.s2)
                            .frame(height: Space.s5)
                            .background(on ? accent : Theme.surface,
                                        in: RoundedRectangle(cornerRadius: Radius.base, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.base, style: .continuous)
                                .stroke(on ? accent : Theme.line, lineWidth: 1))
                    }
                    .buttonStyle(PressStyle())
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }
}
