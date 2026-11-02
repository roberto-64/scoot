import SwiftUI
import SwiftData

/// Set up or renew one deadline (RCA, Bollo or Revisione) for a vehicle.
/// The due date is calculated from the rules in HANDOFF.md and can be edited.
struct DeadlineSheet: View {
    let vehicle: Vehicle

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale

    @State private var kind: DeadlineKind
    @State private var start = Date()
    @State private var months = 12
    @State private var amountText = ""
    @State private var due = Date()
    @State private var alertsOn = true
    @State private var addCost = true
    @State private var markPaid = false
    @State private var expiryMonth = 1
    @State private var hasLast = false
    @State private var lastDate = Date()
    @State private var loaded = false

    init(vehicle: Vehicle, kind: DeadlineKind) {
        self.vehicle = vehicle
        _kind = State(initialValue: kind)
    }

    private var existing: Deadline? {
        vehicle.deadlines.first { $0.kindRaw == kind.rawValue }
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s2) {
                header
                Segmented(options: [
                    SegmentOption(value: DeadlineKind.rca, label: "RCA"),
                    SegmentOption(value: DeadlineKind.bollo, label: "Bollo"),
                    SegmentOption(value: DeadlineKind.revisione, label: "Revisione")
                ], selection: $kind)

                switch kind {
                case .rca: rcaFields
                case .bollo: bolloFields
                case .revisione: revisioneFields
                }

                Toggle(isOn: $alertsOn) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Avvisi").font(AppFont.sans(17)).foregroundStyle(Theme.ink)
                        Text(LocalizedStringKey(kind == .revisione
                                                ? "60, 30, 7 e 1 giorno prima, alle 9:00"
                                                : "30, 7 e 1 giorno prima, alle 9:00"))
                            .font(AppFont.sans(13)).foregroundStyle(Theme.muted)
                    }
                }
                .toggleStyle(AccentToggleStyle())
                .padding(.top, Space.s1)
            }
            .padding(.horizontal, Space.s2)
            .padding(.top, Space.s2)
            .padding(.bottom, Space.s3)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Salva scadenza") { save() }
                .padding(.horizontal, Space.s2)
                .padding(.bottom, Space.s1)
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            load()
        }
        .onChange(of: kind) { _, _ in load() }
        .onChange(of: start) { _, _ in if kind == .rca { due = rcaDue } }
        .onChange(of: months) { _, _ in if kind == .rca { due = rcaDue } }
        .onChange(of: expiryMonth) { _, m in if kind == .bollo { due = bolloDue(forMonth: m) } }
        .onChange(of: hasLast) { _, _ in if kind == .revisione, let c = revisioneCalc { due = c } }
        .onChange(of: lastDate) { _, _ in if kind == .revisione, hasLast, let c = revisioneCalc { due = c } }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Imposta scadenza").eyebrow()
                Text(LocalizedStringKey(kind.title))
                    .font(AppFont.serif(28))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            Button { dismiss() } label: { IconSquare(systemName: "xmark") }
                .buttonStyle(PressStyle())
        }
    }

    // MARK: Fields per kind

    private var rcaFields: some View {
        VStack(alignment: .leading, spacing: 0) {
            row("Data di inizio") {
                DatePicker("", selection: $start, displayedComponents: .date).labelsHidden()
            }
            row("Durata") {
                Segmented(options: [
                    SegmentOption(value: 6, label: "6 mesi"),
                    SegmentOption(value: 12, label: "12 mesi")
                ], selection: $months)
                .frame(width: 160)
            }
            amountRow
            calcCard(label: "Scade il",
                     note: "I 15 giorni di tolleranza valgono solo per le polizze annuali. L’app ti avvisa prima, non contarci.")
                .padding(.top, Space.s2)
            Toggle(isOn: $addCost) {
                Text("Aggiungi il costo allo storico").font(AppFont.sans(17)).foregroundStyle(Theme.ink)
            }
            .toggleStyle(AccentToggleStyle())
            .padding(.top, Space.s2)
        }
    }

    private var bolloFields: some View {
        VStack(alignment: .leading, spacing: 0) {
            row("Mese di scadenza") {
                Picker("", selection: $expiryMonth) {
                    ForEach(1...12, id: \.self) { m in
                        Text(verbatim: monthName(m)).tag(m)
                    }
                }
                .labelsHidden()
                .tint(Theme.ink)
            }
            amountRow
            calcCard(label: "Da pagare entro",
                     note: "Si paga entro la fine del mese dopo la scadenza. L’importo cambia da regione a regione. Conserva la ricevuta per 5 anni.")
                .padding(.top, Space.s2)
            row("Data di scadenza") {
                DatePicker("", selection: $due, displayedComponents: .date).labelsHidden()
            }
            Toggle(isOn: $markPaid) {
                Text("Segna come pagato").font(AppFont.sans(17)).foregroundStyle(Theme.ink)
            }
            .toggleStyle(AccentToggleStyle())
            .padding(.top, Space.s2)
            Toggle(isOn: $addCost) {
                Text("Aggiungi il costo allo storico").font(AppFont.sans(17)).foregroundStyle(Theme.ink)
            }
            .toggleStyle(AccentToggleStyle())
            .padding(.top, Space.s2)
        }
    }

    private var revisioneFields: some View {
        VStack(alignment: .leading, spacing: 0) {
            row("Prima immatricolazione") {
                if let reg = vehicle.firstRegistration {
                    Text(verbatim: reg.monthShortYear(locale))
                        .font(AppFont.sans(17)).foregroundStyle(Theme.ink).monospacedDigit()
                } else {
                    Text("Non impostata").font(AppFont.sans(13)).foregroundStyle(Theme.muted)
                }
            }
            Toggle(isOn: $hasLast) {
                Text("Ultima revisione fatta").font(AppFont.sans(17)).foregroundStyle(Theme.ink)
            }
            .toggleStyle(AccentToggleStyle())
            .padding(.vertical, Space.s1)
            if hasLast {
                row("Data") {
                    DatePicker("", selection: $lastDate, displayedComponents: .date).labelsHidden()
                }
            }
            calcCard(label: "Scadenza calcolata",
                     note: "Prima revisione dopo 4 anni dall’immatricolazione, poi ogni 2. Puoi modificare la data.")
                .padding(.top, Space.s2)
            row("Data di scadenza") {
                DatePicker("", selection: $due, displayedComponents: .date).labelsHidden()
            }
            row("Costo (facoltativo)") { amountField }
        }
    }

    // MARK: Pieces

    private func row<V: View>(_ label: LocalizedStringKey, @ViewBuilder _ value: () -> V) -> some View {
        HStack {
            Text(label).font(AppFont.sans(17)).foregroundStyle(Theme.ink)
            Spacer(minLength: Space.s2)
            value()
        }
        .padding(.vertical, Space.s1)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var amountRow: some View {
        row("Importo") { amountField }
    }

    private var amountField: some View {
        HStack(spacing: Space.s1) {
            TextField("", text: $amountText,
                      prompt: Text(verbatim: "0,00").foregroundColor(Theme.muted.opacity(0.5)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(AppFont.sans(17))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .frame(width: 96)
            Text(verbatim: "€").font(AppFont.sans(15)).foregroundStyle(Theme.muted)
        }
    }

    private func calcCard(label: LocalizedStringKey, note: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Text(label).eyebrow()
            Text(verbatim: due.short(locale))
                .font(AppFont.serif(32))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
            Text(note).eyebrow()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func monthName(_ m: Int) -> String {
        var c = Calendar.current
        c.locale = locale
        return c.monthSymbols[max(0, min(11, m - 1))]
    }

    // MARK: Calculation

    private var rcaDue: Date {
        start.addingMonths(months).addingDays(-1)
    }

    /// Bollo: due by the end of the month after the expiry month.
    /// Picks the first such date that is today or later.
    private func bolloDue(forMonth m: Int) -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let year = cal.component(.year, from: today)
        for y in [year - 1, year, year + 1] {
            if let first = cal.date(from: DateComponents(year: y, month: m, day: 1)) {
                let candidate = first.addingMonths(1).endOfMonth
                if candidate >= today { return candidate }
            }
        }
        return today
    }

    /// Revisione: 4 years after first registration, then every 2 years, at the end of the month.
    private var revisioneCalc: Date? {
        if hasLast { return lastDate.addingMonths(24).endOfMonth }
        if let reg = vehicle.firstRegistration { return reg.addingMonths(48).endOfMonth }
        return nil
    }

    // MARK: Load and save

    private func load() {
        let d = existing
        alertsOn = d?.alertsOn ?? true
        if let a = d?.amount, a > 0 { amountText = a.decimal(2, locale) } else { amountText = "" }
        addCost = (d == nil)
        markPaid = false
        hasLast = false
        lastDate = Date()
        let cal = Calendar.current
        switch kind {
        case .rca:
            start = d?.startDate ?? Date()
            months = (d?.durationMonths == 6) ? 6 : 12
            due = d?.dueDate ?? rcaDue
        case .bollo:
            if let d {
                due = d.dueDate
                let dueMonth = cal.component(.month, from: d.dueDate)
                expiryMonth = ((dueMonth - 2 + 12) % 12) + 1
            } else {
                expiryMonth = vehicle.firstRegistration.map { cal.component(.month, from: $0) }
                    ?? cal.component(.month, from: Date())
                due = bolloDue(forMonth: expiryMonth)
            }
        case .revisione:
            due = d?.dueDate ?? revisioneCalc ?? Date().addingMonths(12).endOfMonth
        }
    }

    private func save() {
        let amount = parseDecimal(amountText) ?? 0
        let cal = Calendar.current
        var newDue = due
        let previous = existing?.dueDate

        // "Segna come pagato" moves Bollo to the next year.
        if kind == .bollo && markPaid {
            newDue = due.addingMonths(12).endOfMonth
        }

        let d: Deadline
        if let e = existing {
            d = e
        } else {
            d = Deadline(kind: kind, dueDate: newDue)
            context.insert(d)
            d.vehicle = vehicle
        }

        // Renewal: the old due date goes into the history.
        let oldDate = (kind == .bollo && markPaid) ? due : previous
        if let old = oldDate, newDue > old,
           !d.renewals.contains(where: { cal.isDate($0, inSameDayAs: old) }) {
            d.renewals.append(old)
        }

        d.dueDate = newDue
        d.amount = amount
        d.alertsOn = alertsOn
        switch kind {
        case .rca:
            d.startDate = start
            d.durationMonths = months
        case .bollo:
            d.startDate = nil
            d.durationMonths = 12
        case .revisione:
            d.startDate = nil
            d.durationMonths = 24
        }

        // Optional cost in the spending history.
        if amount > 0 {
            switch kind {
            case .rca where addCost:
                record(amount, .rca, date: start, cover: months)
            case .bollo where addCost && markPaid:
                record(amount, .bollo, date: Date(), cover: 12)
            case .revisione where hasLast:
                record(amount, .revisione, date: lastDate, cover: 1)
            default:
                break
            }
        }

        try? context.save()
        Haptics.success()
        DataSignal.fire()
        dismiss()
    }

    private func record(_ amount: Double, _ category: ExpenseCategory, date: Date, cover: Int) {
        let e = ExpenseEntry(date: date, odometer: vehicle.currentOdometer, category: category,
                             title: "", amount: amount, coverMonths: cover)
        context.insert(e)
        e.vehicle = vehicle
    }
}
