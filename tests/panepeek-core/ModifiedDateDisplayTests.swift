import Foundation
import Testing
@testable import PanePeekCore

struct ModifiedDateDisplayTests {
    @Test(arguments: [
        (0.0, "Just now"), (59.0, "Just now"), (60.0, "1 min ago"),
        (600.0, "10 min ago"), (3599.0, "59 min ago"), (3600.0, "1 hour ago"),
        (7200.0, "2 hours ago"), (43199.0, "11 hours ago"), (43200.0, "12 hours ago"),
        (46799.0, "12 hours ago"), (46800.0, "Today")
    ])
    func recentLabelsUseCompletedUnits(age: TimeInterval, expected: String) throws {
        let now = try date("2026-10-05T21:30:00Z")
        #expect(ModifiedDateDisplay.string(for: now.addingTimeInterval(-age), relativeTo: now, calendar: utc) == expected)
    }

    @Test func olderLabelsUseLocalDaysAndExactDateTime() throws {
        var calendar = utc
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        let now = try date("2026-10-05T21:30:00+02:00")
        for (timestamp, expected) in [
            ("2026-10-05T08:30:00+02:00", "Today"),
            ("2026-10-04T23:30:00+02:00", "Yesterday"),
            ("2026-10-03T14:05:00+02:00", "03.10.2026 14:05")
        ] {
            #expect(ModifiedDateDisplay.string(for: try date(timestamp), relativeTo: now, calendar: calendar) == expected)
        }
    }

    @Test func relativeLabelsAgeAcrossMidnightWithoutChangingTheTimestamp() throws {
        let modified = try date("2026-10-04T23:55:00Z")
        let first = try date("2026-10-05T00:05:00Z")
        #expect(ModifiedDateDisplay.string(for: modified, relativeTo: first, calendar: utc) == "10 min ago")
        #expect(ModifiedDateDisplay.string(for: modified, relativeTo: first.addingTimeInterval(60), calendar: utc) == "11 min ago")
        #expect(ModifiedDateDisplay.string(for: modified, relativeTo: try date("2026-10-05T13:00:00Z"), calendar: utc) == "Yesterday")
    }

    @Test(arguments: [
        ("2026-03-30T00:30:00+02:00", "2026-03-29T00:30:00+01:00"),
        ("2026-10-25T23:30:00+01:00", "2026-10-24T00:30:00+02:00")
    ])
    func yesterdayUsesCalendarDaysAcrossDaylightSaving(now: String, modified: String) throws {
        var calendar = utc
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        #expect(ModifiedDateDisplay.string(for: try date(modified), relativeTo: try date(now), calendar: calendar) == "Yesterday")
    }

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ value: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: value))
    }
}
