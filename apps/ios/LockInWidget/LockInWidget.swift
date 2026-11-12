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
}

struct BrainProvider: TimelineProvider {
    func placeholder(in context: Context) -> BrainEntry {
        BrainEntry(date: .now, today: .init(total: 4, app: 2), watching: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (BrainEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : current())
    }

    /// Now, then a fresh brain just after midnight. The monitor extension asks for a reload
    /// whenever a new hour line is crossed, so nothing else needs scheduling.
    func getTimeline(in context: Context, completion: @escaping (Timeline<BrainEntry>) -> Void) {
        let now = current()
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
        let fresh = BrainEntry(date: tomorrow.addingTimeInterval(30), today: .init(total: 0, app: 0), watching: now.watching)
        completion(Timeline(entries: [now, fresh], policy: .after(tomorrow.addingTimeInterval(60))))
    }

    private func current() -> BrainEntry {
        BrainEntry(date: .now, today: BrainLevel.today(), watching: BrainLevel.isWatching())
    }
}

struct BrainWidgetView: View {
    let entry: BrainEntry

    private var stage: Int { entry.today.stage }
    private var reached: Int { entry.today.total }

    var body: some View {
        HStack(spacing: 10) {
            BrainCanvas(stage: stage)
                .frame(width: 138)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                if entry.watching {
                    Text("ON YOUR PHONE TODAY")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(BrainDrawing.levelColor(stage))
                    Text(entry.today.headline)
                        .font(.system(size: 38, weight: .black).width(.compressed))
                        .foregroundStyle(BrainDrawing.cream)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    hourBar
                    Text(entry.today.appLine.map { "\u{25B2} \($0)" } ?? " ")
                        .font(.system(size: 13, weight: .bold).width(.condensed))
                        .foregroundStyle(BrainDrawing.tongueColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
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
            ? "Your brain. \(entry.today.headline) on your phone today. \(entry.today.appLine ?? "")"
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
            let line = BrainDrawing.ecg(stage: stage, t: 0, width: size.width, mid: size.height / 2,
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
