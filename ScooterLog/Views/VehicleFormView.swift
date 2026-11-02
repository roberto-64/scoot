import SwiftUI
import SwiftData

struct VehicleFormView: View {
    var vehicle: Vehicle? = nil
    var onDeleted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("selectedVehicle") private var selectedID = ""

    @State private var name: String
    @State private var make: String
    @State private var model: String
    @State private var yearText: String
    @State private var odoText: String
    @State private var tankText: String
    @State private var priceText: String
    @State private var hasReg: Bool
    @State private var regDate: Date
    @State private var kind: String
    @State private var fuelKey: String
    @State private var cooling: String
    @State private var rearBrake: String
    @State private var hasPurchase: Bool
    @State private var purchaseDate: Date
    @State private var confirmDelete = false

    init(vehicle: Vehicle? = nil, onDeleted: @escaping () -> Void = {}) {
        self.vehicle = vehicle
        self.onDeleted = onDeleted
        _name = State(initialValue: vehicle?.name ?? "")
        _make = State(initialValue: vehicle?.make ?? "")
        _model = State(initialValue: vehicle?.model ?? "")
        _yearText = State(initialValue: String(vehicle?.year ?? Calendar.current.component(.year, from: Date())))
        _odoText = State(initialValue: vehicle.map { String($0.currentOdometer) } ?? "")
        _tankText = State(initialValue: (vehicle?.tankLiters ?? 0) > 0 ? String(vehicle?.tankLiters ?? 0) : "")
        _priceText = State(initialValue: (vehicle?.purchasePrice ?? 0) > 0 ? String(vehicle?.purchasePrice ?? 0) : "")
        _hasReg = State(initialValue: vehicle?.firstRegistration != nil)
        _regDate = State(initialValue: vehicle?.firstRegistration ?? Date())
        _kind = State(initialValue: vehicle?.kindRaw ?? "scooter")
        _fuelKey = State(initialValue: vehicle?.fuelKey ?? "petrol95")
        _cooling = State(initialValue: vehicle?.coolingRaw ?? "air")
        _rearBrake = State(initialValue: vehicle?.rearBrakeRaw ?? "drum")
        _hasPurchase = State(initialValue: vehicle?.purchaseDate != nil)
        _purchaseDate = State(initialValue: vehicle?.purchaseDate ?? Date())
    }

    private var year: Int { parseInt(yearText) }
    private var canSave: Bool { !model.trimmingCharacters(in: .whitespaces).isEmpty && year > 1900 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s3) {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        if let v = vehicle { Text(verbatim: v.displayName).eyebrow() }
                        Text(vehicle == nil ? "Nuovo veicolo" : "Dettagli veicolo")
                            .font(AppFont.serif(28)).foregroundStyle(Theme.ink)
                    }
                    Spacer()
                    Button { dismiss() } label: { IconSquare(systemName: "xmark") }
                        .buttonStyle(PressStyle())
                }

                LineField(label: "Soprannome", text: $name, keyboard: .default, size: 28, placeholder: "Filippo")
                HStack(alignment: .top, spacing: Space.s3) {
                    LineField(label: "Marca", text: $make, keyboard: .default, size: 22, placeholder: "Piaggio")
                    LineField(label: "Modello", text: $model, keyboard: .default, size: 22, placeholder: "Liberty 125")
                }
                HStack(alignment: .top, spacing: Space.s3) {
                    LineField(label: "Anno", text: $yearText, keyboard: .numberPad, size: 22)
                    VStack(alignment: .leading, spacing: Space.s1) {
                        Text("Prima immatricolazione").eyebrow()
                        Toggle(isOn: $hasReg) { Text("Imposta").font(AppFont.sans(15)).foregroundStyle(Theme.ink) }
                            .toggleStyle(AccentToggleStyle())
                        if hasReg {
                            DatePicker("", selection: $regDate, displayedComponents: .date).labelsHidden()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: Space.s1) {
                    Text("Tipo di veicolo").eyebrow()
                    Segmented(options: [SegmentOption(value: "scooter", label: "Scooter"),
                                        SegmentOption(value: "moto", label: "Moto"),
                                        SegmentOption(value: "car", label: "Auto")], selection: $kind)
                }

                HStack {
                    Text("Carburante").font(AppFont.sans(17)).foregroundStyle(Theme.ink)
                    Spacer()
                    Picker("", selection: $fuelKey) {
                        ForEach(FuelKind.allCases) { k in Text(LocalizedStringKey(k.title)).tag(k.rawValue) }
                    }
                    .pickerStyle(.menu).tint(Theme.muted)
                }
                .padding(.vertical, Space.s1)
                .overlay(alignment: .top) { Hairline() }
                .overlay(alignment: .bottom) { Hairline() }

                VStack(alignment: .leading, spacing: Space.s1) {
                    Text("Raffreddamento").eyebrow()
                    Segmented(options: [SegmentOption(value: "air", label: "Aria"),
                                        SegmentOption(value: "liquid", label: "Liquido")], selection: $cooling)
                }
                VStack(alignment: .leading, spacing: Space.s1) {
                    Text("Freno posteriore").eyebrow()
                    Segmented(options: [SegmentOption(value: "drum", label: "Tamburo"),
                                        SegmentOption(value: "disc", label: "Disco")], selection: $rearBrake)
                }

                HStack(alignment: .top, spacing: Space.s3) {
                    LineField(label: "Capienza serbatoio", text: $tankText, unit: "L", size: 22)
                    LineField(label: "Contachilometri", text: $odoText, unit: "km", keyboard: .numberPad, size: 22)
                }

                VStack(alignment: .leading, spacing: Space.s1) {
                    Toggle(isOn: $hasPurchase) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Acquisto").font(AppFont.sans(17)).foregroundStyle(Theme.ink)
                            Text("Data e prezzo, facoltativi").eyebrow()
                        }
                    }
                    .toggleStyle(AccentToggleStyle())
                    if hasPurchase {
                        DatePicker("", selection: $purchaseDate, displayedComponents: .date).labelsHidden()
                        LineField(label: "Prezzo", text: $priceText, unit: "€", size: 22)
                    }
                }

                HStack(alignment: .top, spacing: Space.s2) {
                    Image(systemName: "lock").foregroundStyle(Theme.muted)
                    Text("Nessuna targa, nessun numero di telaio, nessun account. I dati restano su questo telefono.")
                        .eyebrow()
                }
                .card()

                if vehicle != nil {
                    Button { confirmDelete = true } label: {
                        HStack(spacing: Space.s1) {
                            Image(systemName: "trash")
                            Text("Elimina veicolo")
                        }
                        .font(AppFont.sans(15, .semibold))
                        .foregroundStyle(Theme.ink)
                    }
                    .buttonStyle(PressStyle())
                }
            }
            .padding(.horizontal, Space.s2)
            .padding(.top, Space.s3)
            .padding(.bottom, Space.s3)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Salva veicolo", enabled: canSave) { save() }
                .padding(.horizontal, Space.s2)
                .padding(.bottom, Space.s1)
        }
        .confirmationDialog("Eliminare questo veicolo e tutte le sue registrazioni?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Elimina veicolo", role: .destructive) {
                if let v = vehicle {
                    context.delete(v)
                    try? context.save()
                    DataSignal.fire()
                    dismiss()
                    onDeleted()
                }
            }
            Button("Annulla", role: .cancel) {}
        }
    }

    private func save() {
        let odo = parseInt(odoText)
        let v: Vehicle
        if let existing = vehicle {
            v = existing
        } else {
            v = Vehicle(name: "", make: "", model: "", year: year, startOdometer: odo)
            context.insert(v)
            selectedID = v.uid.uuidString
        }
        v.name = name.trimmingCharacters(in: .whitespaces)
        v.make = make.trimmingCharacters(in: .whitespaces)
        v.model = model.trimmingCharacters(in: .whitespaces)
        v.year = year
        v.kindRaw = kind
        v.fuelKey = fuelKey
        v.coolingRaw = cooling
        v.rearBrakeRaw = rearBrake
        v.tankLiters = parseDecimal(tankText) ?? 0
        v.firstRegistration = hasReg ? regDate : nil
        v.purchaseDate = hasPurchase ? purchaseDate : nil
        v.purchasePrice = hasPurchase ? parseDecimal(priceText) : nil
        if vehicle != nil, odo > v.currentOdometer {
            let r = OdometerReading(date: Date(), odometer: odo)
            context.insert(r)
            r.vehicle = v
        }
        try? context.save()
        Haptics.success()
        DataSignal.fire()
        dismiss()
    }
}
