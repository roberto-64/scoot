import SwiftUI
import SwiftData

struct MonthGroup: Identifiable {
    let id: Date
    let entries: [HistoryEntry]
    var total: Double { entries.reduce(0) { $0 + $1.amount } }
}

/// Searchable history: search field, filter chips, then either the search results or the
/// entries grouped by month. Used on a vehicle page and on the Home "Attività" page.
struct HistoryList: View {
    let vehicles: [Vehicle]
    var showVehicle: Bool = false

    @Environment(\.locale) private var locale
    @AppStorage("language") private var language = "it"
    @State private var query = ""
    @State private var filter: HistoryFilter = .all

    private var all: [HistoryEntry] {
        vehicles.flatMap { HistoryEntry.all($0) }.sorted { $0.date > $1.date }
    }
    private var tokens: [String] { HistorySearch.tokens(query) }
    private var searching: Bool { !tokens.isEmpty || filter != .all }

    /// What the search and the chips let through, newest first.
    private func results(_ source: [HistoryEntry]) -> [HistoryEntry] {
        source.filter {
            filter.allows($0) && HistorySearch.matches($0, tokens: tokens, language: language, locale: locale)
        }
    }

    private func groups(_ source: [HistoryEntry]) -> [MonthGroup] {
        let dict = Dictionary(grouping: source) { $0.date.startOfMonth }
        return dict.keys.sorted(by: >).map { MonthGroup(id: $0, entries: dict[$0] ?? []) }
    }

    var body: some View {
        let source = all
        let months = groups(source)
        VStack(alignment: .leading, spacing: 0) {
            if !source.isEmpty {
                HistorySearchField(text: $query).padding(.top, Space.s2)
                HistoryFilterChips(filter: $filter).padding(.top, Space.s1)
            }
            if searching {
                let found = results(source)
                HStack {
                    Group {
                        if found.count == 1 { Text("1 risultato") } else { Text("\(found.count) risultati") }
                    }
                    .eyebrow()
                    Spacer()
                    Text(found.reduce(0) { $0 + $1.amount }.money(locale)).monospacedDigit().eyebrow()
                }
                .padding(.top, Space.s3)
                if found.isEmpty {
                    Text("Nessun risultato.").font(AppFont.sans(15)).foregroundStyle(Theme.muted).padding(.top, Space.s2)
                }
                ForEach(Array(found.enumerated()), id: \.element.id) { i, e in
                    HistoryRow(entry: e, showVehicle: showVehicle, previousID: i > 0 ? found[i - 1].id : nil, highlight: tokens).rowTransition()
                }
            } else {
                if months.isEmpty {
                    Text("Nessuna registrazione.").font(AppFont.sans(15)).foregroundStyle(Theme.muted).padding(.top, Space.s2)
                }
                ForEach(months) { g in
                    HStack {
                        Text(verbatim: g.id.monthYear(locale)).font(AppFont.sans(15, .semibold)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text(g.total.money(locale)).font(AppFont.sans(13)).foregroundStyle(Theme.muted)
                    }
                    .padding(.top, Space.s3)
                    ForEach(Array(g.entries.enumerated()), id: \.element.id) { i, e in
                        HistoryRow(entry: e, showVehicle: showVehicle, previousID: i > 0 ? g.entries[i - 1].id : nil).rowTransition()
                    }
                }
            }
        }
        .animation(Motion.bounce, value: months.flatMap { $0.entries.map { $0.id } })
    }
}

/// Home > "Attività recente": the whole history of every vehicle, grouped by month and searchable.
struct ActivityView: View {
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BackHeader(title: "Attività")
                HistoryList(vehicles: vehicles, showVehicle: vehicles.count > 1)
            }
            .padding(.horizontal, Space.s2)
            .padding(.top, Space.s2)
            .padding(.bottom, Space.s4)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: Space.s8 + Space.s2) }
        .screenBackground(glow: true)
        .toolbar(.hidden, for: .navigationBar)
    }
}
