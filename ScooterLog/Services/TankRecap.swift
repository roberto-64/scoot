import Foundation

/// The last two tanks, measured from one reserve-light fill-up to the next.
/// A tank runs from one marked fill-up to the following one. Its litres are the first fill-up plus any
/// fill-up in between, not the closing one (the tank was back at reserve level just before it).
struct TankRecap {
    /// Identifies the latest fill-up, so the pop-up shows once per fill-up.
    let key: String
    let kmPerL: Double
    /// Uncertainty in km/L, from the tank-level margin.
    let plusMinus: Int
    let lastKm: Int
    let lastLiters: Double
    let prevKm: Int
    let prevLiters: Double

    var totalKm: Int { lastKm + prevKm }
    var totalLiters: Double { lastLiters + prevLiters }

    /// Needs three fill-ups marked "reserve light" on one vehicle, the newest being its latest fill-up.
    static func make(vehicles: [Vehicle], marginLiters: Double) -> TankRecap? {
        var best: [FuelEntry] = []
        for v in vehicles {
            let fills = v.fuelEntries.sorted { $0.odometer < $1.odometer }
            guard let last = fills.last else { continue }
            if best.isEmpty || last.date > (best.last?.date ?? .distantPast) { best = fills }
        }
        guard let newest = best.last else { return nil }
        let marked = best.indices.filter { best[$0].reserveLight }
        guard marked.count >= 3, marked.last == best.count - 1 else { return nil }
        let a = marked[marked.count - 3], b = marked[marked.count - 2], c = marked[marked.count - 1]

        var prevLiters = 0.0
        for k in a..<b { prevLiters += best[k].liters }
        var lastLiters = 0.0
        for k in b..<c { lastLiters += best[k].liters }
        let prevKm = best[b].odometer - best[a].odometer
        let lastKm = best[c].odometer - best[b].odometer
        let liters = prevLiters + lastLiters
        guard prevKm > 0, lastKm > 0, prevLiters > 0, lastLiters > 0, liters > 0 else { return nil }

        let kmPerL = Double(prevKm + lastKm) / liters
        let margin = min(marginLiters / liters, 0.99)
        return TankRecap(key: "\(Int(newest.date.timeIntervalSince1970))-\(newest.odometer)",
                         kmPerL: kmPerL,
                         plusMinus: max(1, Int((kmPerL * margin).rounded())),
                         lastKm: lastKm, lastLiters: lastLiters,
                         prevKm: prevKm, prevLiters: prevLiters)
    }
}
