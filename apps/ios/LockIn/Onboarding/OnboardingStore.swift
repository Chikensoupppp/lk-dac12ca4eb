import Foundation

/// What the first-run flow remembers. Answers stay on the device; nothing is sent anywhere.
enum OnboardingStore {
    static let doneKey = "lockin.onboarding.done.v1"
    static let hoursKey = "lockin.onboarding.hoursIndex.v1"
    static let categoriesKey = "lockin.onboarding.categories.v1"
    static let goalsKey = "lockin.onboarding.goals.v1"

    /// True when the first-run flow should not show.
    /// UI tests skip it unless they ask for it with `-ui-testing-onboarding`.
    static func isDone(_ defaults: UserDefaults = .standard) -> Bool {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-ui-testing-onboarding") {
            if args.contains("-ui-testing-reset-state") { defaults.removeObject(forKey: doneKey) }
            return defaults.bool(forKey: doneKey)
        }
        if args.contains(where: { $0.hasPrefix("-ui-testing") }) { return true }
        #endif
        return defaults.bool(forKey: doneKey)
    }

    static func save(hoursIndex: Int?, categories: Set<String>, goals: Set<String>, defaults: UserDefaults = .standard) {
        if let hoursIndex { defaults.set(hoursIndex, forKey: hoursKey) }
        defaults.set(categories.sorted(), forKey: categoriesKey)
        defaults.set(goals.sorted(), forKey: goalsKey)
        defaults.set(true, forKey: doneKey)
        seedFromAnswers(goals: goals, defaults: defaults)
    }

    /// The task names the "what is worth your time" answers turn into. Sleep and People have no task.
    private static let taskForGoal: [(goal: String, task: String)] = [
        ("Study", "Studying"), ("Train", "Working out"), ("Create", "Creating"), ("Read", "Reading")
    ]

    /// Makes the answers do something: the chosen activities go to the top of the task list, and the
    /// first session starts at the 25 minutes the plan slide showed.
    static func seedFromAnswers(goals: Set<String>, defaults: UserDefaults = .standard) {
        let mine = taskForGoal.filter { goals.contains($0.goal) }.map(\.task)
        if !mine.isEmpty {
            let current = defaults.stringArray(forKey: "lockin.tasks.v1") ?? ["Studying", "Homework", "Work", "Writing", "Reading"]
            defaults.set(mine + current.filter { !mine.contains($0) }, forKey: "lockin.tasks.v1")
        }
        // The plan slide already set its own length; without a plan (Skip intro) it is 25.
        defaults.set(PlanStore.load(defaults)?.minutes ?? 25, forKey: "lockin.minutes.v1")
    }
}

/// The "look at your year" numbers. Plain arithmetic, shown to the user as an estimate.
enum OnboardingMath {
    static let hoursChoices = ["1 to 2 hours", "3 to 4 hours", "5 to 6 hours", "7 hours or more"]
    /// Middle of each choice. The last one is open-ended, so 8 is a low guess.
    static let hoursMidpoints: [Double] = [1.5, 3.5, 5.5, 8]

    /// Full 24-hour days per year spent on the phone. 0 for an unknown choice.
    static func daysPerYear(hoursIndex: Int) -> Int {
        guard hoursMidpoints.indices.contains(hoursIndex) else { return 0 }
        return Int((hoursMidpoints[hoursIndex] * 365 / 24).rounded())
    }

    /// Full 24-hour days a daily habit adds up to over a 365-day year, rounded down so
    /// "more than N days" stays true (25 minutes a day is 6.3 days).
    static func focusDaysPerYear(minutesPerDay: Int) -> Int {
        Int(Double(minutesPerDay * 365) / (24 * 60))
    }

    /// Small numbers as words ("six"); larger ones stay digits.
    static func spelled(_ n: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
        return words.indices.contains(n) ? words[n] : "\(n)"
    }

    /// Days won back if the time were cut in half.
    static func daysBackIfHalved(hoursIndex: Int) -> Int {
        daysPerYear(hoursIndex: hoursIndex) / 2
    }
}
