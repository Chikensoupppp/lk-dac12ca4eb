import SwiftUI

/// The first-run coach. Every step is something the user does for real: pick the task, the
/// minutes, the apps, the weekly goal, a friend, the PC (only when one is on the Wi-Fi), then one
/// slide to start. The first session ends the lesson: the brain dares the user to open a locked
/// app and see the lock work. Features that cannot be tried yet (streak, report, Plus) are not
/// explained here; each shows up by itself when it first happens. Skip stays visible the whole time.
enum FocusCoachStep: Equatable {
    case task, minutes, apps, goal, partner, pc, hold, celebrate, tryIt, caught

    var words: String {
        switch self {
        case .task: return "Hi, I'm your brain! What are we working on?"
        case .minutes: return "25 minutes is a great start. Tap it."
        case .apps: return "Which apps steal your time? I'll lock them up."
        case .goal: return "How many hours a week? Pick one. I'll keep count."
        case .partner: return "Got a friend who keeps you honest? Add them now."
        case .pc: return "I see your PC! Want me to watch there too?"
        case .hold: return "Ready? Slide to lock in!"
        case .celebrate: return "We're locked in. Go get it!"
        case .tryIt: return "Your apps are locked. Go try one. I dare you!"
        case .caught: return "Ha! Locked tight. Now back to work!"
        }
    }

    var expression: CoachExpression {
        switch self {
        case .task: return .lookDownRight
        case .minutes, .apps, .goal: return .lookDown
        case .partner, .pc, .hold, .tryIt: return .keen
        case .celebrate, .caught: return .cheer
        }
    }

    /// Steps shown while the first session runs. They end when the session ends.
    var duringSession: Bool { self == .celebrate || self == .tryIt || self == .caught }
}

/// A non-blocking coach: the real Focus controls remain the interaction targets.
struct FocusCoach: View {
    let step: FocusCoachStep
    let reduceMotion: Bool
    var pressing = false
    var reward: String? = nil
    @State private var typed = ""

    private var words: String { reward ?? step.words }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                TimelineView(.animation(paused: reduceMotion || !pressing)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    BrainCanvas(stage: 0, expression: reward == nil ? step.expression : .cheer)
                        .offset(x: pressing && !reduceMotion ? sin(time * 65) * 3 : 0,
                                y: pressing && !reduceMotion ? cos(time * 49) * 2 : 0)
                }
                    .frame(width: 92, height: 78)
                    .accessibilityHidden(true)
                Text(words).hidden()
                    .overlay(alignment: .leading) { Text(typed) }
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Ink.ink)
                    .padding(12)
                    .background(Ink.receipt, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(BrainDrawing.outlineInk, lineWidth: 2))
                    .accessibilityLabel(words)
            }
            if let reward {
                Text(reward)
                    .font(.title2.weight(.black))
                    .foregroundStyle(Ink.ink)
                    .padding(8)
                    .background(Ink.sun, in: RoundedRectangle(cornerRadius: 8))
                    .rotationEffect(.degrees(reduceMotion ? 0 : -8))
                    .accessibilityIdentifier("coach-reward")
                    .transition(.opacity)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("focus-coach")
        .task(id: words + String(reduceMotion)) {
            typed = ""
            guard !reduceMotion else { typed = words; return }
            for character in words {
                do { try await Task.sleep(for: .milliseconds(28)) } catch { return }
                typed.append(character)
            }
        }
    }
}

extension View {
    /// An amber glow around a real control that the coach is talking about. No dimmed overlay.
    func coachGlow(_ on: Bool, reduceMotion: Bool) -> some View {
        modifier(CoachGlow(on: on, reduceMotion: reduceMotion))
    }
}

private struct CoachGlow: ViewModifier {
    let on: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content.overlay {
            if on {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(FocusPaper.amber, lineWidth: 3)
                    .padding(-4)
                    .shadow(color: FocusPaper.amber.opacity(0.25), radius: 6)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: on)
    }
}

/// The goal step's answers. One tap sets the real weekly goal (the same one the goal sheet edits).
struct CoachGoalChips: View {
    let choices: [Int]
    let current: Int?
    let pick: (Int) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8),
                                 count: dynamicTypeSize.isAccessibilitySize ? 2 : choices.count), spacing: 8) {
            ForEach(choices, id: \.self) { hours in
                let on = hours == current
                Button { pick(hours) } label: {
                    Text("\(hours)h")
                        .font(.headline.weight(.heavy).monospacedDigit())
                        .foregroundStyle(on ? FocusPaper.page : FocusPaper.ink)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(on ? FocusPaper.ink : FocusPaper.page))
                        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(FocusPaper.ink, lineWidth: 2))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(hours) hours a week")
                .accessibilityIdentifier("coach-goal-\(hours)")
            }
        }
    }
}

