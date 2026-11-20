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
            #if DEBUG
            if DebugShot.name == "moods" { BrainMoodsSheet() } else { FocusView() }
            #else
            FocusView()
            #endif
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
