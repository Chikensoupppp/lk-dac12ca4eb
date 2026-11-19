import SwiftUI

// Three "how it works" slides between the goals and the plan. Each one is a small paper toy the
// user plays with, so they learn by doing (Duolingo's first lesson, one sec's try-it-yourself):
// the real slider, a shop sign that flips to "BACK LATER", and a daily punch card.
// One short line each. No help paragraphs.

// MARK: One slide. You're in.

/// The real "slide to lock in" control, with the brain as the knob. A tap also works (VoiceOver,
/// UI tests); NEXT unlocks once it has been slid.
struct SlideToLockStep: View {
    let next: () -> Void
    @State private var x: CGFloat = 0
    @State private var locked = false
    @State private var hint: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    private let knob: CGFloat = 66

    var body: some View {
        PrintScaffold(step: 10, title: "One slide.\nYou\u{2019}re in.",
                      primaryTitle: "NEXT", primaryEnabled: locked || voiceOver, primaryAction: next) {
            Text(locked ? "That\u{2019}s how every session starts." : "Go on. Try it.")
                .font(PrintFont.mono(14))
                .foregroundStyle(Ink.ink)
            GeometryReader { proxy in
                let maxX = max(proxy.size.width - knob, 1)
                let progress = min(x / maxX, 1)
                ZStack(alignment: .leading) {
                    Capsule().fill(Ink.ink)
                    // The blue trail only shows once the knob really moves (not during the hint nudge).
                    Capsule().fill(Ink.blue).frame(width: knob + x).opacity(x > 0 ? 1 : 0)
                    Text("SLIDE TO LOCK IN")
                        .font(PrintFont.bold(17))
                        .tracking(2)
                        .foregroundStyle(Ink.paper)
                        .frame(maxWidth: .infinity)
                        .padding(.leading, knob)
                        .opacity(1 - progress)
                    Text("LOCKED IN")
                        .font(PrintFont.bold(17))
                        .tracking(2)
                        .foregroundStyle(Ink.paper)
                        .frame(maxWidth: .infinity)
                        .padding(.trailing, knob)
                        .opacity(locked ? 1 : 0)
                    Circle().fill(Ink.paper)
                        .frame(width: knob - 8, height: knob - 8)
                        .overlay(Image("BrainExact").resizable().scaledToFit().scaleEffect(1.25))
                        .overlay(alignment: .bottomTrailing) {
                            if locked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Ink.paper)
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(Ink.ink))
                                    .transition(.scale(scale: 0.3).combined(with: .opacity))
                            }
                        }
                        .padding(4)
                        .offset(x: x + hint)
                        .gesture(
                            DragGesture(minimumDistance: 2)
                                .onChanged { value in
                                    guard !locked else { return }
                                    hint = 0
                                    x = min(max(value.translation.width, 0), maxX)
                                }
                                .onEnded { _ in
                                    guard !locked else { return }
                                    if x > maxX * 0.7 { lock(maxX) }
                                    else { withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { x = 0 } }
                                }
                        )
                        .onTapGesture { lock(maxX) }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(locked ? "Locked in" : "Slide to lock in")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("onboarding-slide-knob")
                        .accessibilityAction { lock(maxX) }
                }
            }
            .frame(height: knob)
            .padding(.top, 30)
            ZStack {
                HStack {
                    Text("slide me \u{2192}")
                        .font(PrintFont.hand(30))
                        .foregroundStyle(Ink.blue)
                        .rotationEffect(.degrees(-3))
                        .padding(.leading, 20)
                        .opacity(locked ? 0 : 1)
                    Spacer()
                }
                HStack {
                    Spacer()
                    Text("see? easy.")
                        .font(PrintFont.hand(34))
                        .foregroundStyle(Ink.blue)
                        .rotationEffect(.degrees(-6))
                        .scaleEffect(locked ? 1 : 0.3)
                        .opacity(locked ? 1 : 0)
                        .padding(.trailing, 28)
                }
            }
            .padding(.top, 10)
            .accessibilityHidden(true)
        }
        .sensoryFeedback(.success, trigger: locked)
        .task {
            // A small nudge to the right now and then, until the user slides it.
            guard !effectiveReduceMotion(systemReduceMotion) else { return }
            while !locked {
                guard await printPause(1.6) else { return }
                guard !locked, x == 0 else { continue }
                withAnimation(.easeOut(duration: 0.22)) { hint = 24 }
                guard await printPause(0.22) else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) { hint = 0 }
            }
        }
    }

    private func lock(_ maxX: CGFloat) {
        guard !locked else { return }
        hint = 0
        let change = { x = maxX; locked = true }
        if effectiveReduceMotion(systemReduceMotion) { change() }
        else { withAnimation(.spring(response: 0.4, dampingFraction: 0.75), change) }
    }
}

// MARK: Swipe later.

/// The brand name as the payoff: a shop sign on a nail that flips from OPEN to BACK LATER.
/// Tap it, or it flips by itself.
struct BackLaterSignStep: View {
    let next: () -> Void
    @State private var angle: Double = 0
    @State private var swing: Double = 0
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var flipped: Bool { angle >= 90 }

    var body: some View {
        PrintScaffold(step: 11, title: "Swipe\nlater.", primaryTitle: "NEXT", primaryAction: next) {
            Text("The apps you pick stay shut till your timer\u{2019}s done.")
                .font(PrintFont.mono(14))
                .foregroundStyle(Ink.ink)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    SignStrings()
                        .stroke(Ink.ink, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 170, height: 54)
                    Circle().fill(Ink.ink).frame(width: 12, height: 12).offset(y: -6)
                }
                FlipSides(angle: angle, front: openSide, back: laterSide)
                    .frame(width: 270, height: 150)
            }
            .rotationEffect(.degrees(swing), anchor: .top)
            .frame(maxWidth: .infinity)
            .padding(.top, 26)
            .contentShape(Rectangle())
            .onTapGesture(perform: flip)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(flipped ? "Sign: back later" : "Sign: open")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("onboarding-sign")
            .accessibilityAction { flip() }
            HStack {
                Spacer()
                Text(flipped ? "your feed will survive." : "tap the sign")
                    .font(PrintFont.hand(28))
                    .foregroundStyle(Ink.blue)
                    .rotationEffect(.degrees(-4))
                    .contentTransition(.opacity)
                    .padding(.trailing, 16)
            }
            .padding(.top, 14)
            .accessibilityHidden(true)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: flipped)
        .task {
            guard await printPause(2.2) else { return }
            flip()
        }
    }

    private var openSide: some View {
        VStack(spacing: 0) {
            Text("OPEN")
                .font(PrintFont.head(84))
                .foregroundStyle(Ink.ink)
            Text("24/7, sadly")
                .font(PrintFont.hand(22))
                .foregroundStyle(Ink.red)
                .rotationEffect(.degrees(-3))
                .offset(y: -8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(Ink.receipt))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Ink.ink, lineWidth: 3))
        .shadow(color: .black.opacity(0.16), radius: 8, y: 6)
    }

    private var laterSide: some View {
        VStack(spacing: 0) {
            Text("BACK LATER")
                .font(PrintFont.head(58))
                .foregroundStyle(Ink.paper)
                .misprint()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("after your session")
                .font(PrintFont.hand(22))
                .foregroundStyle(Ink.sun)
                .rotationEffect(.degrees(-3))
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(Ink.blue))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Ink.ink, lineWidth: 3))
        .shadow(color: .black.opacity(0.16), radius: 8, y: 6)
    }

    private func flip() {
        guard !flipped else { return }
        if effectiveReduceMotion(systemReduceMotion) { angle = 180; return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) { angle = 180 }
        withAnimation(.easeOut(duration: 0.15)) { swing = 7 }
        Task {
            guard await printPause(0.15) else { return }
            withAnimation(.interpolatingSpring(stiffness: 45, damping: 3.5)) { swing = 0 }
        }
    }
}

/// Shows the front until the card is edge-on, then the back, so the flip never shows both.
private struct FlipSides<Front: View, Back: View>: View, Animatable {
    var angle: Double
    let front: Front
    let back: Back

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        ZStack {
            if angle < 90 { front } else { back.rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0)) }
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
    }
}

/// Two strings from the nail to the corners of the sign.
private struct SignStrings: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        return p
    }
}

// MARK: Stack up the days.

/// A coffee-shop punch card: one punch per day you lock in. Tap it to punch day one.
struct PunchCardStep: View {
    let next: () -> Void
    @State private var punched = false
    @State private var chipFalling = false
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private static let letters = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        PrintScaffold(step: 12, title: "Stack up\nthe days.", primaryTitle: "NEXT", primaryAction: next) {
            Text("One session a day keeps the scroll away.")
                .font(PrintFont.mono(14))
                .foregroundStyle(Ink.ink)
                .fixedSize(horizontal: false, vertical: true)
            card
                .padding(.top, 26)
            HStack {
                Text(punched ? "day 1. nice." : "punch day 1 \u{2191}")
                    .font(PrintFont.hand(28))
                    .foregroundStyle(Ink.blue)
                    .rotationEffect(.degrees(-3))
                    .contentTransition(.opacity)
                    .padding(.leading, 18)
                Spacer()
            }
            .padding(.top, 10)
            .accessibilityHidden(true)
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: punched)
        .task {
            let reduce = effectiveReduceMotion(systemReduceMotion)
            if !reduce {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
            }
            guard await printPause(3) else { return }
            punch()
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DAILY CARD")
                        .font(PrintFont.head(30))
                        .foregroundStyle(Ink.ink)
                    Text("1 session = 1 punch")
                        .font(PrintFont.mono(12))
                        .foregroundStyle(Ink.soft)
                }
                Spacer()
                Image("BrainExact").resizable().scaledToFit().frame(width: 48)
                    .rotationEffect(.degrees(punched ? -8 : 0))
                    .scaleEffect(punched ? 1.12 : 1)
                    .accessibilityHidden(true)
            }
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 6) {
                        hole(i)
                        Text(Self.letters[i])
                            .font(PrintFont.mono(12, .bold))
                            .foregroundStyle(Ink.soft)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Ink.ink.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 7)
        .rotationEffect(.degrees(-2))
        .contentShape(Rectangle())
        .onTapGesture(perform: punch)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(punched ? "Daily card, day one punched" : "Daily card. Punch day one")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("onboarding-punch-card")
        .accessibilityAction { punch() }
    }

    @ViewBuilder private func hole(_ i: Int) -> some View {
        let size: CGFloat = 34
        if i == 6 {
            Image(systemName: "star.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Ink.sun)
                .frame(width: size, height: size)
                .background(Circle().strokeBorder(Ink.sun, style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
        } else if i == 0 {
            ZStack {
                // Punched: a blue stamp with a check, so "done" reads at a glance.
                Circle().fill(Ink.blue)
                    .overlay(Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Ink.paper))
                    .scaleEffect(punched ? 1 : 0.2)
                    .opacity(punched ? 1 : 0)
                Circle().strokeBorder(Ink.blue, lineWidth: 3)
                    .opacity(punched ? 0 : 1)
                    .scaleEffect(pulse && !punched ? 1.12 : 1)
                // The paper chip falls out.
                Circle().fill(Color.white)
                    .overlay(Circle().stroke(Ink.ink.opacity(0.2), lineWidth: 1))
                    .frame(width: size * 0.8, height: size * 0.8)
                    .offset(x: chipFalling ? 14 : 0, y: chipFalling ? 120 : 0)
                    .rotationEffect(.degrees(chipFalling ? 40 : 0))
                    .opacity(punched && !chipFalling ? 1 : 0)
            }
            .frame(width: size, height: size)
        } else {
            Circle()
                .strokeBorder(Ink.ink.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                .frame(width: size, height: size)
        }
    }

    private func punch() {
        guard !punched else { return }
        if effectiveReduceMotion(systemReduceMotion) { punched = true; chipFalling = true; return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { punched = true }
        Task {
            guard await printPause(0.05) else { return }
            withAnimation(.easeIn(duration: 0.5)) { chipFalling = true }
        }
    }
}
