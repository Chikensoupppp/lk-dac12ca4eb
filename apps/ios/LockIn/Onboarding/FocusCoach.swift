import SwiftUI

/// The first-run coach: task, minutes, distracting apps, then one hold to start. Every step
/// points at a real control. Skip stays visible the whole time (FocusView draws it).
enum FocusCoachStep: Equatable {
    case task, minutes, apps, mode, goal, partner, pc, live, widget, streak, report, quit, plus, hold, celebrate

    var words: String {
        switch self {
        case .task: return "Hi, I'm your brain! What are we working on?"
        case .minutes: return "25 minutes is a great start. Tap it."
        case .apps: return "Which apps steal your time? I'll lock them up."
        case .mode: return "Locked mode hides the quit button. For brave days."
        case .goal: return "Pick a weekly goal. I'll keep count for you."
        case .partner: return "Bring a friend. They cheer you on, and can let you out."
        case .pc: return "On a PC too? Connect it, and I'll keep watch there."
        case .live: return "I stay on your lock screen. Peek anytime."
        case .widget: return "Put me on your home screen. I'll watch your apps."
        case .streak: return "One session a day grows your streak. Easy wins!"
        case .report: return "Every Sunday, I'll show you how your week went."
        case .quit: return "Need out? Hold to quit, or ask your friend. No judgment."
        case .plus: return "Want more? Plus unlocks Locked mode and PC pairing."
        case .hold: return "Ready? Slide to lock in!"
        case .celebrate: return "We're locked in. Go get it!"
        }
    }

    /// The steps after the first three, in order. The tour card shows each with Next.
    static let tour: [FocusCoachStep] = [.mode, .goal, .partner, .pc, .live, .widget, .streak, .report, .quit, .plus]

    var expression: CoachExpression {
        switch self {
        case .task: return .lookDownRight
        case .minutes: return .lookDown
        case .apps: return .lookDown
        case .mode, .goal, .partner, .pc, .live, .widget, .streak, .report, .quit, .plus: return .keen
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

/// A small drawn picture of a feature that is not on this screen, so the brain can show it.
struct TourPreview: View {
    let step: FocusCoachStep

    var body: some View {
        switch step {
        case .live:
            HStack(spacing: 10) {
                Image("BrainExact").resizable().scaledToFit().frame(width: 34)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Studying").font(.caption).foregroundStyle(FocusPaper.page.opacity(0.7))
                    Text("24:31").font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(FocusPaper.page)
                }
                Spacer()
            }
            .padding(12).background(RoundedRectangle(cornerRadius: 22).fill(FocusPaper.ink))
        case .widget:
            HStack {
                Image("BrainExact").resizable().scaledToFit().frame(width: 60)
                    .padding(14).background(RoundedRectangle(cornerRadius: 24).fill(FocusPaper.inset))
                    .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(FocusPaper.line))
                Spacer()
            }
        case .streak:
            HStack(spacing: 8) {
                Image(systemName: "flame.fill").font(.system(size: 34)).foregroundStyle(FocusPaper.amber)
                Text("3 days").font(.title2.weight(.black)).foregroundStyle(FocusPaper.ink)
                Spacer()
            }
        case .report:
            HStack(alignment: .bottom, spacing: 7) {
                ForEach(Array([0.4, 0.7, 0.55, 0.9, 0.3, 0.0, 0.0].enumerated()), id: \.offset) { _, h in
                    RoundedRectangle(cornerRadius: 4).fill(h > 0 ? FocusPaper.amber : FocusPaper.line)
                        .frame(width: 24, height: max(6, 54 * h))
                }
                Spacer()
            }
            .frame(height: 56, alignment: .bottom)
        case .quit:
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill").font(.system(size: 28)).foregroundStyle(FocusPaper.ink)
                Text("Hold to quit").font(.headline).foregroundStyle(FocusPaper.ink)
                Spacer()
            }
        case .plus:
            HStack(spacing: 8) {
                Text("PLUS").font(.caption.weight(.heavy)).tracking(2).foregroundStyle(FocusPaper.page)
                    .padding(.horizontal, 10).padding(.vertical, 5).background(Capsule().fill(FocusPaper.ink))
                Text("Locked mode, PC pairing").font(.subheadline).foregroundStyle(FocusPaper.secondary)
                Spacer()
            }
        default:
            EmptyView()
        }
    }
}

/// The card for the tour steps: the brain says one line, Next moves on. It sits at the bottom, or at
/// the top when the control being explained is in the lower half (Locked mode).
struct TourCard: View {
    let step: FocusCoachStep
    let number: Int
    let total: Int
    let reduceMotion: Bool
    let next: () -> Void
    let skip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image("BrainExact").resizable().scaledToFit().frame(width: 54)
                    .accessibilityHidden(true)
                Text(step.words)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(FocusPaper.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            TourPreview(step: step)
                .padding(.leading, 64)
                .accessibilityHidden(true)
            HStack(spacing: 8) {
                Text("\(number)/\(total)").font(.caption).foregroundStyle(FocusPaper.secondary)
                Spacer()
                Button("Skip tour", action: skip)
                    .font(.caption)
                    .foregroundStyle(FocusPaper.secondary)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("skip-tour")
                Button(action: next) {
                    Text("Next").font(.footnote.weight(.bold))
                        .foregroundStyle(FocusPaper.page)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(FocusPaper.ink))
                }
                .accessibilityIdentifier("coach-next")
            }
            .padding(.leading, 64)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 22).fill(FocusPaper.page))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(FocusPaper.line, lineWidth: 1.5))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tour-card")
    }
}
