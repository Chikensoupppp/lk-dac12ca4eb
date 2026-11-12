import SwiftUI
import WidgetKit

/// The brain widget: one medium widget. The brain rots as today's phone time crosses hour lines,
/// and one heavy app makes it worse. It never flatlines: at 7h+ the heartbeat is weak but there.
/// Widgets cannot animate on their own, so the heart trace is a still picture of the current beat.
@main
struct LockInWidgets: WidgetBundle {
    var body: some Widget { BrainWidget() }
}

struct BrainWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: BrainLevel.widgetKind, provider: BrainProvider()) { entry in
            BrainWidgetView(entry: entry)
        }
        .configurationDisplayName("Your brain")
        .description("Your brain rots as your phone time adds up today.")
        .supportedFamilies([.systemMedium])
    }
}

struct BrainEntry: TimelineEntry {
    let date: Date
    let today: BrainLevel.Today
    let watching: Bool
    /// Which frame this is. Each frame shifts the beat line and nudges the BPM, so the monitor
    /// looks alive when glanced at (widgets cannot animate on their own).
    let frame: Int
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
        BrainEntry(date: date, today: BrainLevel.today(now: date), watching: BrainLevel.isWatching(), frame: frame)
    }
}

struct BrainWidgetView: View {
    let entry: BrainEntry

    private var stage: Int { entry.today.stage }
    private var reached: Int { entry.today.total }

    private static let words = ["FRESH", "TIRED", "DIZZY", "FADING", "BEGGING", "ROTTEN"]
    /// Climbs with the hours; at "rotten" it is weak and slow, but never zero.
    private static let bpmBase = [72, 98, 126, 154, 188, 38]

    /// Drifts a few beats from frame to frame, like a real monitor.
    private var bpm: Int {
        let wobble = ((entry.frame &* 7919) % 7 + 7) % 7 - 3
        return Self.bpmBase[stage] + wobble
    }

    /// "4+ hrs on phone · 1 app 2h+"
    private var hoursLine: some View {
        let hours = entry.today.total == 0 ? "Under 1 hr on phone" : "\(entry.today.total)+ hrs on phone"
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
            BrainCanvas(stage: stage)
                .frame(width: 138)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                if entry.watching {
                    HStack(alignment: .firstTextBaseline) {
                        Text("YOUR BRAIN")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(1.2)
                        Spacer(minLength: 4)
                        Text("\u{2665} \(bpm) BPM")
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                            .monospacedDigit()
                    }
                    .foregroundStyle(BrainDrawing.levelColor(stage))
                    Text(Self.words[stage])
                        .font(.system(size: 38, weight: .black).width(.compressed))
                        .foregroundStyle(BrainDrawing.cream)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    hoursLine
                    hourBar
                        .padding(.top, 2)
                } else {
                    Text("YOUR BRAIN")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(BrainDrawing.green)
                    Text("Open Lock In and pick the apps to watch.")
                        .font(.system(size: 16, weight: .heavy).width(.condensed))
                        .foregroundStyle(BrainDrawing.cream)
                        .fixedSize(horizontal: false, vertical: true)
                }
                heartTrace
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .containerBackground(for: .widget) { BrainDrawing.bg }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.watching
            ? "Your brain is \(Self.words[stage].lowercased()), \(bpm) beats a minute. \(entry.today.headline) on your phone today. \(entry.today.appLine ?? "")"
            : "Your brain. Open Lock In and pick the apps to watch.")
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

    private var heartTrace: some View {
        Canvas { ctx, size in
            // Each frame starts the strip at a different point in the beat.
            let phase = Double(entry.frame % 97) * 0.37
            let line = BrainDrawing.ecg(stage: stage, t: phase, width: size.width, mid: size.height / 2,
                                        scale: 0.36, beat: 40, neverFlat: true)
            let color = BrainDrawing.traceColor(stage)
            var glow = ctx
            glow.addFilter(.blur(radius: 2.5))
            glow.stroke(line, with: .color(color.opacity(0.8)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            ctx.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        }
        .frame(height: 30)
    }
}
