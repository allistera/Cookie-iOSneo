import Foundation

/// The short time shown beside a row: clock time today, "Yesterday", the
/// weekday within the last week, otherwise day and month.
enum RelativeSentTime {
    static func string(
        for date: Date, now: Date = .now, calendar: Calendar = .current, locale: Locale = .current
    ) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return date.formatted(Date.FormatStyle(calendar: calendar).hour().minute().locale(locale))
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
            calendar.isDate(date, inSameDayAs: yesterday)
        {
            return String(localized: "Yesterday")
        }
        if let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)),
            date >= weekStart
        {
            return date.formatted(Date.FormatStyle(calendar: calendar).weekday(.abbreviated).locale(locale))
        }
        return date.formatted(Date.FormatStyle(calendar: calendar).day().month(.abbreviated).locale(locale))
    }
}
