import SwiftUI

@main
struct LockInApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-ui-testing-reduce-motion") {
                FocusView().environment(\.accessibilityReduceMotion, true)
            } else {
                FocusView()
            }
            #else
            FocusView()
            #endif
        }
    }
}
