import Foundation
import SwiftData

enum DeadlineKind: String, CaseIterable, Identifiable {
    case rca, bollo, revisione
    var id: String { rawValue }
    /// Italian text doubles as the localisation key.
    var title: String {
        switch self {
        case .rca: return "Assicurazione RCA"
        case .bollo: return "Bollo"
        case .revisione: return "Revisione"
        }
    }
    var short: String {
        switch self {
        case .rca: return "RCA"
        case .bollo: return "Bollo"
        case .revisione: return "Revisione"
        }
    }
    /// Days before the due date at which a notification fires (9:00).
    var alertOffsets: [Int] {
        self == .revisione ? [60, 30, 7, 1] : [30, 7, 1]
    }
}

enum ExpenseCategory: String, CaseIterable, Identifiable {
    case cleaning, parking, fine, other, rca, bollo, revisione
    var id: String { rawValue }
    var title: String {
        switch self {
        case .cleaning: return "Pulizia"
        case .parking: return "Parcheggio"
        case .fine: return "Multa"
        case .other: return "Altro"
        case .rca: return "Assicurazione RCA"
        case .bollo: return "Bollo"
        case .revisione: return "Revisione"
        }
    }
    var symbol: String {
        switch self {
        case .cleaning: return "sparkles"
        case .parking: return "parkingsign"
        case .fine: return "doc.text"
        case .other: return "tag"
        case .rca: return "shield"
        case .bollo: return "building.columns"
        case .revisione: return "checklist"
        }
    }
    /// Categories a person can pick by hand (deadline ones come from the deadline sheets).
    static var manual: [ExpenseCategory] { [.cleaning, .parking, .fine, .other] }
}

enum FuelKind: String, CaseIterable, Identifiable {
    case petrol95, petrol98, diesel, lpg
    var id: String { rawValue }
    var title: String {
        switch self {
        case .petrol95: return "Benzina 95"
        case .petrol98: return "Benzina 98"
        case .diesel: return "Gasolio"
        case .lpg: return "GPL"
        }
    }
}

@Model
final class Vehicle {
    var uid: UUID = UUID()
    var name: String = ""
    var make: String = ""
    var model: String = ""
    var year: Int = 2024
    var firstRegistration: Date? = nil
    var kindRaw: String = "scooter"
    var fuelKey: String = "petrol95"
    var coolingRaw: String = "air"
    var rearBrakeRaw: String = "drum"
    var tankLiters: Double = 0
    var startOdometer: Int = 0
    var purchaseDate: Date? = nil
    var purchasePrice: Double? = nil
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \FuelEntry.vehicle)
    var fuelEntries: [FuelEntry] = []
    @Relationship(deleteRule: .cascade, inverse: \MaintenanceEntry.vehicle)
    var maintenance: [MaintenanceEntry] = []
    @Relationship(deleteRule: .cascade, inverse: \ExpenseEntry.vehicle)
    var expenses: [ExpenseEntry] = []
    @Relationship(deleteRule: .cascade, inverse: \OdometerReading.vehicle)
    var readings: [OdometerReading] = []
    @Relationship(deleteRule: .cascade, inverse: \Deadline.vehicle)
    var deadlines: [Deadline] = []

    init(name: String, make: String, model: String, year: Int, startOdometer: Int) {
        self.uid = UUID()
        self.name = name
        self.make = make
        self.model = model
        self.year = year
        self.startOdometer = startOdometer
        self.createdAt = Date()
    }

    var displayName: String { name.isEmpty ? model : name }
    var isCar: Bool { kindRaw == "car" }
    var isLiquidCooled: Bool { coolingRaw == "liquid" }
    var hasDrumRear: Bool { rearBrakeRaw == "drum" }

    /// Every odometer reading we know about, with its date.
    var odometerPoints: [(date: Date, km: Int)] {
        var pts: [(date: Date, km: Int)] = [(createdAt, startOdometer)]
        for f in fuelEntries { pts.append((f.date, f.odometer)) }
        for m in maintenance { pts.append((m.date, m.odometer)) }
        for e in expenses where e.odometer > 0 { pts.append((e.date, e.odometer)) }
        for r in readings { pts.append((r.date, r.odometer)) }
        return pts
    }

    var currentOdometer: Int {
        odometerPoints.map { $0.km }.max() ?? startOdometer
    }

    func deadline(_ kind: DeadlineKind) -> Deadline? {
        deadlines.first(where: { $0.kindRaw == kind.rawValue })
    }

    var entryCount: Int {
        fuelEntries.count + maintenance.count + expenses.count + readings.count
    }
}

@Model
final class FuelEntry {
    var date: Date = Date()
    var odometer: Int = 0
    var liters: Double = 0
    var pricePerLiter: Double = 0
    /// The reserve light was on when this fill-up was made. Used to measure consumption
    /// from one light to the next. Older entries default to false.
    var reserveLight: Bool = false
    var vehicle: Vehicle?

    init(date: Date, odometer: Int, liters: Double, pricePerLiter: Double, reserveLight: Bool = false) {
        self.date = date
        self.odometer = odometer
        self.liters = liters
        self.pricePerLiter = pricePerLiter
        self.reserveLight = reserveLight
    }

    var total: Double { liters * pricePerLiter }
}

@Model
final class MaintenanceEntry {
    var date: Date = Date()
    var odometer: Int = 0
    var workshop: String = ""
    var note: String = ""
    var vehicle: Vehicle?
    @Relationship(deleteRule: .cascade, inverse: \MaintenanceJob.entry)
    var jobs: [MaintenanceJob] = []

    init(date: Date, odometer: Int, workshop: String, note: String) {
        self.date = date
        self.odometer = odometer
        self.workshop = workshop
        self.note = note
    }

    var total: Double { jobs.reduce(0) { $0 + $1.total } }
}

@Model
final class MaintenanceJob {
    var jobKey: String = ""
    var customName: String = ""
    var categoryKey: String = "oil"
    var unitPrice: Double = 0
    var quantity: Double = 1
    var ruleKm: Int = 0
    var ruleMonths: Int = 0
    var entry: MaintenanceEntry?

    init(jobKey: String, customName: String, categoryKey: String, unitPrice: Double, quantity: Double, ruleKm: Int, ruleMonths: Int) {
        self.jobKey = jobKey
        self.customName = customName
        self.categoryKey = categoryKey
        self.unitPrice = unitPrice
        self.quantity = quantity
        self.ruleKm = ruleKm
        self.ruleMonths = ruleMonths
    }

    var total: Double { unitPrice * quantity }
}

@Model
final class ExpenseEntry {
    var date: Date = Date()
    var odometer: Int = 0
    var categoryRaw: String = "other"
    var title: String = ""
    var amount: Double = 0
    var coverMonths: Int = 1
    var vehicle: Vehicle?

    init(date: Date, odometer: Int, category: ExpenseCategory, title: String, amount: Double, coverMonths: Int) {
        self.date = date
        self.odometer = odometer
        self.categoryRaw = category.rawValue
        self.title = title
        self.amount = amount
        self.coverMonths = coverMonths
    }

    var category: ExpenseCategory { ExpenseCategory(rawValue: categoryRaw) ?? .other }
}

@Model
final class OdometerReading {
    var date: Date = Date()
    var odometer: Int = 0
    var vehicle: Vehicle?

    init(date: Date, odometer: Int) {
        self.date = date
        self.odometer = odometer
    }
}

@Model
final class Deadline {
    var kindRaw: String = "rca"
    var dueDate: Date = Date()
    var startDate: Date? = nil
    var durationMonths: Int = 12
    var amount: Double = 0
    var alertsOn: Bool = true
    var renewals: [Date] = []
    var vehicle: Vehicle?

    init(kind: DeadlineKind, dueDate: Date) {
        self.kindRaw = kind.rawValue
        self.dueDate = dueDate
    }

    var kind: DeadlineKind { DeadlineKind(rawValue: kindRaw) ?? .rca }
}
