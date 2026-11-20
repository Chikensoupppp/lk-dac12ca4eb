import SwiftUI
import UIKit
import RiveRuntime

/// What a finished session shows. It replaces CompletionCard and, for today's first finished session,
/// the separate streak screen. The picture is one Rive scene (apps/rive/complete): the ring closes
/// around the brain, the time lands, today fills in and, on a new day, sends a spark up into the
/// streak number, which rolls over. Buttons, the reminder offer and the VoiceOver text are SwiftUI.
/// Reduce Motion or Low Power Mode plays the scene already settled: nothing travels, the brain is still.
struct SessionDoneView: View {
    let info: CompletionInfo
    /// Keep the same task and length for next time (they are already saved; this just closes).
    let keep: () -> Void
    /// Close, then open the task picker.
    let change: () -> Void

    @StateObject private var scene: SessionDoneScene
    @State private var shown = false
    @State private var ringClosed = false
    @State private var rolled = false
    @State private var nudgeSet = false
    @State private var nudgeAsking = false

    init(info: CompletionInfo, keep: @escaping () -> Void, change: @escaping () -> Void) {
        self.info = info
        self.keep = keep
        self.change = change
        let still = motionLimited(UIAccessibility.isReduceMotionEnabled)
        _scene = StateObject(wrappedValue: SessionDoneScene(info: info, still: still))
    }

    var body: some View {
        if let clip = scene.clip {
            screen(clip)
        } else {
            // A build without complete.riv keeps the old card.
            CompletionCard(info: info, keep: keep, change: change)
        }
    }

    private func screen(_ clip: RiveClip) -> some View {
        ZStack {
            Done.paper.ignoresSafeArea()
            clip.view()
                .ignoresSafeArea()
                .accessibilityHidden(true)
            spokenSummary
            VStack(spacing: 0) {
                nudge
                Spacer(minLength: 0)
                footer
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
            .opacity(shown ? 1 : 0)
        }
        .preferredColorScheme(.light)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("completion-card")
        .sensoryFeedback(.success, trigger: ringClosed)
        .sensoryFeedback(.impact(weight: .light), trigger: rolled)
        .task { await run(clip) }
    }

    /// Times the haptics and the buttons to the scene's beats (see the timeline in apps/rive/complete/scene.rml).
    private func run(_ clip: RiveClip) async {
        if scene.still {
            clip.play()
            shown = true
            ringClosed = true
            return
        }
        // Let the cover finish sliding up first, so the ring closes where the user is looking.
        try? await Task.sleep(for: .milliseconds(350))
        clip.play()
        try? await Task.sleep(for: .milliseconds(770))
        ringClosed = true
        try? await Task.sleep(for: .milliseconds(830))
        withAnimation(.easeOut(duration: 0.35)) { shown = true }
        guard scene.newDay else { return }
        try? await Task.sleep(for: .milliseconds(900))
        rolled = true
    }

    /// What VoiceOver reads (and what the UI tests find): the scene's own text is drawn by Rive.
    private var spokenSummary: some View {
        VStack(alignment: .leading, spacing: 0) {
            if info.firstEver {
                Text("First lock-in done.")
                    .accessibilityIdentifier("first-lock-in-stamp")
            }
            Text("Focused \(FocusLog.format(minutes: info.minutes))")
                .accessibilityIdentifier("completion-minutes")
            if let task = info.task {
                Text("on \(task)")
            }
            Text(scene.streak == 1 ? "1 day streak" : "\(scene.streak) day streak")
        }
        .font(AppFont.font(13))
        .foregroundStyle(.clear)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    /// Optional: "Remind me tomorrow at 3:40 PM". Nothing is asked until it is tapped.
    @ViewBuilder private var nudge: some View {
        if let minute = info.nudgeMinute {
            Group {
                if nudgeSet {
                    Label("Reminder set for \(DailyNudge.timeText(minute: minute))", systemImage: "checkmark")
                        .accessibilityIdentifier("completion-nudge-set")
                } else {
                    Button {
                        nudgeAsking = true
                        Task {
                            nudgeSet = await DailyNudge.turnOn(minute: minute)
                            nudgeAsking = false
                        }
                    } label: {
                        Label("Remind me tomorrow at \(DailyNudge.timeText(minute: minute))", systemImage: "bell")
                    }
                    .disabled(nudgeAsking)
                    .accessibilityIdentifier("completion-nudge")
                }
            }
            .font(AppFont.font(14, .semibold))
            .foregroundStyle(Done.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 16)
            .frame(minHeight: 36)
            .background(Done.sheet, in: Capsule())
            .overlay(Capsule().strokeBorder(Done.edge, lineWidth: 1))
            .frame(minHeight: 44)
            .padding(.top, 4)
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            if let task = info.task {
                Text("Next time: \(task) · \(info.nextMinutes) min")
                    .font(AppFont.font(13, .medium))
                    .foregroundStyle(Done.soft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Button(action: keep) { Text("Keep it").lineLimit(1) }
                    .buttonStyle(DonePillStyle())
                    .accessibilityIdentifier("completion-keep")
                Button(action: change) {
                    Text("Change task")
                        .font(AppFont.font(16, .medium))
                        .foregroundStyle(Done.soft)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("completion-change")
            } else {
                Button(action: keep) { Text("Done").lineLimit(1) }
                    .buttonStyle(DonePillStyle())
                    .accessibilityIdentifier("completion-done")
            }
        }
    }
}

/// Builds the scene once and writes every view model value before its first frame, so the state
/// machine's entry choices (settled or played, roll or no roll) see real data.
final class SessionDoneScene: ObservableObject {
    let clip: RiveClip?
    let still: Bool
    /// True when this session started a new day of the streak, so the number rolls over.
    let newDay: Bool
    let streak: Int

    init(info: CompletionInfo, still: Bool) {
        let after = info.streakAfter ?? StreakStore.current()
        let before = info.streakBefore ?? after
        self.still = still
        newDay = after != before
        streak = after
        clip = RiveClip.make("complete", artboard: "Complete", stateMachine: "Complete",
                             alignment: .topCenter, autoPlay: false)
        guard let clip else { return }
        clip.set("focused", text: FocusLog.format(minutes: info.minutes))
        if let task = info.task {
            clip.set("lead", text: info.firstEver ? "first lock-in on " : "locked in on ")
            clip.set("task", text: task)
        } else {
            clip.set("lead", text: info.firstEver ? "your first lock-in" : "locked in")
            clip.set("task", text: "")
        }
        clip.set("streakFrom", text: "\(before)")
        clip.set("streakTo", text: "\(after)")
        clip.set("newDay", flag: newDay)
        clip.set("still", flag: still)
        // The scene's own buttons are for previews; the real ones are SwiftUI.
        clip.set("footer", number: 0)
        let week = StreakStore.around()
        for (index, done) in week.past.enumerated() {
            clip.set("p\(index + 1)", number: done ? 1 : 0)
        }
        for (index, letter) in week.letters.enumerated() where index != 3 {
            clip.set("l\(index + 1)", text: letter)
        }
    }
}

/// The scene's colors (apps/rive/complete): warm paper, ink, honey amber.
private enum Done {
    static let paper = Color(hex: 0xF6F3EC)
    static let sheet = Color(hex: 0xFDFBF7)
    static let edge = Color(hex: 0xEDE7DC)
    static let ink = Color(hex: 0x171513)
    static let soft = Color(hex: 0x6F6A60)
}

/// A black pill, full width, that presses in a little.
private struct DonePillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.font(17, .semibold))
            .foregroundStyle(Done.paper)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Done.ink, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
