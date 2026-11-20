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

    @State private var showReport = false
    /// The print pass that wipes the "doing the math" cover off the real slide.
    @State private var pass = 0.0
    @State private var coverFaded = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private static let titles = ["1\u{2013}2 hours\na day.", "3\u{2013}4 hours\na day.", "5\u{2013}6 hours\na day.", "7+ hours\na day."]
    private static let midpoints = [1.5, 3.5, 5.5, 7.5]

    /// The room between the slide's tag and the CONTINUE button: the screen minus the safe areas,
    /// the progress bars and Back (60), the tag (23), the scroll's bottom padding and fade (40) and
    /// the button area (68). Slide 5 is scaled down to fit it, so the last row never hides under
    /// the button, and the report is given exactly this height.
    private static var fitHeight: CGFloat {
        let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.windows.first
        let insets = window?.safeAreaInsets ?? .zero
        return max(UIScreen.main.bounds.height - insets.top - insets.bottom - 60 - 23 - 40 - 68, 420)
    }

    var body: some View {
        PrintScaffold(step: 4, tag: "What that means for your day", grain: true, primaryTitle: "CONTINUE", primaryAction: next) {
            if useReport {
                ZStack(alignment: .top) {
                    if showReport {
                        DeviceActivityReport(.dayBar, filter: ScreenTimeReport.lastWeek)
                            .frame(height: Self.fitHeight)
                            .frame(maxWidth: .infinity)
                    }
                    // Over the report while it draws: the same layout "doing the math", every number
                    // spinning, so no made-up number shows (it used to show the guess, then jump to
                    // the real one). A print pass then wipes it off the real slide.
                    DayBarSlide(hours: 0, headline: "Doing the\nmath\u{2026}", computing: true)
                        .scaleToFit(height: Self.fitHeight)
                        .frame(maxWidth: .infinity, minHeight: Self.fitHeight, alignment: .top)
                        .background(DayBarSlide.paper)
                        .modifier(PrintPassWipe(progress: pass))
                        .opacity(coverFaded ? 0 : 1)
                        .allowsHitTesting(pass < 1 && !coverFaded)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: pass >= 1 || coverFaded)
                // Only one Screen Time report on screen at a time: start after slide 3's is gone, then
                // give it a moment to draw under the cover.
                .task {
                    guard await printPause(1.0) else { return }
                    showReport = true
                    let still = effectiveReduceMotion(systemReduceMotion)
                    guard await printPause(still ? 1.0 : 1.5) else { return }
                    if still { withAnimation(.easeOut(duration: 0.3)) { coverFaded = true } }
                    else { withAnimation(.printPass) { pass = 1 } }
                }
            } else {
                let band = min(max(hoursIndex ?? 0, 0), 3)
                DayBarSlide(hours: Self.midpoints[band], headline: Self.titles[band])
                    .scaleToFit(height: Self.fitHeight)
            }
        }
    }
}
