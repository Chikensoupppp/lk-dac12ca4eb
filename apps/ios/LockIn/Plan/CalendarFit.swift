import Foundation

/// Fits the plan's lock-in time around the user's calendar. Pure (no EventKit), so it is tested
/// directly; `CalendarAccess` turns calendar events into `Busy` values on the phone.
///
/// It reads what each event is, not only when: a surgery or an away game makes the day off,
/// and things like exams, games and flights get a buffer before and after.
enum CalendarFit {
    struct Busy: Equatable {
        var start: Date
        var end: Date
        var title: String
        var allDay: Bool
    }

    enum Kind: Equatable { case dayOff, buffer, normal }

    /// Minutes kept free before and after a `.buffer` event.
    static let bufferMinutes = 30

    private static let dayOffWords = ["surgery", "operation", "hospital", "sick", "funeral", "vacation", "holiday",
                                      "trip", "wedding", "away game", "tournament", "retreat", "camp", "moving day"]
    private static let bufferWords = ["flight", "exam", "test", "final", "midterm", "quiz", "game", "match", "practice",
                                      "concert", "recital", "appointment", "dentist", "doctor", "interview", "gym"]

    static func kind(of title: String) -> Kind {
        let t = title.lowercased()
        if dayOffWords.contains(where: { contains(word: $0, in: t) }) { return .dayOff }
        if bufferWords.contains(where: { contains(word: $0, in: t) }) { return .buffer }
        return .normal
    }

    /// Whole-word match, so "test" does not match "latest".
    private static func contains(word: String, in text: String) -> Bool {
        text.range(of: "\\b\(NSRegularExpression.escapedPattern(for: word))\\b", options: .regularExpression) != nil
    }

    /// One plan day: its busy minutes inside the window, or the reason it is a day off.
    struct Day: Equatable {
        struct Block: Equatable {
            let range: ClosedRange<Int>
            let title: String
        }
        let date: Date
        let weekday: Int
        /// Busy ranges as minutes after midnight, buffers included, merged and sorted.
        let busy: [ClosedRange<Int>]
        /// The same events one by one with their names (buffers not included), for labels.
        let blocks: [Block]
        /// The event that makes it a day off (shown as the reason), or nil.
        let dayOff: String?

        /// The name of what is on at `start` for `minutes`, if anything.
        func clash(start: Int, minutes: Int) -> String? {
            if let dayOff { return dayOff }
            let end = start + minutes
            if let b = blocks.first(where: { $0.range.lowerBound < end && $0.range.upperBound > start }) { return b.title }
            return busy.contains { $0.lowerBound < end && $0.upperBound > start } ? "Busy" : nil
        }
    }

    /// The hours shown and searched: mornings for an early plan, afternoon and evening otherwise.
    static func window(near startMinute: Int) -> ClosedRange<Int> {
        startMinute < 12 * 60 ? (6 * 60)...(15 * 60) : (14 * 60)...(23 * 60)
    }

    /// The next occurrence of each plan weekday, starting today, Monday first, with what is on it.
    static func days(weekdays: Set<Int>, events: [Busy], from now: Date, calendar: Calendar = .current) -> [Day] {
        let today = calendar.startOfDay(for: now)
        let dates = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
            .filter { weekdays.contains(calendar.component(.weekday, from: $0)) }
            .sorted { mondayIndex(calendar.component(.weekday, from: $0)) < mondayIndex(calendar.component(.weekday, from: $1)) }
        return dates.map { date in
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            let onDay = events.filter { $0.start < dayEnd && $0.end > date }
            let off = onDay.first { kind(of: $0.title) == .dayOff }
            var ranges: [ClosedRange<Int>] = []
            var blocks: [Day.Block] = []
            for e in onDay where !e.allDay {
                let pad = kind(of: e.title) == .buffer ? bufferMinutes : 0
                let s0 = minuteOfDay(max(e.start, date), calendar: calendar)
                let e0 = e.end >= dayEnd ? 24 * 60 : minuteOfDay(e.end, calendar: calendar)
                guard e0 > s0 else { continue }
                blocks.append(Day.Block(range: s0...e0, title: e.title))
                ranges.append(max(s0 - pad, 0)...min(e0 + pad, 24 * 60))
            }
            return Day(date: date, weekday: calendar.component(.weekday, from: date), busy: merge(ranges),
                       blocks: blocks.sorted { $0.range.lowerBound < $1.range.lowerBound }, dayOff: off?.title)
        }
    }

    /// True when `minutes` starting at `start` fit with nothing busy, inside the day.
    static func isFree(_ day: Day, start: Int, minutes: Int) -> Bool {
        guard day.dayOff == nil, start >= 0, start + minutes <= 24 * 60 else { return false }
        let end = start + minutes
        return !day.busy.contains { $0.lowerBound < end && $0.upperBound > start }
    }

    struct Suggestion: Equatable {
        let minute: Int
        /// Plan days (not off) free at this time.
        let freeDays: Int
        let workingDays: Int
    }

    /// The same time every day: the best few starting times, most free days first, then nearest
    /// to the plan's own time. Starts on the quarter hour, at least 45 minutes apart.
    static func suggestions(days: [Day], minutes: Int, near: Int, count: Int = 3) -> [Suggestion] {
        let working = days.filter { $0.dayOff == nil }
        guard !working.isEmpty else { return [] }
        let w = window(near: near)
        var all: [Suggestion] = []
        var t = w.lowerBound
        while t + minutes <= w.upperBound {
            let free = working.filter { isFree($0, start: t, minutes: minutes) }.count
            if free > 0 { all.append(Suggestion(minute: t, freeDays: free, workingDays: working.count)) }
            t += 15
        }
        all.sort { a, b in
            if a.freeDays != b.freeDays { return a.freeDays > b.freeDays }
            return abs(a.minute - near) < abs(b.minute - near)
        }
        var picked: [Suggestion] = []
        for s in all where picked.allSatisfy({ abs($0.minute - s.minute) >= 45 }) {
            picked.append(s)
            if picked.count == count { break }
        }
        return picked
    }

    /// Fitted to each day (Plus): per weekday, the free start nearest to `near`. Days off are left out.
    static func bestEachDay(days: [Day], minutes: Int, near: Int) -> [Int: Int] {
        let w = window(near: near)
        var out: [Int: Int] = [:]
        for day in days where day.dayOff == nil {
            var best: Int?
            var t = w.lowerBound
            while t + minutes <= w.upperBound {
                if isFree(day, start: t, minutes: minutes), best.map({ abs(t - near) < abs($0 - near) }) ?? true { best = t }
                t += 15
            }
            if let best { out[day.weekday] = best }
        }
        return out
    }

    // MARK: Helpers

    static func minuteOfDay(_ date: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// 0 = Monday ... 6 = Sunday, for sorting.
    static func mondayIndex(_ weekday: Int) -> Int { (weekday + 5) % 7 }

    static func merge(_ ranges: [ClosedRange<Int>]) -> [ClosedRange<Int>] {
        var out: [ClosedRange<Int>] = []
        for r in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = out.last, r.lowerBound <= last.upperBound {
                out[out.count - 1] = last.lowerBound...max(last.upperBound, r.upperBound)
            } else {
                out.append(r)
            }
        }
        return out
    }
}
