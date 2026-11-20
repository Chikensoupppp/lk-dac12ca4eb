import SwiftUI

@main
struct LockInApp: App {
    init() {
        PlusStore.configureRevenueCat()
        Analytics.start()
        FreshStart.runIfNewBuild()
        AppFont.register()
        AppFont.styleNavigationBar()
    }

    var body: some Scene {
        WindowGroup {
            AppRoot()
        }
    }
}

/// The app, plus the one-time analytics question where the law needs a yes first.
private struct AppRoot: View {
    @State private var asking = Analytics.needsConsentPrompt

    var body: some View {
        ZStack {
            #if DEBUG
            if DebugShot.name == "moods" { BrainMoodsSheet() } else { FocusView() }
            #else
            FocusView()
            #endif
            if asking {
                AnalyticsConsentView { yes in
                    Analytics.setConsent(yes)
                    withAnimation(.easeOut(duration: 0.25)) { asking = false }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }
}

func effectiveReduceMotion(_ systemValue: Bool) -> Bool {
    #if DEBUG
    return systemValue || ProcessInfo.processInfo.arguments.contains("-ui-testing-reduce-motion")
    #else
    return systemValue
    #endif
}
