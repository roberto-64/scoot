import SwiftUI
import SwiftData

enum RuleMode: Hashable { case km, months, both, never }

struct PickedJob {
    let def: JobDef?
    let custom: String
}

struct DraftJob: Identifiable {
    let id = UUID()
    var jobKey: String
    var customName: String
    var categoryKey: String
    var priceText: String = ""
    var qtyText: String = "1"
    var mode: RuleMode = .never
    var kmText: String = ""
    var monthsText: String = ""
    var source: RuleSource = .none
    var expanded: Bool = true

    init(picked: PickedJob) {
        if let def = picked.def {
            jobKey = def.id
            customName = ""
            categoryKey = def.category
            source = def.source
            if def.km > 0 && def.months > 0 { mode = .both }
            else if def.km > 0 { mode = .km }
            else if def.months > 0 { mode = .months }
            else { mode = .never }
            kmText = def.km > 0 ? String(def.km) : ""
            monthsText = def.months > 0 ? String(def.months) : ""
        } else {
            jobKey = ""
            customName = picked.custom
            categoryKey = "custom"
        }
    }

    /// Rebuilds a draft from a saved job, for editing an entry.
    init(job: MaintenanceJob) {
        jobKey = job.jobKey
        customName = job.customName
        categoryKey = job.categoryKey
        priceText = job.unitPrice == 0 ? "" : job.unitPrice.plain(Locale.current, maxDigits: 2)
        qtyText = job.quantity.plain(Locale.current, maxDigits: 2)
        if job.ruleKm > 0 && job.ruleMonths > 0 { mode = .both }
        else if job.ruleKm > 0 { mode = .km }
        else if job.ruleMonths > 0 { mode = .months }
        else { mode = .never }
        kmText = job.ruleKm > 0 ? String(job.ruleKm) : ""
        monthsText = job.ruleMonths > 0 ? String(job.ruleMonths) : ""
        source = Catalog.job(job.jobKey)?.source ?? RuleSource.none
        expanded = false
    }

    var ruleKm: Int { (mode == .km || mode == .both) ? parseInt(kmText) : 0 }
    var ruleMonths: Int { (mode == .months || mode == .both) ? parseInt(monthsText) : 0 }
    var total: Double { (parseDecimal(priceText) ?? 0) * (parseDecimal(qtyText) ?? 1) }
}

// MARK: - Entry form

struct MaintenanceEntryView: View {
    let vehicle: Vehicle
    var editing: MaintenanceEntry? = nil
    var onSaved: () -> Void = {}
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @AppStorage("language") private var language = "it"
    @State private var drafts: [DraftJob] = []
    @State private var showPicker = false
    @State private var replacing: UUID? = nil
    @State private var odoText = ""
    @State private var workshop = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var prefilled = false

    private var odo: Int { parseInt(odoText) }
    private var total: Double { drafts.reduce(0) { $0 + $1.total } }
    private var canSave: Bool { !drafts.isEmpty && odo > 0 }
    private var pastWorkshops: [String] {
        var seen: [String] = []
        for m in vehicle.maintenance.sorted(by: { $0.date > $1.date }) where !m.workshop.isEmpty {
            if !seen.contains(m.workshop) { seen.append(m.workshop) }
        }
        return Array(seen.prefix(3))
    }

    private var eyebrowKey: LocalizedStringKey? {
        editing == nil ? LocalizedStringKey("Nuova registrazione") : nil
    }

    var body: some View {
        FormScaffold(title: "Manutenzione", eyebrow: eyebrowKey,
                     saveTitle: editing == nil ? "Salva la manutenzione" : "Salva modifiche",
                     canSave: canSave, modal: editing != nil, onDelete: deleteAction, onSave: save) {
            Text("Interventi eseguiti").eyebrow()
            VStack(spacing: Space.s2) {
                ForEach($drafts) { $d in
                    JobCard(draft: $d, odo: odo, date: date, lang: language,
                            onChange: { replacing = d.id; showPicker = true },
                            onRemove: { let id = d.id; withAnimation(Motion.spring) { drafts.removeAll { $0.id == id } } })
                }
            }
            Button { replacing = nil; showPicker = true } label: {
                HStack(spacing: Space.s2) {
                    Image(systemName: "plus").font(.system(size: 17, weight: .semibold))
                    Text("Aggiungi intervento").font(AppFont.sans(17))
                    Spacer()
                    if total > 0 {
                        Text("Totale \(total.money(locale))").font(AppFont.sans(13, .semibold)).foregroundStyle(Theme.muted)
                    }
                }
                .foregroundStyle(Theme.ink)
                .padding(.vertical, Space.s1)
            }
            .buttonStyle(PressStyle())

            Text("Dettagli del registro").eyebrow().padding(.top, Space.s1)
            VStack(alignment: .leading, spacing: Space.s1) {
                LineField(label: "Contachilometri", text: $odoText, unit: "km", keyboard: .numberPad, size: 40)
                if editing == nil {
                    Text("Ultima lettura: \(vehicle.currentOdometer.grouped(locale)) km").eyebrow()
                }
            }
            VStack(alignment: .leading, spacing: Space.s1) {
                LineField(label: "Officina", text: $workshop, keyboard: .default, size: 22, placeholder: "Chi ha fatto il lavoro?")
                if !pastWorkshops.isEmpty {
                    HStack(spacing: Space.s1) {
                        ForEach(pastWorkshops, id: \.self) { w in
                            Button { workshop = w } label: {
                                Text(verbatim: w).font(AppFont.sans(13, .semibold)).foregroundStyle(Theme.ink)
                                    .padding(.horizontal, Space.s2).frame(height: Space.s5)
                                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.base, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: Radius.base, style: .continuous).stroke(Theme.line, lineWidth: 1))
                            }
                            .buttonStyle(PressStyle())
                        }
                    }
                }
            }
            DateRow(label: "Data", date: $date)
            LineField(label: "Note", text: $note, keyboard: .default, size: 17, placeholder: "Facoltative")
        }
        .onAppear {
            guard !prefilled else { return }
            prefilled = true
            if let e = editing {
                odoText = String(e.odometer)
                workshop = e.workshop
                note = e.note
                date = e.date
                drafts = e.jobs.map { DraftJob(job: $0) }
                return
            }
            odoText = String(vehicle.currentOdometer)
        }
        .sheet(isPresented: $showPicker) {
            MaintenancePicker(vehicle: vehicle, multi: replacing == nil) { picked in apply(picked) }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(Radius.base)
                .presentationBackground(Theme.bg)
        }
    }

    private func apply(_ picked: [PickedJob]) {
        if let r = replacing, let first = picked.first, let i = drafts.firstIndex(where: { $0.id == r }) {
            var n = DraftJob(picked: first)
            n.priceText = drafts[i].priceText
            n.qtyText = drafts[i].qtyText
            drafts[i] = n
        } else {
            for p in picked { drafts.append(DraftJob(picked: p)) }
        }
        replacing = nil
    }

    private func save() {
        guard canSave else { return }
        let entry: MaintenanceEntry
        if let e = editing {
            entry = e
            entry.date = date
            entry.odometer = odo
            entry.workshop = workshop.trimmingCharacters(in: .whitespaces)
            entry.note = note.trimmingCharacters(in: .whitespaces)
            for old in Array(entry.jobs) { context.delete(old) }
        } else {
            entry = MaintenanceEntry(date: date, odometer: odo,
                                     workshop: workshop.trimmingCharacters(in: .whitespaces),
                                     note: note.trimmingCharacters(in: .whitespaces))
            context.insert(entry)
            entry.vehicle = vehicle
        }
        for d in drafts {
            let job = MaintenanceJob(jobKey: d.jobKey, customName: d.customName, categoryKey: d.categoryKey,
                                     unitPrice: parseDecimal(d.priceText) ?? 0, quantity: parseDecimal(d.qtyText) ?? 1,
                                     ruleKm: d.ruleKm, ruleMonths: d.ruleMonths)
            context.insert(job)
            job.entry = entry
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

// MARK: - One job card

struct JobCard: View {
    @Environment(\.appAccent) private var accent
    @Environment(\.locale) private var locale
    @Binding var draft: DraftJob
    let odo: Int
    let date: Date
    let lang: String
    var onChange: () -> Void
    var onRemove: () -> Void
    @State private var confirmRemove = false

    private var name: String { Catalog.displayName(jobKey: draft.jobKey, custom: draft.customName, lang: lang) }
    private var categoryName: String {
        Catalog.category(draft.categoryKey)?.name(lang) ?? Loc.tr("Altro", lang)
    }
    private var symbol: String { Catalog.category(draft.categoryKey)?.symbol ?? "wrench.and.screwdriver" }

    private var preview: String {
        var parts: [String] = []
        if draft.ruleKm > 0 { parts.append("\((odo + draft.ruleKm).grouped(locale)) km") }
        if draft.ruleMonths > 0 { parts.append(date.addingMonths(draft.ruleMonths).short(locale)) }
        if parts.isEmpty { return "" }
        let joined = parts.joined(separator: " " + Loc.tr("o", lang) + " ")
        return Loc.tr("Prossima:", lang) + " " + joined + (parts.count > 1 ? Loc.tr(", quale arriva prima", lang) : "")
    }

    private var sourceTag: LocalizedStringKey? {
        switch draft.source {
        case .piaggio: return "Piaggio"
        case .verify: return "Da verificare"
        case .none: return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(Motion.spring) { draft.expanded.toggle() }
            } label: {
                HStack(spacing: Space.s2) {
                    Image(systemName: symbol).font(.system(size: 20)).foregroundStyle(accent).frame(width: Space.s3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: name).font(AppFont.serif(17)).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                        Text(verbatim: categoryName).font(AppFont.sans(13)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Image(systemName: draft.expanded ? "chevron.up" : "chevron.down").foregroundStyle(Theme.muted)
                }
                .padding(Space.s2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if draft.expanded {
                Hairline()
                VStack(alignment: .leading, spacing: Space.s3) {
                    HStack(alignment: .top, spacing: Space.s3) {
                        LineField(label: "Prezzo unitario", text: $draft.priceText, unit: "€", size: 28)
                        LineField(label: "Quantità", text: $draft.qtyText, size: 28, placeholder: "1")
                    }
                    VStack(alignment: .leading, spacing: Space.s1) {
                        HStack(spacing: Space.s1) {
                            Text("Prossima manutenzione").font(AppFont.sans(15, .semibold)).foregroundStyle(Theme.ink)
                            if let t = sourceTag {
                                Text(t).font(AppFont.sans(11, .semibold)).foregroundStyle(accent)
                                    .padding(.horizontal, Space.s1).frame(height: Space.s3)
                                    .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: Radius.base, style: .continuous))
                            }
                        }
                        Segmented(options: [SegmentOption(value: RuleMode.km, label: "Km"),
                                            SegmentOption(value: RuleMode.months, label: "Mesi"),
                                            SegmentOption(value: RuleMode.both, label: "Entrambi"),
                                            SegmentOption(value: RuleMode.never, label: "Mai")],
                                  selection: $draft.mode)
                        HStack(alignment: .top, spacing: Space.s3) {
                            if draft.mode == .km || draft.mode == .both {
                                LineField(label: "Ogni", text: $draft.kmText, unit: "km", keyboard: .numberPad, size: 22)
                            }
                            if draft.mode == .months || draft.mode == .both {
                                LineField(label: "Ogni", text: $draft.monthsText, unit: "mesi", keyboard: .numberPad, size: 22)
                            }
                        }
                        if !preview.isEmpty { Text(verbatim: preview).eyebrow() }
                    }
                    HStack(spacing: Space.s2) {
                        SecondaryButton(title: "Cambia intervento", systemImage: "arrow.left.arrow.right") { onChange() }
                        Button { confirmRemove = true } label: {
                            HStack(spacing: Space.s1) { Image(systemName: "trash"); Text("Rimuovi") }
                                .font(AppFont.sans(15, .semibold)).foregroundStyle(Theme.ink)
                        }
                        .buttonStyle(PressStyle())
                    }
                }
                .padding(Space.s2)
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.base, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.base, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .cardShadow()
        .confirmationDialog("Rimuovere questo intervento?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Rimuovi", role: .destructive) { onRemove() }
            Button("Annulla", role: .cancel) {}
        }
    }
}

// MARK: - Picker

struct MaintenancePicker: View {
    let vehicle: Vehicle
    var multi: Bool = true
    var onDone: ([PickedJob]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccent) private var accent
    @AppStorage("language") private var language = "it"
    @State private var query = ""
    @State private var showAll = false
    @State private var expanded: Set<String> = []
    @State private var picked: [String] = []
    @State private var customs: [String] = []
    @State private var askCustom = false
    @State private var customName = ""

    private var jobs: [JobDef] { Catalog.visibleJobs(for: vehicle, showAll: showAll) }
    private var count: Int { picked.count + customs.count }

    private var recents: [JobDef] {
        var ids: [String] = []
        for m in vehicle.maintenance.sorted(by: { $0.date > $1.date }) {
            for j in m.jobs where !j.jobKey.isEmpty && !ids.contains(j.jobKey) { ids.append(j.jobKey) }
        }
        return ids.prefix(4).compactMap { id in jobs.first(where: { $0.id == id }) }
    }

    private var results: [JobDef] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return jobs.filter { $0.name(language).range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Scegli una manutenzione").font(AppFont.serif(28)).foregroundStyle(Theme.ink)
                Spacer()
            }
            .padding(.horizontal, Space.s2)
            .padding(.top, Space.s3)

            HStack(spacing: Space.s1) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                TextField("", text: $query, prompt: Text("Cerca un intervento").foregroundColor(Theme.muted))
                    .font(AppFont.sans(17)).foregroundStyle(Theme.ink)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted) }
                }
            }
            .padding(.horizontal, Space.s2)
            .frame(height: Space.s6)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.base, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.base, style: .continuous).stroke(Theme.line, lineWidth: 1))
            .cardShadow()
            .padding(.horizontal, Space.s2)
            .padding(.top, Space.s2)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if query.isEmpty {
                        if !recents.isEmpty {
                            Text("Usati di recente").eyebrow().padding(.top, Space.s3)
                            HStack(spacing: Space.s1) {
                                ForEach(recents) { j in
                                    Button { toggle(j.id) } label: {
                                        Text(verbatim: j.name(language))
                                            .font(AppFont.sans(13, .semibold))
                                            .foregroundStyle(picked.contains(j.id) ? Theme.surface : Theme.ink)
                                            .padding(.horizontal, Space.s2).frame(height: Space.s5)
                                            .background(picked.contains(j.id) ? accent : Theme.surface,
                                                        in: RoundedRectangle(cornerRadius: Radius.base, style: .continuous))
                                            .overlay(RoundedRectangle(cornerRadius: Radius.base, style: .continuous).stroke(Theme.line, lineWidth: 1))
                                    }
                                    .buttonStyle(PressStyle())
                                }
                            }
                            .padding(.top, Space.s1)
                        }
                        Text("Tutte le manutenzioni").eyebrow().padding(.top, Space.s4)
                        ForEach(Catalog.categories) { c in categoryBlock(c) }
                    } else {
                        ForEach(results) { j in jobRow(j) }
                        if results.isEmpty {
                            Text("Nessun risultato.").font(AppFont.sans(15)).foregroundStyle(Theme.muted).padding(.top, Space.s3)
                        }
                    }

                    Button { askCustom = true } label: {
                        HStack(spacing: Space.s2) {
                            Image(systemName: "plus").foregroundStyle(accent)
                            Text("Altro: intervento personalizzato").font(AppFont.serif(17)).foregroundStyle(Theme.ink)
                            Spacer()
                        }
                        .padding(.vertical, Space.s2)
                        .contentShape(Rectangle())
                        .overlay(alignment: .top) { Hairline() }
                    }
                    .buttonStyle(.plain)
                    ForEach(customs, id: \.self) { c in
                        HStack {
                            Text(verbatim: c).font(AppFont.serif(17)).foregroundStyle(Theme.ink)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(accent)
                        }
                        .padding(.leading, Space.s5).padding(.vertical, Space.s1)
                    }

                    Toggle(isOn: $showAll) {
                        Text("Mostra anche gli interventi da auto").font(AppFont.sans(15)).foregroundStyle(Theme.ink)
                    }
                    .toggleStyle(AccentToggleStyle())
                    .padding(.vertical, Space.s3)
                }
                .padding(.horizontal, Space.s2)
                .padding(.bottom, Space.s8)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            if multi {
                PrimaryButton(title: count == 1 ? "Aggiungi 1 intervento" : "Aggiungi \(count) interventi", enabled: count > 0) { finish() }
                    .padding(.horizontal, Space.s2)
                    .padding(.bottom, Space.s1)
            }
        }
        .alert("Intervento personalizzato", isPresented: $askCustom) {
            TextField("Nome", text: $customName)
            Button("Aggiungi") {
                let n = customName.trimmingCharacters(in: .whitespaces)
                customName = ""
                guard !n.isEmpty else { return }
                if multi { customs.append(n) } else { onDone([PickedJob(def: nil, custom: n)]); dismiss() }
            }
            Button("Annulla", role: .cancel) { customName = "" }
        }
    }

    private func categoryBlock(_ c: CategoryDef) -> some View {
        let list = jobs.filter { $0.category == c.id }
        return VStack(alignment: .leading, spacing: 0) {
            if !list.isEmpty {
                let open = expanded.contains(c.id)
                Button {
                    withAnimation(Motion.spring) {
                        if open { expanded.remove(c.id) } else { expanded.insert(c.id) }
                    }
                    Haptics.tick()
                } label: {
                    HStack(spacing: Space.s2) {
                        Image(systemName: c.symbol).font(.system(size: 20)).foregroundStyle(open ? accent : Theme.muted).frame(width: Space.s3)
                        Text(verbatim: c.name(language)).font(AppFont.serif(17)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text(verbatim: String(list.count)).font(AppFont.sans(15)).foregroundStyle(Theme.muted)
                        Image(systemName: open ? "chevron.up" : "chevron.down").foregroundStyle(open ? accent : Theme.muted)
                    }
                    .padding(.vertical, Space.s2)
                    .contentShape(Rectangle())
                    .overlay(alignment: .top) { Hairline() }
                }
                .buttonStyle(.plain)
                if open { ForEach(list) { j in jobRow(j) } }
            }
        }
    }

    private func jobRow(_ j: JobDef) -> some View {
        let on = picked.contains(j.id)
        return Button { toggle(j.id) } label: {
            HStack(spacing: Space.s2) {
                Text(verbatim: j.name(language)).font(AppFont.sans(17)).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                Spacer()
                ZStack {
                    Circle().fill(on ? accent : Color.clear)
                    Circle().stroke(on ? accent : Theme.muted, lineWidth: 1.5)
                    if on { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.surface) }
                }
                .frame(width: Space.s3, height: Space.s3)
            }
            .padding(.vertical, Space.s2)
            .padding(.leading, Space.s5)
            .contentShape(Rectangle())
            .overlay(alignment: .top) { Hairline().padding(.leading, Space.s5) }
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ id: String) {
        Haptics.tick()
        if !multi {
            if let d = Catalog.job(id) { onDone([PickedJob(def: d, custom: "")]); dismiss() }
            return
        }
        if let i = picked.firstIndex(of: id) { picked.remove(at: i) } else { picked.append(id) }
    }

    private func finish() {
        var out: [PickedJob] = []
        for id in picked { if let d = Catalog.job(id) { out.append(PickedJob(def: d, custom: "")) } }
        for c in customs { out.append(PickedJob(def: nil, custom: c)) }
        onDone(out)
        dismiss()
    }
}
