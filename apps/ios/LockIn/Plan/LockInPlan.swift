import Foundation

/// The user's lock-in plan: how many lock-ins a day, how long, from what time, on which days.
/// Made from the first-run answers (hours, what pulls them in, what it is for), shown every day
/// on the Focus screen, and adjusted at the start of each week. Stays on this phone.
struct LockInPlan: Codable, Equatable {
    var sessionsPerDay: Int
    var minutes: Int
    /// Minute of the day the first lock-in starts (16 * 60 = 4:00 PM). The rest follow back to back.
    var startMinute: Int
    /// `Calendar` weekday numbers: 1 = Sunday ... 7 = Saturday. Weekdays by default.
    var weekdays: Set<Int>
    /// Hours band from the first run (0 = 1-2 h ... 3 = 7+ h), nil when skipped.
    var hoursIndex: Int?
    /// What pulls them in ("Social", "Video", ...) and what the time is for ("Studying").
    var pulls: [String]
    var task: String?
    /// When the plan started; weeks are counted from here.
    var since: Date
    /// Start minute per weekday when the time is fitted to each day around the calendar (Plus);
    /// nil means `startMinute` on every plan day. Older saved plans decode it as nil.
    var dayStarts: [Int: Int]? = nil

    var minutesPerDay: Int { sessionsPerDay * minutes }

    /// When the first lock-in starts on a given weekday.
    func startMinute(weekday: Int) -> Int { dayStarts?[weekday] ?? startMinute }

    func isPlanDay(_ date: Date, calendar: Calendar = FocusLog.calendar) -> Bool {
        weekdays.contains(calendar.component(.weekday, from: date))
    }

    /// Start times of the day's lock-ins.
    func slots(on date: Date, calendar: Calendar = FocusLog.calendar) -> [Date] {
        let day = calendar.startOfDay(for: date)
        let start = startMinute(weekday: calendar.component(.weekday, from: date))
        return (0..<sessionsPerDay).compactMap {
            calendar.date(byAdding: .minute, value: start + $0 * minutes, to: day)
        }
    }
}

/// The rules that turn answers into a plan, and a week's result into next week's plan.
/// Opinionated defaults on purpose: one clear plan beats a page of options.
enum PlanRules {
    struct Step: Equatable {
        let sessions: Int
        let minutes: Int
    }

    /// Lock-ins for each hours band: more phone time gets a bigger plan.
    static let ladder = [Step(sessions: 1, minutes: 25), Step(sessions: 2, minutes: 25),
                         Step(sessions: 2, minutes: 45), Step(sessions: 3, minutes: 45)]

    static func make(hoursIndex: Int?, pulls: Set<String>, goals: Set<String>, now: Date = .now) -> LockInPlan {
        let step = ladder[min(max(hoursIndex ?? 0, 0), ladder.count - 1)]
        return LockInPlan(sessionsPerDay: step.sessions, minutes: step.minutes,
                          startMinute: startMinute(goals: goals), weekdays: [2, 3, 4, 5, 6],
                          hoursIndex: hoursIndex, pulls: pulls.sorted(), task: task(goals: goals), since: now)
    }

    /// When the first lock-in starts, from what the time is for.
    static func startMinute(goals: Set<String>) -> Int {
        if goals.contains("Study") { return 16 * 60 }      // after school
        if goals.contains("Train") { return 7 * 60 }       // before the day starts
        if goals.contains("Create") { return 10 * 60 }
        if goals.contains("Read") { return 20 * 60 }
        if goals.contains("Sleep") { return 21 * 60 }      // a phone-free hour before bed
        return 16 * 60
    }

    static func task(goals: Set<String>) -> String? {
        let names = [("Study", "Studying"), ("Train", "Working out"), ("Create", "Creating"), ("Read", "Reading")]
        return names.first { goals.contains($0.0) }?.1
    }

    /// Full 24-hour days a year the plan adds up to, counting only plan days ("≈ 16 days this year").
    static func daysPerYear(_ plan: LockInPlan) -> Int {
        Int(Double(plan.minutesPerDay * plan.weekdays.count * 52) / (24 * 60))
    }

    enum Change: String, CaseIterable { case stepUp, keep, easier }

    /// Where a plan sits on the ladder. A plan that is not on it counts as the highest step that
    /// is not bigger.
    static func rung(_ plan: LockInPlan) -> Int {
        if let exact = ladder.firstIndex(where: { $0.sessions == plan.sessionsPerDay && $0.minutes == plan.minutes }) {
            return exact
        }
        return ladder.indices.last { ladder[$0].sessions * ladder[$0].minutes <= plan.minutesPerDay } ?? 0
    }

    static func apply(_ change: Change, to plan: LockInPlan) -> LockInPlan {
        let r = rung(plan)
        let target: Int
        switch change {
        case .keep: return plan
        case .stepUp: target = min(r + 1, ladder.count - 1)
        case .easier: target = max(r - 1, 0)
        }
        var next = plan
        next.sessionsPerDay = ladder[target].sessions
        next.minutes = ladder[target].minutes
        return next
    }

    /// What to suggest after a week: nearly all done, go up; about half, keep; less, go easier.
    static func suggestion(done: Int, planned: Int, plan: LockInPlan) -> Change {
        guard planned > 0 else { return .keep }
        let rate = Double(done) / Double(planned)
        if rate >= 0.9, rung(plan) < ladder.count - 1 { return .stepUp }
        if rate >= 0.5 { return .keep }
        return rung(plan) > 0 ? .easier : .keep
    }
}

/// How the plan is going, read from Lock In's own focus log (finished lock-ins and minutes).
struct PlanProgress: Equatable {
    struct Day: Equatable {
        let date: Date
        let planned: Int
        let done: Int
    }

    let today: Day?
    let minutesToday: Int
    /// The plan days of this week, Monday first.
    let week: [Day]

    static func make(plan: LockInPlan, now: Date = .now, defaults: UserDefaults = .standard) -> PlanProgress {
        let cal = FocusLog.calendar
        let log = FocusLog.week(of: now, defaults: defaults)
        let todayIndex = min(max(cal.dateComponents([.day], from: log.start, to: cal.startOfDay(for: now)).day ?? 0, 0), 6)
        var week: [Day] = []
        for i in 0..<7 {
            guard let date = cal.date(byAdding: .day, value: i, to: log.start), plan.isPlanDay(date, calendar: cal) else { continue }
            week.append(Day(date: date, planned: plan.sessionsPerDay, done: min(log.days[i].sessions, plan.sessionsPerDay)))
        }
        let today = week.first { cal.isDate($0.date, inSameDayAs: now) }
        return PlanProgress(today: today, minutesToday: log.days[todayIndex].minutes, week: week)
    }

    /// The next lock-in today that is not done yet, if any.
    func nextSlot(plan: LockInPlan, now: Date = .now) -> Date? {
        guard let today else { return nil }
        let slots = plan.slots(on: now)
        return slots.indices.contains(today.done) ? slots[today.done] : nil
    }
}

/// A finished week, for the Monday check-in.
struct PlanWeekResult: Equatable {
    let weekStart: Date
    let planned: Int
    let done: Int
    let minutes: Int
    /// 0 = Monday.
    let bestDay: Int?
    /// 1 for the plan's first week.
    let number: Int

    static func make(plan: LockInPlan, weekOf date: Date, defaults: UserDefaults = .standard) -> PlanWeekResult {
        let cal = FocusLog.calendar
        let log = FocusLog.week(of: date, defaults: defaults)
        let firstDay = cal.startOfDay(for: plan.since)
        var planned = 0, done = 0
        for i in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: i, to: log.start), day >= firstDay,
                  plan.isPlanDay(day, calendar: cal) else { continue }
            planned += plan.sessionsPerDay
            done += min(log.days[i].sessions, plan.sessionsPerDay)
        }
        let weeks = cal.dateComponents([.weekOfYear], from: FocusLog.weekStart(plan.since), to: log.start).weekOfYear ?? 0
        return PlanWeekResult(weekStart: log.start, planned: planned, done: done, minutes: log.minutes,
                              bestDay: log.bestDay, number: max(weeks, 0) + 1)
    }
}

/// Saves the plan and remembers which weeks were already checked in.
enum PlanStore {
    static let key = "lockin.plan.v1"
    static let checkedKey = "lockin.plan.checkedWeek.v1"

    static func load(_ defaults: UserDefaults = .standard) -> LockInPlan? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(LockInPlan.self, from: $0) }
    }

    static func save(_ plan: LockInPlan, _ defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(plan) { defaults.set(data, forKey: key) }
        // The Focus screen opens on the plan's length.
        defaults.set(plan.minutes, forKey: "lockin.minutes.v1")
    }

    /// The week (its Monday) that still needs a check-in: last week, if the plan ran in it and it
    /// was not checked in yet.
    static func pendingCheckIn(now: Date = .now, _ defaults: UserDefaults = .standard) -> Date? {
        guard let plan = load(defaults) else { return nil }
        let cal = FocusLog.calendar
        guard let lastWeek = cal.date(byAdding: .day, value: -7, to: FocusLog.weekStart(now)) else { return nil }
        guard FocusLog.weekStart(plan.since) <= lastWeek else { return nil }
        guard defaults.string(forKey: checkedKey) != FocusLog.dayKey(lastWeek) else { return nil }
        return lastWeek
    }

    static func markCheckedIn(week: Date, _ defaults: UserDefaults = .standard) {
        defaults.set(FocusLog.dayKey(week), forKey: checkedKey)
    }
}
