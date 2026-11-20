import Foundation
import PostHog

/// Product analytics with PostHog: what people do in SwipeLater (which intro slides they see and
/// leave on, what they pick, sessions started, finished or ended early, Plus offers), so the app
/// can be improved. Never what is on their phone: Screen Time numbers stay inside Apple's report
/// and never reach this code, and app picks are sent as counts, not names.
///
/// Off when the build has no PostHog project token (`POSTHOG_PROJECT_TOKEN` in project.yml) and in
/// Debug builds (simulator CI). Events carry a random install id, no name, email or Apple ID.
///
/// In the EU, EEA, UK and Switzerland nothing is sent until the person says yes to the one-time
/// "Help improve SwipeLater?" screen (`AnalyticsConsentView`). They can change their mind later in
/// the Screen Time sheet. Elsewhere analytics run as before.
enum Analytics {
    private static var started = false
    private static let consentKey = "analyticsConsent"

    /// Countries that need a yes before analytics: EU, EEA, UK, Switzerland.
    private static let consentRegions: Set<String> = [
        "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU", "IE", "IT",
        "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK", "SI", "ES", "SE",
        "IS", "LI", "NO", "GB", "CH",
    ]

    /// Region override for tests: `-analytics-region DE`.
    private static var region: String? {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-analytics-region"), i + 1 < args.count { return args[i + 1] }
        return Locale.current.region?.identifier
    }

    /// True where a yes is needed first. Uses the phone's region setting.
    static var consentRequired: Bool {
        guard let region else { return false }
        return consentRegions.contains(region.uppercased())
    }

    /// nil = not asked yet.
    static var consent: Bool? {
        get { UserDefaults.standard.object(forKey: consentKey) as? Bool }
        set {
            if let newValue { UserDefaults.standard.set(newValue, forKey: consentKey) }
            else { UserDefaults.standard.removeObject(forKey: consentKey) }
        }
    }

    /// The prompt shows once, only where a yes is needed and nothing has been answered.
    static var needsConsentPrompt: Bool { consentRequired && consent == nil }

    /// Analytics may run: outside the consent regions always, inside them only after a yes.
    static var allowed: Bool { !consentRequired || consent == true }

    static func start() {
        guard !started, allowed,
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

    /// The person answered the prompt (or flipped the switch later).
    static func setConsent(_ yes: Bool) {
        consent = yes
        if yes {
            if started { PostHogSDK.shared.optIn() } else { start() }
        } else if started {
            PostHogSDK.shared.optOut()
            PostHogSDK.shared.reset()
        }
    }

    /// One user action. Names are snake_case, properties are plain values.
    static func track(_ event: String, _ properties: [String: Any] = [:]) {
        guard started, allowed else { return }
        PostHogSDK.shared.capture(event, properties: properties.isEmpty ? nil : properties)
    }

    /// Facts about this person that later events and charts can be split by (e.g. has_plus).
    static func set(_ properties: [String: Any]) {
        guard started, allowed else { return }
        PostHogSDK.shared.capture("$set", properties: ["$set": properties])
    }
}
