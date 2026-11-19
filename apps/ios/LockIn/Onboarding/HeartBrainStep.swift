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

    private static let titles = ["1\u{2013}2 hours\na day.", "3\u{2013}4 hours\na day.", "5\u{2013}6 hours\na day.", "7+ hours\na day."]
    private static let midpoints = [1.5, 3.5, 5.5, 7.5]

    var body: some View {
        PrintScaffold(step: 5, tag: "What that means for your day", grain: true, primaryTitle: "CONTINUE", primaryAction: next) {
            if useReport {
                ZStack(alignment: .top) {
                    // Under the report while it draws, so the slide is never blank: the same slide from
                    // the guess (or a typical day), marked as such. The report covers it once drawn.
                    let band = min(max(hoursIndex ?? 1, 0), 3)
                    DayBarSlide(hours: Self.midpoints[band], headline: Self.titles[band])
                        .overlay(alignment: .topTrailing) {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(hoursIndex == nil ? "A TYPICAL DAY" : "YOUR GUESS")
                                    .font(PrintFont.mono(11, .bold)).tracking(1.2)
                                Text("REAL NUMBERS LOADING\u{2026}")
                                    .font(PrintFont.mono(8.5, .semibold))
                            }
                            .foregroundStyle(Ink.ink)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Ink.sun))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Ink.ink, lineWidth: 2))
                            .background(RoundedRectangle(cornerRadius: 10).fill(Ink.ink).offset(y: 3))
                            .rotationEffect(.degrees(5))
                            .offset(x: -8, y: 166)
                            .accessibilityElement(children: .combine)
                        }
                    if showReport {
                        DeviceActivityReport(.dayBar, filter: ScreenTimeReport.lastWeek)
                            .frame(height: 700)
                            .frame(maxWidth: .infinity)
                            .transition(.opacity)
                    }
                }
                // Only one Screen Time report on screen at a time: start after slide 4's is gone.
                .task {
                    guard await printPause(1.0) else { return }
                    withAnimation(.easeOut(duration: 0.3)) { showReport = true }
                }
            } else {
                let band = min(max(hoursIndex ?? 0, 0), 3)
                DayBarSlide(hours: Self.midpoints[band], headline: Self.titles[band])
            }
        }
    }
}
