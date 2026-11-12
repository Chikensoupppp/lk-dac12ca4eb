import DeviceActivity
import ManagedSettings
import SwiftUI

/// Draws the user's real Screen Time inside Lock In's onboarding. Apple runs this in a sandbox:
/// it can read usage, but nothing it reads can leave it, not even back to the app.
@main
struct LockInReport: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        RevealScene(guess: nil) { RevealView(data: $0) }
        RevealScene(guess: 0) { RevealView(data: $0) }
        RevealScene(guess: 1) { RevealView(data: $0) }
        RevealScene(guess: 2) { RevealView(data: $0) }
        RevealScene(guess: 3) { RevealView(data: $0) }
    }
}

struct RevealData {
    struct AppTime: Identifiable {
        let id = UUID()
        let name: String
        let token: ApplicationToken?
        let seconds: TimeInterval
    }

    let guess: Int?
    /// Average per day over the days that had any use.
    let perDay: TimeInterval
    let pickupsPerDay: Int
    let topApps: [AppTime]
    let daysWithData: Int
}

struct RevealScene: DeviceActivityReportScene {
    let guess: Int?
    let content: (RevealData) -> RevealView

    var context: DeviceActivityReport.Context { .reveal(guess: guess) }

    init(guess: Int?, content: @escaping (RevealData) -> RevealView) {
        self.guess = guess
        self.content = content
    }

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> RevealData {
        var total: TimeInterval = 0
        var pickups = 0
        var days = 0
        var perApp: [String: (token: ApplicationToken?, seconds: TimeInterval)] = [:]

        for await device in data {
            for await segment in device.activitySegments {
                if segment.totalActivityDuration > 60 { days += 1 }
                total += segment.totalActivityDuration
                for await category in segment.categories {
                    for await app in category.applications {
                        let name = app.application.localizedDisplayName ?? "App"
                        let old = perApp[name] ?? (app.application.token, 0)
                        perApp[name] = (old.token ?? app.application.token, old.seconds + app.totalActivityDuration)
                        pickups += app.numberOfPickups
                    }
                }
            }
        }
        let d = max(days, 1)
        let top = perApp
            .sorted { $0.value.seconds > $1.value.seconds }
            .prefix(4)
            .map { RevealData.AppTime(name: $0.key, token: $0.value.token, seconds: $0.value.seconds / Double(d)) }
        return RevealData(guess: guess, perDay: total / Double(d), pickupsPerDay: pickups / d,
                          topApps: Array(top), daysWithData: days)
    }
}
