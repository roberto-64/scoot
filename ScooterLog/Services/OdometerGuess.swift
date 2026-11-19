import Foundation

/// Helps the fill-up form with the odometer: guesses where the next reading will land, and returns the
/// leading digits that the last reading and the guess share, so tapping the field can complete them.
enum OdometerGuess {
    /// The usual distance between two fill-ups: the median of the last few gaps (km between consecutive
    /// fill-ups, ordered by odometer). nil when there are fewer than two fill-ups.
    static func usualGap(fills: [FuelEntry]) -> Int? {
        let kms = fills.map { $0.odometer }.filter { $0 > 0 }.sorted()
        guard kms.count >= 2 else { return nil }
        var gaps: [Int] = []
        for i in 1..<kms.count where kms[i] > kms[i - 1] { gaps.append(kms[i] - kms[i - 1]) }
        let recent = Array(gaps.suffix(5)).sorted()
        guard !recent.isEmpty else { return nil }
        return recent[recent.count / 2]
    }

    /// Leading digits common to the last reading and (last reading + usual gap), e.g. last 33878 and gap 120
    /// guess 33998 and share "33". Empty when there is no gap to learn from or nothing is shared
    /// (e.g. 99990 -> 100110). It never contains a digit that the guess itself would change.
    static func sharedPrefix(last: Int, fills: [FuelEntry]) -> String {
        guard last > 0, let gap = usualGap(fills: fills) else { return "" }
        let a = Array(String(last)), b = Array(String(last + gap))
        var out = ""
        for i in 0..<min(a.count, b.count) {
            if a[i] != b[i] { break }
            out.append(a[i])
        }
        return out
    }

    /// True when another dated reading of this vehicle makes `km` on `date` physically impossible: an entry
    /// on an earlier day with MORE km, or on a later day with FEWER km. Fuel, maintenance and odometer
    /// readings count; expenses don't (their km is often just "the current reading" stamped on an old
    /// date) and neither does the vehicle's start value. Same-day entries never conflict.
    static func conflicts(km: Int, date: Date, vehicle: Vehicle, ignoring: FuelEntry?) -> Bool {
        guard km > 0 else { return false }
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        var points: [(Date, Int)] = []
        for f in vehicle.fuelEntries where f !== ignoring { points.append((f.date, f.odometer)) }
        for m in vehicle.maintenance { points.append((m.date, m.odometer)) }
        for r in vehicle.readings { points.append((r.date, r.odometer)) }
        for (d, k) in points where k > 0 {
            let other = cal.startOfDay(for: d)
            if (other < day && k > km) || (other > day && k < km) { return true }
        }
        return false
    }
}
