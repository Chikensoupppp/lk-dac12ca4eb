import SwiftUI

// Three short "how it works" slides, shown after the goals and before the plan.
// One paper object per slide, one short line each. No help paragraphs.

// MARK: Slide to lock in

struct SlideToLockStep: View {
    let next: () -> Void
    @State private var slid = false
    @State private var noteShown = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        PrintScaffold(step: 10, title: "Slide to\nlock in.", primaryTitle: "NEXT", primaryAction: next) {
            Text("One slide starts your timer.")
                .font(PrintFont.mono(14))
                .foregroundStyle(Ink.ink)
            GeometryReader { proxy in
                let knob: CGFloat = 64
                ZStack(alignment: .leading) {
                    Capsule().fill(Ink.ink)
                    Text("SLIDE TO LOCK IN")
                        .font(PrintFont.bold(17))
                        .tracking(2)
                        .foregroundStyle(Ink.paper)
                        .frame(maxWidth: .infinity)
                        .padding(.leading, knob)
                        .opacity(slid ? 0.25 : 1)
                    Circle().fill(Ink.paper)
                        .frame(width: knob - 8, height: knob - 8)
                        .overlay(Image(systemName: slid ? "lock.fill" : "arrow.right")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Ink.ink))
                        .padding(4)
                        .offset(x: slid ? proxy.size.width - knob : 0)
                }
            }
            .frame(height: 64)
            .padding(.top, 36)
            .accessibilityHidden(true)
            HStack {
                Spacer()
                Text("that\u{2019}s it.")
                    .font(PrintFont.hand(34))
                    .foregroundStyle(Ink.blue)
                    .rotationEffect(.degrees(-5))
                    .scaleEffect(noteShown ? 1 : 0.3)
                    .opacity(noteShown ? 1 : 0)
                    .padding(.trailing, 24)
            }
            .padding(.top, 8)
        }
        .task {
            if effectiveReduceMotion(systemReduceMotion) { slid = true; noteShown = true; return }
            guard await printPause(0.6) else { return }
            withAnimation(.easeInOut(duration: 0.9)) { slid = true }
            guard await printPause(1.0) else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { noteShown = true }
        }
    }
}

// MARK: Distractions wait

struct AppsWaitStep: View {
    let next: () -> Void
    @State private var locked = 0
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private static let rows: [(name: String, symbol: String)] = [
        ("Social", "bubble.left.and.bubble.right.fill"), ("Video", "play.rectangle.fill"), ("Games", "gamecontroller.fill")
    ]

    var body: some View {
        PrintScaffold(step: 11, title: "Distractions\nwait outside.", primaryTitle: "NEXT", primaryAction: next) {
            Text("The apps you pick stay shut until the timer ends.")
                .font(PrintFont.mono(14))
                .foregroundStyle(Ink.ink)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                ForEach(Array(Self.rows.enumerated()), id: \.offset) { i, row in
                    let on = i < locked
                    HStack(spacing: 14) {
                        Image(systemName: row.symbol)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(on ? Ink.ink.opacity(0.35) : Ink.ink)
                            .frame(width: 32)
                        Text(row.name.uppercased())
                            .font(PrintFont.bold(24))
                            .tracking(1.5)
                            .foregroundStyle(on ? Ink.ink.opacity(0.35) : Ink.ink)
                        Spacer()
                        Image(systemName: on ? "lock.fill" : "lock.open")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(on ? Ink.blue : Ink.ink.opacity(0.3))
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 64)
                    .overlay(alignment: .bottom) { Rectangle().fill(Ink.ink.opacity(0.12)).frame(height: 1) }
                }
            }
            .background(Ink.receipt)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.14), radius: 10, y: 6)
            .padding(.top, 24)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Social, video and games are locked until the timer ends")
        }
        .task {
            if effectiveReduceMotion(systemReduceMotion) { locked = Self.rows.count; return }
            for i in 1...Self.rows.count {
                guard await printPause(0.6) else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { locked = i }
            }
        }
    }
}

// MARK: Come back tomorrow

struct ComeBackStep: View {
    let next: () -> Void
    @State private var days = 0
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private static let letters = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        PrintScaffold(step: 12, title: "Come back\ntomorrow.", primaryTitle: "NEXT", primaryAction: next) {
            Text("Short sessions add up. A daily reminder keeps you going.")
                .font(PrintFont.mono(14))
                .foregroundStyle(Ink.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 8) {
                        Text(Self.letters[i])
                            .font(PrintFont.mono(13, .bold))
                            .foregroundStyle(Ink.soft)
                        Circle()
                            .strokeBorder(Ink.ink, lineWidth: 2.5)
                            .frame(width: 38, height: 38)
                            .overlay {
                                if i < days {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 26, weight: .black))
                                        .foregroundStyle(Ink.blue)
                                        .offset(x: 3, y: -4)
                                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 30)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("A week of days, checked off one by one")
        }
        .task {
            if effectiveReduceMotion(systemReduceMotion) { days = 5; return }
            for i in 1...5 {
                guard await printPause(0.45) else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { days = i }
            }
        }
    }
}
