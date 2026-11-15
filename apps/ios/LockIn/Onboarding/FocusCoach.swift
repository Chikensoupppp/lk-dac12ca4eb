import SwiftUI

/// The first-run coach: task, minutes, distracting apps, then one hold to start. Every step
/// points at a real control. Skip stays visible the whole time (FocusView draws it).
enum FocusCoachStep: Equatable {
    case task, minutes, apps, hold, celebrate

    var words: String {
        switch self {
        case .task: return "First — what are we working on?"
        case .minutes: return "Try 25. Long enough to count."
        case .apps: return "Which apps pull you away?"
        case .hold: return "Hold to start."
        case .celebrate: return "Locked in. Go get it."
        }
    }

    var expression: CoachExpression {
        switch self {
        case .task: return .lookDownRight
        case .minutes: return .lookDown
        case .apps: return .lookDown
        case .hold: return .keen
        case .celebrate: return .cheer
        }
    }
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
