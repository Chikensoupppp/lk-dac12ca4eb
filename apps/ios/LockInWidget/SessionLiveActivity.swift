import ActivityKit
import SwiftUI
import WidgetKit

/// The lock screen countdown and Dynamic Island. Same monitor look as the brain widget: dark
/// green-black, cream digits, green progress. The system ticks the timer by itself.
struct SessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            LockScreenCountdown(context: context)
                .activityBackgroundTint(BrainDrawing.bg)
                .activitySystemActionForegroundColor(BrainDrawing.cream)
        } dynamicIsland: { context in
            let range = context.attributes.startedAt...context.state.endsAt
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.locked ? "LOCKED" : "LOCKED IN", systemImage: "lock.fill")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundStyle(context.state.locked ? BrainDrawing.alarm : BrainDrawing.green)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("ends \(context.state.endsAt.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(BrainDrawing.cream.opacity(0.7))
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        CountdownDigits(range: range, stale: context.isStale, size: 40)
                        ProgressView(timerInterval: range, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                            .tint(BrainDrawing.green)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: "lock.fill")
                    .foregroundStyle(context.state.locked ? BrainDrawing.alarm : BrainDrawing.green)
            } compactTrailing: {
                Text(timerInterval: range, countsDown: true)
                    .monospacedDigit()
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(BrainDrawing.cream)
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "lock.fill")
                    .foregroundStyle(BrainDrawing.green)
            }
            .keylineTint(BrainDrawing.green)
        }
    }
}

private struct CountdownDigits: View {
    let range: ClosedRange<Date>
    let stale: Bool
    let size: CGFloat

    var body: some View {
        if stale {
            Text("DONE")
                .font(.system(size: size, weight: .black).width(.compressed))
                .foregroundStyle(BrainDrawing.green)
        } else {
            Text(timerInterval: range, countsDown: true)
                .font(.system(size: size, weight: .black).width(.compressed))
                .monospacedDigit()
                .foregroundStyle(BrainDrawing.cream)
                .multilineTextAlignment(.center)
        }
    }
}

private struct LockScreenCountdown: View {
    let context: ActivityViewContext<SessionActivityAttributes>

    private var range: ClosedRange<Date> { context.attributes.startedAt...context.state.endsAt }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(context.state.locked ? "LOCKED \u{00B7} NO QUITTING" : "LOCKED IN",
                      systemImage: "lock.fill")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(context.state.locked ? BrainDrawing.alarm : BrainDrawing.green)
                Spacer()
                Text(context.isStale ? "open Lock In"
                                     : "ends \(context.state.endsAt.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(BrainDrawing.cream.opacity(0.7))
            }
            HStack(alignment: .lastTextBaseline) {
                CountdownDigits(range: range, stale: context.isStale, size: 54)
                Spacer(minLength: 8)
                Text(context.isStale ? "Session done." : "Stay off\nyour phone.")
                    .font(.system(size: 15, weight: .heavy).width(.condensed))
                    .foregroundStyle(BrainDrawing.cream.opacity(0.85))
                    .multilineTextAlignment(.trailing)
            }
            ProgressView(timerInterval: range, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                .tint(BrainDrawing.green)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }
}
