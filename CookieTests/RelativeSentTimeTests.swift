import Foundation
import Testing

@testable import Cookie

struct RelativeSentTimeTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }
    private let locale = Locale(identifier: "en_GB")
    /// Monday 5 October 2026, 11:20 UTC.
    private let now = Date(timeIntervalSince1970: 1_791_199_200)

    private func text(hoursAgo: Double) -> String {
        RelativeSentTime.string(
            for: now.addingTimeInterval(-hoursAgo * 3600), now: now, calendar: calendar, locale: locale)
    }

    @Test func todayShowsTime() { #expect(text(hoursAgo: 1.5) == "09:50") }
    @Test func yesterdayShowsYesterday() { #expect(text(hoursAgo: 24) == "Yesterday") }
    @Test func withinAWeekShowsWeekday() { #expect(text(hoursAgo: 48) == "Sat") }
    @Test func sixDaysAgoShowsWeekday() { #expect(text(hoursAgo: 6 * 24) == "Tue") }
    @Test func olderShowsDayAndMonth() { #expect(text(hoursAgo: 7 * 24) == "28 Sep") }
}
