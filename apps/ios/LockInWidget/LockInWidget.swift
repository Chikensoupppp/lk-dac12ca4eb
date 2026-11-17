import SwiftUI
import WidgetKit

/// The selected-apps widget: one medium widget. It shows today's time in the apps the user picked
/// to watch (not total phone use), as a big number and hour blocks. The mascot only looks a little
/// tired at most. It does not measure anyone's brain or health.
@main
struct LockInWidgets: WidgetBundle {
    var body: some Widget {
        BrainWidget()
        SessionLiveActivity()
    }
}

struct BrainWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: BrainLevel.widgetKind, provider: BrainProvider()) { entry in
            BrainWidgetView(entry: entry)
        }
        .configurationDisplayName("Selected apps")
        .description("Today's time in the apps you picked to watch.")
        .supportedFamilies([.systemMedium])
    }
}

struct BrainEntry: TimelineEntry {
    let date: Date
    let today: BrainLevel.Today
    let watching: Bool
    /// Which timeline frame this is (kept so each entry is distinct).
    let frame: Int
    /// Proof Check: Screen Time access was turned off after being on.
    var proofOff = false
}

struct BrainProvider: TimelineProvider {
    /// A new frame every 5 minutes, planned 3 hours ahead. Frames are drawn from one timeline, so
    /// they do not use up the widget's daily refresh budget.
    private static let step: TimeInterval = 5 * 60
    private static let frames = 36

    func placeholder(in context: Context) -> BrainEntry {
        BrainEntry(date: .now, today: .init(total: 4, app: 2), watching: true, frame: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (BrainEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: .now, frame: 0))
    }

    /// The monitor extension also asks for a reload whenever a new hour line is crossed. After
    /// midnight the stored level for the new day is empty, so later frames show a fresh brain.
    func getTimeline(in context: Context, completion: @escaping (Timeline<BrainEntry>) -> Void) {
        let start = Date.now
        let seed = Int(start.timeIntervalSince1970 / Self.step)
        let entries = (0...Self.frames).map { i in
            entry(at: start.addingTimeInterval(Double(i) * Self.step), frame: seed + i)
        }
        completion(Timeline(entries: entries, policy: .after(entries.last?.date ?? start)))
    }

    private func entry(at date: Date, frame: Int) -> BrainEntry {
        BrainEntry(date: date, today: BrainLevel.today(now: date), watching: BrainLevel.isWatching(), frame: frame,
                   proofOff: ProofCheck.offSince() != nil)
    }
}

struct BrainWidgetView: View {
    let entry: BrainEntry

    private var stage: Int { entry.today.stage }
    private var reached: Int { entry.today.total }

    /// The mascot never looks worse than a little tired.
    private var mascotStage: Int { min(stage, 1) }

    /// "4+ hrs in selected apps · 1 app 2h+"
    private var hoursLine: some View {
        let hours = entry.today.total == 0 ? "Under 1 hr in selected apps" : "\(entry.today.total)+ hrs in selected apps"
        var line = Text(hours).foregroundColor(BrainDrawing.cream)
        if entry.today.app >= 2 {
            line = line + Text(" \u{00B7} 1 app \(entry.today.app)h+").foregroundColor(BrainDrawing.tongueColor)
        }
        return line
            .font(.system(size: 13, weight: .bold).width(.condensed))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    var body: some View {
        HStack(spacing: 10) {
            BrainCanvas(stage: mascotStage)
                .frame(width: 138)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                if entry.watching {
                    Text("SELECTED APPS TODAY")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(BrainDrawing.green)
                    Text(entry.today.headline)
                        .font(.system(size: 38, weight: .black).width(.compressed))
                        .foregroundStyle(BrainDrawing.cream)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    hoursLine
                    hourBar
                        .padding(.top, 2)
                } else if entry.proofOff {
                    Text("SCREEN TIME OFF")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(BrainDrawing.alarm)
                    Text("Screen Time was turned off. Open SwipeLater to turn it back on.")
                        .font(.system(size: 16, weight: .heavy).width(.condensed))
                        .foregroundStyle(BrainDrawing.cream)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("SELECTED APPS")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(BrainDrawing.green)
                    Text("Open SwipeLater and pick the apps to watch.")
                        .font(.system(size: 16, weight: .heavy).width(.condensed))
                        .foregroundStyle(BrainDrawing.cream)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .containerBackground(for: .widget) { BrainDrawing.bg }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.watching
            ? "Time in your selected apps today: \(entry.today.headline). \(entry.today.appLine ?? "")"
            : entry.proofOff ? "Screen Time was turned off. Open SwipeLater to turn it back on."
            : "Selected apps. Open SwipeLater and pick the apps to watch.")
    }

    /// Seven blocks for 1 to 7 hours: green, then yellow at 4, red from 5.
    private var hourBar: some View {
        HStack(spacing: 3) {
            ForEach(1...7, id: \.self) { h in
                RoundedRectangle(cornerRadius: 3)
                    .fill(h <= reached ? (h >= 5 ? BrainDrawing.alarm : h == 4 ? BrainDrawing.yellow : BrainDrawing.green)
                                       : BrainDrawing.rgb(0x1E3A32))
                    .frame(height: 9)
            }
        }
    }
}
