import SwiftUI
import SwiftData

struct DateRow: View {
    let label: LocalizedStringKey
    @Binding var date: Date
    var body: some View {
        HStack {
            Text(label).font(AppFont.sans(17)).foregroundStyle(Theme.ink)
            Spacer()
            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute]).labelsHidden()
        }
        .padding(.vertical, Space.s1)
        .overlay(alignment: .top) { Hairline() }
        .overlay(alignment: .bottom) { Hairline() }
    }
}

/// Shared frame of every entry form. When `onDelete` is set (editing an existing entry)
/// a "Delete" button appears at the bottom and asks for confirmation.
struct FormScaffold<Content: View>: View {
    let title: LocalizedStringKey
    var eyebrow: LocalizedStringKey? = nil
    let saveTitle: LocalizedStringKey
    let canSave: Bool
    var modal: Bool = false
    var onDelete: (() -> Void)? = nil
    let onSave: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s3) {
                BackHeader(title: title, eyebrow: eyebrow, modal: modal)
                content()
                if onDelete != nil {
                    Button { confirmDelete = true } label: {
                        HStack(spacing: Space.s1) {
                            Image(systemName: "trash")
                            Text("Elimina registrazione")
                        }
                        .font(AppFont.sans(15, .semibold))
                        .foregroundStyle(Theme.ink)
                    }
                    .buttonStyle(PressStyle())
                }
            }
            .padding(.horizontal, Space.s2)
            .padding(.top, Space.s2)
            .padding(.bottom, Space.s3)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: saveTitle, enabled: canSave, action: onSave)
                .padding(.horizontal, Space.s2)
                .padding(.bottom, Space.s1)
        }
        .confirmationDialog("Eliminare questa registrazione?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Elimina registrazione", role: .destructive) { onDelete?() }
            Button("Annulla", role: .cancel) {}
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Edit sheet (opens when an entry in a list is tapped)

struct EntryEditSheet: View {
    let entry: HistoryEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        switch entry {
        case .fuel(let e):
            if let v = e.vehicle { FuelFormView(vehicle: v, editing: e, onSaved: { dismiss() }) }
        case .maint(let e):
            if let v = e.vehicle { MaintenanceEntryView(vehicle: v, editing: e, onSaved: { dismiss() }) }
        case .expense(let e):
            if let v = e.vehicle { ExpenseFormView(vehicle: v, editing: e, onSaved: { dismiss() }) }
        case .reading(let e):
            if let v = e.vehicle { OdometerFormView(vehicle: v, editing: e, onSaved: { dismiss() }) }
        }
    }
}

// MARK: - Fill-up

struct FuelFormView: View {
    let vehicle: Vehicle
    var editing: FuelEntry? = nil
    var onSaved: () -> Void = {}
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @State private var litersText = ""
    @State private var priceText = ""
    @State private var odoText = ""
    @State private var date = Date()
    @State private var prefilled = false

    private var liters: Double { parseDecimal(litersText) ?? 0 }
    private var price: Double { parseDecimal(priceText) ?? 0 }
    private var odo: Int { parseInt(odoText) }
    private var total: Double { liters * price }
    private var lastOdo: Int { vehicle.currentOdometer }
    private var odoTooLow: Bool { editing == nil && odo > 0 && odo < lastOdo }
    private var overTank: Bool { vehicle.tankLiters > 0 && liters > vehicle.tankLiters * 1.05 }
    private var canSave: Bool { liters > 0 && price > 0 && odo > 0 }

    var body: some View {
        FormScaffold(title: "Rifornimento", saveTitle: editing == nil ? "Salva registrazione" : "Salva modifiche",
                     canSave: canSave, modal: editing != nil,
                     onDelete: deleteAction, onSave: save) {
            HStack(alignment: .top, spacing: Space.s3) {
                LineField(label: "Quantità", text: $litersText, unit: "L")
                LineField(label: "Prezzo per L", text: $priceText, unit: "€")
            }
            if overTank {
                Text("Più litri della capienza del serbatoio: controlla il valore.")
                    .font(AppFont.sans(13)).foregroundStyle(Theme.ink)
            }
            VStack(alignment: .leading, spacing: Space.s1) {
                Text("Costo calcolato").eyebrow()
                HStack(alignment: .firstTextBaseline, spacing: Space.s1) {
                    Text(total.decimal(2, locale))
                        .font(AppFont.serif(56))
                        .foregroundStyle(total > 0 ? Theme.ink : Theme.muted.opacity(0.5))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(verbatim: "€").font(AppFont.serif(32)).foregroundStyle(Theme.muted)
                }
                .animation(Motion.spring, value: total)
            }
            VStack(alignment: .leading, spacing: Space.s1) {
                LineField(label: "Contachilometri", text: $odoText, unit: "km", keyboard: .numberPad, size: 40)
                if odoTooLow {
                    Text("Il valore è inferiore all’ultima lettura.").font(AppFont.sans(13, .semibold)).foregroundStyle(Theme.ink)
                } else if editing == nil {
                    Text("Ultima lettura: \(lastOdo.grouped(locale)) km").eyebrow()
                }
            }
            Text("Una voce per sosta: somma tutti i litri, anche dopo i ritocchi.").eyebrow()
            DateRow(label: "Data", date: $date)
        }
        .onAppear {
            guard !prefilled else { return }
            prefilled = true
            if let e = editing {
                litersText = e.liters.plain(locale)
                priceText = e.pricePerLiter.plain(locale)
                odoText = String(e.odometer)
                date = e.date
                return
            }
            odoText = String(vehicle.currentOdometer)
            if let last = vehicle.fuelEntries.sorted(by: { $0.date > $1.date }).first {
                priceText = last.pricePerLiter.decimal(3, locale)
            }
        }
        .onChange(of: odoTooLow) { _, bad in if bad { Haptics.warning() } }
    }

    private func save() {
        guard canSave else { return }
        if let e = editing {
            e.date = date
            e.odometer = odo
            e.liters = liters
            e.pricePerLiter = price
        } else {
            let e = FuelEntry(date: date, odometer: odo, liters: liters, pricePerLiter: price)
            context.insert(e)
            e.vehicle = vehicle
        }
        try? context.save()
        Haptics.success()
        DataSignal.fire()
        onSaved()
    }

    private var deleteAction: (() -> Void)? {
        guard editing != nil else { return nil }
        return { deleteEntry() }
    }

    /// Closes the sheet first, then removes the entry so the row is seen leaving the list.
    private func deleteEntry() {
        guard let e = editing else { return }
        onSaved()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(Motion.bounce) {
                context.delete(e)
                try? context.save()
            }
            DataSignal.fire()
        }
    }
}

// MARK: - Expense

struct ExpenseFormView: View {
    let vehicle: Vehicle
    var editing: ExpenseEntry? = nil
    var onSaved: () -> Void = {}
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @State private var category: ExpenseCategory = .parking
    @State private var title = ""
    @State private var amountText = ""
    @State private var odoText = ""
    @State private var date = Date()
    @State private var prefilled = false

    private var amount: Double { parseDecimal(amountText) ?? 0 }
    private var canSave: Bool { amount > 0 }

    var body: some View {
        FormScaffold(title: "Spesa", saveTitle: editing == nil ? "Salva registrazione" : "Salva modifiche",
                     canSave: canSave, modal: editing != nil,
                     onDelete: deleteAction, onSave: save) {
            VStack(alignment: .leading, spacing: Space.s1) {
                Text("Categoria").eyebrow()
                HStack(spacing: Space.s1) {
                    ForEach(ExpenseCategory.manual) { c in
                        Button { category = c; Haptics.tick() } label: {
                            Text(LocalizedStringKey(c.title))
                                .font(AppFont.sans(15, .semibold))
                                .foregroundStyle(category == c ? Theme.surface : Theme.muted)
                                .padding(.horizontal, Space.s2)
                                .frame(height: Space.s5)
                                .background(category == c ? Theme.ink : Theme.surface,
                                            in: RoundedRectangle(cornerRadius: Radius.base, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: Radius.base, style: .continuous).stroke(Theme.line, lineWidth: 1))
                        }
                        .buttonStyle(PressStyle())
                    }
                }
            }
            LineField(label: "Importo", text: $amountText, unit: "€", size: 40)
            LineField(label: "Descrizione", text: $title, keyboard: .default, size: 22, placeholder: "Facoltativo")
            LineField(label: "Contachilometri", text: $odoText, unit: "km", keyboard: .numberPad, size: 22, placeholder: "Facoltativo")
            DateRow(label: "Data", date: $date)
        }
        .onAppear {
            guard !prefilled else { return }
            prefilled = true
            if let e = editing {
                category = e.category
                title = e.title
                amountText = e.amount.plain(locale, maxDigits: 2)
                odoText = e.odometer > 0 ? String(e.odometer) : ""
                date = e.date
            }
        }
    }

    private func save() {
        guard canSave else { return }
        if let e = editing {
            e.date = date
            e.odometer = parseInt(odoText)
            e.categoryRaw = category.rawValue
            e.title = title.trimmingCharacters(in: .whitespaces)
            e.amount = amount
        } else {
            let e = ExpenseEntry(date: date, odometer: parseInt(odoText), category: category,
                                 title: title.trimmingCharacters(in: .whitespaces), amount: amount, coverMonths: 1)
            context.insert(e)
            e.vehicle = vehicle
        }
        try? context.save()
        Haptics.success()
        DataSignal.fire()
        onSaved()
    }

    private var deleteAction: (() -> Void)? {
        guard editing != nil else { return nil }
        return { deleteEntry() }
    }

    /// Closes the sheet first, then removes the entry so the row is seen leaving the list.
    private func deleteEntry() {
        guard let e = editing else { return }
        onSaved()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(Motion.bounce) {
                context.delete(e)
                try? context.save()
            }
            DataSignal.fire()
        }
    }
}

// MARK: - Odometer update

struct OdometerFormView: View {
    let vehicle: Vehicle
    var editing: OdometerReading? = nil
    var onSaved: () -> Void = {}
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @State private var odoText = ""
    @State private var date = Date()
    @State private var prefilled = false

    private var odo: Int { parseInt(odoText) }
    private var tooLow: Bool { editing == nil && odo > 0 && odo < vehicle.currentOdometer }
    private var canSave: Bool { odo > 0 }

    var body: some View {
        FormScaffold(title: "Aggiorna contachilometri", saveTitle: editing == nil ? "Salva registrazione" : "Salva modifiche",
                     canSave: canSave, modal: editing != nil,
                     onDelete: deleteAction, onSave: save) {
            VStack(alignment: .leading, spacing: Space.s1) {
                LineField(label: "Contachilometri", text: $odoText, unit: "km", keyboard: .numberPad, size: 56)
                if tooLow {
                    Text("Il valore è inferiore all’ultima lettura.").font(AppFont.sans(13, .semibold)).foregroundStyle(Theme.ink)
                } else if editing == nil {
                    Text("Ultima lettura: \(vehicle.currentOdometer.grouped(locale)) km").eyebrow()
                }
            }
            DateRow(label: "Data", date: $date)
        }
        .onAppear {
            guard !prefilled else { return }
            prefilled = true
            if let e = editing {
                odoText = String(e.odometer)
                date = e.date
                return
            }
            odoText = String(vehicle.currentOdometer)
        }
        .onChange(of: tooLow) { _, bad in if bad { Haptics.warning() } }
    }

    private func save() {
        guard canSave else { return }
        if let e = editing {
            e.date = date
            e.odometer = odo
        } else {
            let r = OdometerReading(date: date, odometer: odo)
            context.insert(r)
            r.vehicle = vehicle
        }
        try? context.save()
        Haptics.success()
        DataSignal.fire()
        onSaved()
    }

    private var deleteAction: (() -> Void)? {
        guard editing != nil else { return nil }
        return { deleteEntry() }
    }

    /// Closes the sheet first, then removes the entry so the row is seen leaving the list.
    private func deleteEntry() {
        guard let e = editing else { return }
        onSaved()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(Motion.bounce) {
                context.delete(e)
                try? context.save()
            }
            DataSignal.fire()
        }
    }
}
