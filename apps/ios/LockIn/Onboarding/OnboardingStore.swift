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

    /// Days won back if the time were cut in half.
    static func daysBackIfHalved(hoursIndex: Int) -> Int {
        daysPerYear(hoursIndex: hoursIndex) / 2
    }
}
