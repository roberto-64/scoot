import Foundation

func parseDecimal(_ s: String) -> Double? {
    let t = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
    return Double(t)
}

func parseInt(_ s: String) -> Int {
    Int(s.filter { $0.isNumber }) ?? 0
}

extension Double {
    func money(_ locale: Locale) -> String {
        self.formatted(.currency(code: "EUR").locale(locale))
    }
    func decimal(_ digits: Int, _ locale: Locale) -> String {
        self.formatted(.number.precision(.fractionLength(digits)).locale(locale))
    }
    /// For pre-filling an input: no thousands separator, no trailing zeros.
    func plain(_ locale: Locale, maxDigits: Int = 3) -> String {
        self.formatted(.number.grouping(.never).precision(.fractionLength(0...maxDigits)).locale(locale))
    }
}

extension Int {
    func grouped(_ locale: Locale) -> String {
        self.formatted(.number.locale(locale))
    }
}

extension Date {
    func short(_ locale: Locale) -> String {
        self.formatted(.dateTime.day().month(.abbreviated).year().locale(locale))
    }
    func dayMonth(_ locale: Locale) -> String {
        self.formatted(.dateTime.day().month(.abbreviated).locale(locale))
    }
    func monthYear(_ locale: Locale) -> String {
        self.formatted(.dateTime.month(.wide).year().locale(locale))
    }
    func monthShortYear(_ locale: Locale) -> String {
        self.formatted(.dateTime.month(.abbreviated).year().locale(locale))
    }
    func time(_ locale: Locale) -> String {
        self.formatted(.dateTime.hour().minute().locale(locale))
    }
    var startOfMonth: Date {
        let c = Calendar.current
        return c.date(from: c.dateComponents([.year, .month], from: self)) ?? self
    }
    /// Last day of this date's month.
    var endOfMonth: Date {
        let c = Calendar.current
        let start = startOfMonth
        let next = c.date(byAdding: .month, value: 1, to: start) ?? start
        return c.date(byAdding: .day, value: -1, to: next) ?? self
    }
    func addingMonths(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: n, to: self) ?? self
    }
    func addingDays(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: n, to: self) ?? self
    }
}

func daysBetween(_ from: Date, _ to: Date) -> Int {
    let c = Calendar.current
    return c.dateComponents([.day], from: c.startOfDay(for: from), to: c.startOfDay(for: to)).day ?? 0
}
