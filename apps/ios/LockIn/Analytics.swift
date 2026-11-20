import Foundation
import PostHog

/// Product analytics with PostHog: what people do in SwipeLater (which intro slides they see and
/// leave on, what they pick, sessions started, finished or ended early, Plus offers), so the app
/// can be improved. Never what is on their phone: Screen Time numbers stay inside Apple's report
/// and never reach this code, and app picks are sent as counts, not names.
///
/// Off when the build has no PostHog project token (`POSTHOG_PROJECT_TOKEN` in project.yml) and in
/// Debug builds (simulator CI). Events carry a random install id, no name, email or Apple ID.
enum Analytics {
    private static var started = false

    static func start() {
        guard !started,
              let token = Bundle.main.object(forInfoDictionaryKey: "PostHogProjectToken") as? String,
              token.hasPrefix("phc_") else { return }
        #if DEBUG
        // Debug builds (the simulator CI) would mix test taps into real users' numbers.
        return
        #endif
        let config = PostHogConfig(projectToken: token, host: "https://us.i.posthog.com")
        // App opened / backgrounded / installed / updated come for free.
        config.captureApplicationLifecycleEvents = true
        // SwiftUI's automatic screen names are meaningless; the intro sends its own slide names.
        config.captureScreenViews = false
        // A profile per install, so one person's path through the intro can be followed.
        config.personProfiles = .always
        config.sessionReplay = false
        PostHogSDK.shared.setup(config)
        started = true
    }

    /// One user action. Names are snake_case, properties are plain values.
    static func track(_ event: String, _ properties: [String: Any] = [:]) {
        guard started else { return }
        PostHogSDK.shared.capture(event, properties: properties.isEmpty ? nil : properties)
    }

    /// Facts about this person that later events and charts can be split by (e.g. has_plus).
    static func set(_ properties: [String: Any]) {
        guard started else { return }
        PostHogSDK.shared.capture("$set", properties: ["$set": properties])
    }
}
