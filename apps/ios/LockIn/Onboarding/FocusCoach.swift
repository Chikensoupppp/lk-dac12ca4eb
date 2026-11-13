import SwiftUI

enum FocusCoachStep: Equatable {
    case task, minutes, hold, celebrate

    var words: String {
        switch self {
        case .task: return "What are we working on?"
        case .minutes: return "Pick your focus time."
        case .hold: return "Hold to lock in."
        case .celebrate: return "You did it!"
        }
    }

    var expression: CoachExpression {
        switch self {
        case .task, .minutes: return .lookDown
        case .hold: return .keen
        case .celebrate: return .cheer
        }
    }
}

/// A non-blocking coach: the real Focus controls remain the interaction targets.
struct FocusCoach: View {
    let step: FocusCoachStep
    let reduceMotion: Bool
    @State private var confettiVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                BrainCanvas(stage: 0, expression: step.expression)
                    .frame(width: 92, height: 78)
                    .accessibilityHidden(true)
                Text(step.words)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Ink.ink)
                    .padding(12)
                    .background(Ink.receipt, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(BrainDrawing.outlineInk, lineWidth: 2))
            }
            if step == .celebrate {
                Text("FIRST LOCK-IN · DAY 1")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Ink.blue)
                    .padding(8)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Ink.blue, lineWidth: 2))
                    .accessibilityIdentifier("first-lock-in-stamp")
                    .overlay {
                        if !reduceMotion {
                            HStack(spacing: 10) {
                                ForEach(0..<6, id: \.self) { index in
                                    Circle()
                                        .fill(index.isMultiple(of: 2) ? Ink.sun : Ink.blue)
                                        .frame(width: 6, height: 6)
                                        .offset(y: confettiVisible ? (index.isMultiple(of: 2) ? -30 : 30) : 0)
                                        .opacity(confettiVisible ? 0 : 1)
                                }
                            }
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                            .onAppear { withAnimation(.easeOut(duration: 1)) { confettiVisible = true } }
                        }
                    }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("focus-coach")
    }
}
