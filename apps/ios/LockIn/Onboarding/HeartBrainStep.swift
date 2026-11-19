import DeviceActivity
import SwiftUI

/// Slide 5: what the hours mean (DayBarSlide, shared with the report extension). With Screen Time on,
/// the LockInReport extension draws it from the user's real daily average; the app itself never sees
/// that number. Without it, the app draws it from the guess.
/// (The file keeps its old name; the heart monitor is gone.)
struct HeartBrainStep: View {
    let hoursIndex: Int?
    /// True when the real-hours report is in this build and Screen Time is on.
    let useReport: Bool
    let next: () -> Void

    private static let titles = ["1\u{2013}2 hours\na day.", "3\u{2013}4 hours\na day.", "5\u{2013}6 hours\na day.", "7+ hours\na day."]
    private static let midpoints = [1.5, 3.5, 5.5, 7.5]

    var body: some View {
        PrintScaffold(step: 5, tag: "What that means for your day", grain: true, primaryTitle: "CONTINUE", primaryAction: next) {
            if useReport {
                DeviceActivityReport(.dayBar, filter: ScreenTimeReport.lastWeek)
                    .frame(height: 700)
                    .frame(maxWidth: .infinity)
            } else {
                let band = min(max(hoursIndex ?? 0, 0), 3)
                DayBarSlide(hours: Self.midpoints[band], headline: Self.titles[band])
            }
        }
    }
}
