import SwiftUI

@main
struct LockInApp: App {
    init() {
        AppFont.register()
        AppFont.styleNavigationBar()
    }

    var body: some Scene {
        WindowGroup { FocusView() }
    }
}

func effectiveReduceMotion(_ systemValue: Bool) -> Bool {
    #if DEBUG
    return systemValue || ProcessInfo.processInfo.arguments.contains("-ui-testing-reduce-motion")
    #else
    return systemValue
    #endif
}
