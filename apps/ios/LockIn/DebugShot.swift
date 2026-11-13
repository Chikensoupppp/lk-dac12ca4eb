#if DEBUG
import SwiftUI

/// `-shot moods`: all six brain stages on one screen, for checking the drawing.
struct BrainMoodsSheet: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(0..<6, id: \.self) { stage in
                VStack(spacing: 2) {
                    BrainCanvas(stage: stage).frame(height: 150)
                    Text("\(stage)").font(.caption.monospaced()).foregroundStyle(BrainDrawing.cream)
                }
            }
        }
        .padding(12)
        .frame(maxHeight: .infinity)
        .background(BrainDrawing.bg.ignoresSafeArea())
    }
}

/// Debug builds only: `-shot <name>` opens one screen straight away, with sample data, so the
/// CI screenshot run (.github/workflows/ios-screens.yml) can photograph every screen.
/// Names: ob-1 ... ob-12 (onboarding slides), idle, active, quit, quit-type, locked, proof,
/// keys, goals, report, streak, plus, restrictions.
enum DebugShot {
    static let name: String? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-shot"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }()

    static var onboardingStep: Int? {
        guard let name, name.hasPrefix("ob-") else { return nil }
        return Int(name.dropFirst(3))
    }

    /// Sample focus history: last week hit a 4-hour goal, the week before had less, and this
    /// week has a start. The app is reinstalled before each shot, so this runs on empty data.
    static func seed() {
        let cal = FocusLog.calendar
        let thisWeek = FocusLog.weekStart(.now)
        func day(_ weekOffset: Int, _ dayOffset: Int) -> Date {
            cal.date(byAdding: .day, value: weekOffset * 7 + dayOffset, to: thisWeek)!.addingTimeInterval(12 * 3600)
        }
        for (d, minutes) in [(0, 45), (1, 90), (2, 25), (4, 60), (5, 45), (6, 25)] {
            FocusLog.recordFinished(minutes: minutes, at: day(-1, d))
        }
        FocusLog.recordQuit(at: day(-1, 3))
        for (d, minutes) in [(1, 60), (3, 45), (4, 45)] {
            FocusLog.recordFinished(minutes: minutes, at: day(-2, d))
        }
        for (d, minutes) in [(0, 50), (1, 25), (2, 45)] where day(0, d) <= .now {
            FocusLog.recordFinished(minutes: minutes, at: day(0, d))
        }
        UserDefaults.standard.set([FocusLog.weekKey(day(-1, 0)): 4], forKey: "lockin.goal.byWeek.v1")
    }
}
#endif
