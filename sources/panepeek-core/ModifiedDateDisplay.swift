import Foundation

public enum ModifiedDateDisplay {
    /// Compact listing text relative to the supplied clock and local calendar.
    public static func string(for date: Date?, relativeTo now: Date, calendar: Calendar = .current) -> String {
        guard let date else { return "Unavailable" }
        let elapsed = now.timeIntervalSince(date)
        if elapsed >= 0 {
            if elapsed < 60 { return "Just now" }
            if elapsed < 3600 { return "\(Int(elapsed / 60)) min ago" }
            if elapsed < 13 * 3600 {
                let hours = Int(elapsed / 3600)
                return "\(hours) \(hours == 1 ? "hour" : "hours") ago"
            }
            if calendar.isDate(date, inSameDayAs: now) { return "Today" }
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
               calendar.isDate(date, inSameDayAs: yesterday) {
                return "Yesterday"
            }
        }
        return date.formatted(Date.VerbatimFormatStyle(
            format: "\(day: .twoDigits).\(month: .twoDigits).\(year: .defaultDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
            locale: Locale(identifier: "en_US_POSIX"), timeZone: calendar.timeZone, calendar: calendar
        ))
    }
}
