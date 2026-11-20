import SwiftUI

/// What a finished session shows: the time that was focused, and an offer to keep the same task
/// for next time. The first ever one also gets the "First lock-in · Day 1" stamp.
struct CompletionInfo: Identifiable, Equatable {
    let id = UUID()
    let minutes: Int
    let task: String?
    let nextMinutes: Int
    let firstEver: Bool
    /// The time (minutes after midnight) to offer a daily reminder for; nil when it is already on.
    var nudgeMinute: Int? = nil
}

struct CompletionCard: View {
    let info: CompletionInfo
    /// Keep the same task and length for next time (they are already saved; this just closes).
    let keep: () -> Void
    /// Close, then open the task picker.
    let change: () -> Void

    private var focusedText: String { FocusLog.format(minutes: info.minutes) }

    @State private var nudgeSet = false
    @State private var nudgeAsking = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    // Rive clips play unless Reduce Motion is on or a build lacks the file; then the static art stays.
    private var animated: Bool { !effectiveReduceMotion(systemReduceMotion) }
    private var riveStamp: Bool { animated && info.firstEver && RiveClip.isBundled("stamp") }
    private var riveBrain: Bool { animated && !info.firstEver && RiveClip.isBundled("brain") }

    /// The top of the card: the stamp slams down on the first ever session, otherwise the brain cheers.
    @ViewBuilder private var hero: some View {
        if riveStamp {
            RiveStampView().frame(height: 150)
        } else if riveBrain {
            RiveBrainCheer().frame(width: 130, height: 130)
        } else {
            BrainCanvas(stage: 0, expression: .cheer).frame(width: 110, height: 92)
        }
    }

    /// Optional: "Remind me tomorrow at 3:40 PM". Nothing is asked until it is tapped.
    @ViewBuilder private func nudgeRow(minute: Int) -> some View {
        if nudgeSet {
            Label("Reminder set for \(DailyNudge.timeText(minute: minute))", systemImage: "checkmark")
                .font(PrintFont.mono(13))
                .foregroundStyle(Ink.soft)
                .frame(minHeight: 44)
                .accessibilityIdentifier("completion-nudge-set")
        } else {
            Button {
                nudgeAsking = true
                Task {
                    nudgeSet = await DailyNudge.turnOn(minute: minute)
                    nudgeAsking = false
                }
            } label: {
                Text("Remind me tomorrow at \(DailyNudge.timeText(minute: minute))")
                    .font(PrintFont.body(16))
                    .foregroundStyle(Ink.blue)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .disabled(nudgeAsking)
            .accessibilityIdentifier("completion-nudge")
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            hero
                .accessibilityHidden(true)
            VStack(spacing: 6) {
                if info.firstEver {
                    Text("First lock-in done.")
                        .font(PrintFont.mono(13, .heavy))
                        .tracking(2)
                        .foregroundStyle(Ink.blue)
                        // With the Rive stamp there is no text stamp below, so this line carries the badge id.
                        .accessibilityIdentifier(riveStamp ? "first-lock-in-stamp" : "first-lock-in-label")
                }
                Text("Focused \(focusedText)")
                    .font(PrintFont.head(48))
                    .foregroundStyle(Ink.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .accessibilityIdentifier("completion-minutes")
                if let task = info.task {
                    Text("on \(task)")
                        .font(PrintFont.body(18))
                        .foregroundStyle(Ink.soft)
                }
            }
            if info.firstEver, !riveStamp {
                Text("FIRST LOCK-IN · DAY 1")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Ink.blue)
                    .padding(8)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Ink.blue, lineWidth: 2))
                    .accessibilityIdentifier("first-lock-in-stamp")
            }
            Spacer(minLength: 4)
            if let minute = info.nudgeMinute {
                nudgeRow(minute: minute)
            }
            if let task = info.task {
                Text("Next time: \(task) · \(info.nextMinutes) min")
                    .font(PrintFont.mono(13))
                    .foregroundStyle(Ink.soft)
                    .multilineTextAlignment(.center)
                Button(action: keep) { Text("KEEP IT").lineLimit(1) }
                    .buttonStyle(PrintButtonStyle(fill: Ink.blue, text: Ink.paper))
                    .accessibilityIdentifier("completion-keep")
                Button("Change task", action: change)
                    .font(PrintFont.body(16))
                    .foregroundStyle(Ink.soft)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("completion-change")
            } else {
                Button(action: keep) { Text("DONE").lineLimit(1) }
                    .buttonStyle(PrintButtonStyle(fill: Ink.blue, text: Ink.paper))
                    .accessibilityIdentifier("completion-done")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Ink.paper.ignoresSafeArea())
        .preferredColorScheme(.light)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("completion-card")
    }
}
