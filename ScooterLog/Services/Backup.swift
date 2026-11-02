import Foundation
import SwiftData
import SwiftUI
import UIKit

struct BackupFile: Codable {
    var version: Int
    var exportedAt: Date
    var vehicles: [VehicleDTO]
}

struct VehicleDTO: Codable {
    var name: String
    var make: String
    var model: String
    var year: Int
    var firstRegistration: Date?
    var kindRaw: String
    var fuelKey: String
    var coolingRaw: String
    var rearBrakeRaw: String
    var tankLiters: Double
    var startOdometer: Int
    var purchaseDate: Date?
    var purchasePrice: Double?
    var createdAt: Date
    var fuel: [FuelDTO]
    var maintenance: [MaintDTO]
    var expenses: [ExpDTO]
    var readings: [ReadDTO]
    var deadlines: [DeadlineDTO]
}

struct FuelDTO: Codable { var date: Date; var odometer: Int; var liters: Double; var pricePerLiter: Double }
struct JobDTO: Codable {
    var jobKey: String; var customName: String; var categoryKey: String
    var unitPrice: Double; var quantity: Double; var ruleKm: Int; var ruleMonths: Int
}
struct MaintDTO: Codable { var date: Date; var odometer: Int; var workshop: String; var note: String; var jobs: [JobDTO] }
struct ExpDTO: Codable { var date: Date; var odometer: Int; var categoryRaw: String; var title: String; var amount: Double; var coverMonths: Int }
struct ReadDTO: Codable { var date: Date; var odometer: Int }
struct DeadlineDTO: Codable {
    var kindRaw: String; var dueDate: Date; var startDate: Date?
    var durationMonths: Int; var amount: Double; var alertsOn: Bool; var renewals: [Date]
}

enum BackupService {
    private static func fuelDTOs(_ v: Vehicle) -> [FuelDTO] {
        var out: [FuelDTO] = []
        for f in v.fuelEntries {
            out.append(FuelDTO(date: f.date, odometer: f.odometer, liters: f.liters, pricePerLiter: f.pricePerLiter))
        }
        return out
    }

    private static func maintDTOs(_ v: Vehicle) -> [MaintDTO] {
        var out: [MaintDTO] = []
        for m in v.maintenance {
            var jobs: [JobDTO] = []
            for j in m.jobs {
                jobs.append(JobDTO(jobKey: j.jobKey, customName: j.customName, categoryKey: j.categoryKey,
                                   unitPrice: j.unitPrice, quantity: j.quantity, ruleKm: j.ruleKm, ruleMonths: j.ruleMonths))
            }
            out.append(MaintDTO(date: m.date, odometer: m.odometer, workshop: m.workshop, note: m.note, jobs: jobs))
        }
        return out
    }

    private static func expenseDTOs(_ v: Vehicle) -> [ExpDTO] {
        var out: [ExpDTO] = []
        for e in v.expenses {
            out.append(ExpDTO(date: e.date, odometer: e.odometer, categoryRaw: e.categoryRaw, title: e.title,
                              amount: e.amount, coverMonths: e.coverMonths))
        }
        return out
    }

    private static func readingDTOs(_ v: Vehicle) -> [ReadDTO] {
        var out: [ReadDTO] = []
        for r in v.readings { out.append(ReadDTO(date: r.date, odometer: r.odometer)) }
        return out
    }

    private static func deadlineDTOs(_ v: Vehicle) -> [DeadlineDTO] {
        var out: [DeadlineDTO] = []
        for d in v.deadlines {
            out.append(DeadlineDTO(kindRaw: d.kindRaw, dueDate: d.dueDate, startDate: d.startDate,
                                   durationMonths: d.durationMonths, amount: d.amount,
                                   alertsOn: d.alertsOn, renewals: d.renewals))
        }
        return out
    }

    private static func vehicleDTO(_ v: Vehicle) -> VehicleDTO {
        VehicleDTO(
            name: v.name, make: v.make, model: v.model, year: v.year,
            firstRegistration: v.firstRegistration, kindRaw: v.kindRaw, fuelKey: v.fuelKey,
            coolingRaw: v.coolingRaw, rearBrakeRaw: v.rearBrakeRaw, tankLiters: v.tankLiters,
            startOdometer: v.startOdometer, purchaseDate: v.purchaseDate, purchasePrice: v.purchasePrice,
            createdAt: v.createdAt,
            fuel: fuelDTOs(v), maintenance: maintDTOs(v), expenses: expenseDTOs(v),
            readings: readingDTOs(v), deadlines: deadlineDTOs(v))
    }

    static func makeJSON(_ vehicles: [Vehicle]) -> Data? {
        var dtos: [VehicleDTO] = []
        for v in vehicles { dtos.append(vehicleDTO(v)) }
        let file = BackupFile(version: 1, exportedAt: Date(), vehicles: dtos)
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? enc.encode(file)
    }

    static func makeCSV(_ vehicles: [Vehicle]) -> Data? {
        func esc(_ s: String) -> String {
            if s.contains(",") || s.contains("\"") || s.contains("\n") {
                return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return s
        }
        let iso = ISO8601DateFormatter()
        var lines = ["vehicle,type,date,odometer,amount,details"]
        for v in vehicles {
            let n = esc(v.displayName)
            for f in v.fuelEntries {
                lines.append("\(n),fuel,\(iso.string(from: f.date)),\(f.odometer),\(f.total),\(f.liters) L @ \(f.pricePerLiter)")
            }
            for m in v.maintenance {
                let names = m.jobs.map { Catalog.displayName(jobKey: $0.jobKey, custom: $0.customName, lang: "it") }.joined(separator: "; ")
                lines.append("\(n),maintenance,\(iso.string(from: m.date)),\(m.odometer),\(m.total),\(esc(names))")
            }
            for e in v.expenses {
                lines.append("\(n),\(e.categoryRaw),\(iso.string(from: e.date)),\(e.odometer),\(e.amount),\(esc(e.title))")
            }
            for r in v.readings {
                lines.append("\(n),odometer,\(iso.string(from: r.date)),\(r.odometer),,")
            }
        }
        return lines.joined(separator: "\n").data(using: .utf8)
    }

    /// Replaces everything in the store with the backup contents.
    static func restore(_ data: Data, into context: ModelContext) -> Bool {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let file = try? dec.decode(BackupFile.self, from: data) else { return false }
        if let existing = try? context.fetch(FetchDescriptor<Vehicle>()) {
            for v in existing { context.delete(v) }
        }
        for d in file.vehicles {
            let v = Vehicle(name: d.name, make: d.make, model: d.model, year: d.year, startOdometer: d.startOdometer)
            v.firstRegistration = d.firstRegistration
            v.kindRaw = d.kindRaw
            v.fuelKey = d.fuelKey
            v.coolingRaw = d.coolingRaw
            v.rearBrakeRaw = d.rearBrakeRaw
            v.tankLiters = d.tankLiters
            v.purchaseDate = d.purchaseDate
            v.purchasePrice = d.purchasePrice
            v.createdAt = d.createdAt
            context.insert(v)
            for f in d.fuel {
                let e = FuelEntry(date: f.date, odometer: f.odometer, liters: f.liters, pricePerLiter: f.pricePerLiter)
                context.insert(e); e.vehicle = v
            }
            for m in d.maintenance {
                let e = MaintenanceEntry(date: m.date, odometer: m.odometer, workshop: m.workshop, note: m.note)
                context.insert(e); e.vehicle = v
                for j in m.jobs {
                    let job = MaintenanceJob(jobKey: j.jobKey, customName: j.customName, categoryKey: j.categoryKey,
                                             unitPrice: j.unitPrice, quantity: j.quantity, ruleKm: j.ruleKm, ruleMonths: j.ruleMonths)
                    context.insert(job); job.entry = e
                }
            }
            for x in d.expenses {
                let e = ExpenseEntry(date: x.date, odometer: x.odometer, category: ExpenseCategory(rawValue: x.categoryRaw) ?? .other,
                                     title: x.title, amount: x.amount, coverMonths: x.coverMonths)
                context.insert(e); e.vehicle = v
            }
            for r in d.readings {
                let e = OdometerReading(date: r.date, odometer: r.odometer)
                context.insert(e); e.vehicle = v
            }
            for dl in d.deadlines {
                let e = Deadline(kind: DeadlineKind(rawValue: dl.kindRaw) ?? .rca, dueDate: dl.dueDate)
                e.startDate = dl.startDate
                e.durationMonths = dl.durationMonths
                e.amount = dl.amount
                e.alertsOn = dl.alertsOn
                e.renewals = dl.renewals
                context.insert(e); e.vehicle = v
            }
        }
        try? context.save()
        return true
    }

    static func tempFile(named name: String, data: Data) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do { try data.write(to: url, options: .atomic); return url } catch { return nil }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    var onDone: (Bool) -> Void = { _ in }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc.completionWithItemsHandler = { _, completed, _, _ in onDone(completed) }
        return vc
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
