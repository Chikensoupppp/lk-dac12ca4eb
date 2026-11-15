import SwiftUI

/// What a finished session shows: the time that was focused, and an offer to keep the same task
/// for next time. The first ever one also gets the "First lock-in · Day 1" stamp.
struct CompletionInfo: Identifiable, Equatable {
    let id = UUID()
    let minutes: Int
    let task: String?
    let nextMinutes: Int
    let firstEver: Bool
}

struct CompletionCard: View {
    let info: CompletionInfo
    /// Keep the same task and length for next time (they are already saved; this just closes).
    let keep: () -> Void
    /// Close, then open the task picker.
    let change: () -> Void

    private var focusedText: String { FocusLog.format(minutes: info.minutes) }

    var body: some View {
        VStack(spacing: 16) {
            BrainCanvas(stage: 0, expression: .cheer)
                .frame(width: 110, height: 92)
                .accessibilityHidden(true)
            VStack(spacing: 6) {
                if info.firstEver {
                    Text("First lock-in done.")
                        .font(PrintFont.mono(13, .heavy))
                        .tracking(2)
                        .foregroundStyle(Ink.blue)
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
            if info.firstEver {
                Text("FIRST LOCK-IN · DAY 1")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Ink.blue)
                    .padding(8)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Ink.blue, lineWidth: 2))
                    .accessibilityIdentifier("first-lock-in-stamp")
            }
            Spacer(minLength: 4)
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
