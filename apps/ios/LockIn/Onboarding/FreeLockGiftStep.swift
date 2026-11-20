import SwiftUI

/// Right after the Plus offer, for people without Plus: the free Locked session they get every week
/// (`QuitRules.freeLockAvailable`). A blue riso ticket tips up onto the page, FREE is stamped on it,
/// the brain hops onto the stub, then "Unlimited with Plus". The dots ripple on each beat.
/// Reduce Motion shows it all at once.
struct FreeLockGiftStep: View {
    let next: () -> Void
    @State private var ticketIn = false
    @State private var stamped = false
    @State private var brainUp = false
    @State private var shine = false
    @State private var plusIn = false
    @State private var bob = false
    @State private var hop = false
    @State private var ripples: [FieldRipple] = []
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private static let stub: CGFloat = 86
    private static let softInk = Color(hex: 0x3F413B)

    var body: some View {
        PrintScaffold(step: OnboardingFlow.stepCount - 1, tag: "Free every week",
                      title: "One locked\nsession a week,\non us.", titleSize: 44,
                      primaryTitle: "GOT IT", primaryAction: next,
                      backdrop: AnyView(HalftoneField(fadeStart: 0.42, ripples: ripples))) {
            VStack(alignment: .leading, spacing: 28) {
                ticket
                    .padding(.top, 56)
                    .rotation3DEffect(.degrees(ticketIn ? 0 : 70), axis: (x: 1, y: 0, z: 0),
                                      anchor: .bottom, perspective: 0.55)
                    .rotationEffect(.degrees(ticketIn ? -2 : 6))
                    .offset(y: ticketIn ? 0 : 90)
                    .opacity(ticketIn ? 1 : 0)
                plusRow
                    .opacity(plusIn ? 1 : 0)
                    .offset(y: plusIn ? 0 : 14)
            }
            .padding(.top, 2)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: ticketIn)
        .sensoryFeedback(.impact(weight: .heavy), trigger: stamped)
        .task { await play() }
    }

    // MARK: The ticket

    private var ticket: some View {
        let shape = TicketShape(stub: Self.stub)
        return ZStack(alignment: .topLeading) {
            shape.fill(Ink.blue)
            Canvas { ctx, size in
                // Halftone dots, like the member card on the Plus slide.
                for x in stride(from: 4.5, to: size.width, by: 9) {
                    for y in stride(from: 4.5, to: size.height, by: 9) {
                        ctx.fill(Path(ellipseIn: CGRect(x: x - 1.4, y: y - 1.4, width: 2.8, height: 2.8)),
                                 with: .color(.white.opacity(0.15)))
                    }
                }
            }
            LinearGradient(colors: [.clear, .white.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 70)
                .frame(maxHeight: .infinity)
                .scaleEffect(y: 2)
                .rotationEffect(.degrees(18))
                .offset(x: shine ? 460 : -140)
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("ADMIT ONE")
                        .font(PrintFont.mono(10, .bold)).tracking(1.8)
                        .opacity(0.8)
                    Text("LOCKED\nSESSION")
                        .font(PrintFont.head(42))
                        .lineSpacing(-6)
                        .padding(.top, 4)
                    Spacer(minLength: 6)
                    // Short enough for one line beside the stub (two lines ran into the stamp).
                    Text("No quit button. Runs to the end.")
                        .font(PrintFont.body(13, .medium))
                        .opacity(0.92)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                Perforation()
                    .stroke(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .frame(width: 2)
                    .padding(.vertical, 16)
                VStack(spacing: 2) {
                    Text("1\u{00D7}")
                        .font(PrintFont.head(44))
                    Text("EVERY\nWEEK")
                        .font(PrintFont.mono(10, .bold)).tracking(1.4)
                        .multilineTextAlignment(.center)
                        .opacity(0.85)
                }
                .padding(.top, 24)
                .frame(width: Self.stub - 1)
            }
            .foregroundStyle(.white)
        }
        .frame(height: 172)
        .clipShape(shape)
        .overlay(shape.stroke(Ink.ink, lineWidth: 2))
        .background(shape.fill(Ink.ink).offset(y: 6))
        .overlay(alignment: .topTrailing) { freeStamp }
        .overlay(alignment: .topTrailing) { brain }
        .keyframeAnimator(initialValue: CGFloat(1), trigger: stamped) { view, s in
            view.scaleEffect(s)
        } keyframes: { _ in
            KeyframeTrack { CubicKeyframe(0.965, duration: 0.07); SpringKeyframe(1, duration: 0.35) }
        }
        .shadow(color: .black.opacity(0.22), radius: 14, y: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Free: one Locked session every week. No quit button, it runs to the end.")
        .accessibilityAddTraits(.isImage)
        .accessibilityIdentifier("free-lock-ticket")
    }

    /// Slams down on the ticket: big and faint, then flat on the paper with a heavy tap.
    private var freeStamp: some View {
        Stamp(text: "Free", color: Ink.red, size: 32, tilt: -12, fill: Ink.receipt.opacity(0.95))
            .rotationEffect(.degrees(stamped ? 0 : -10))
            .scaleEffect(stamped ? 1 : 2.3)
            .opacity(stamped ? 1 : 0)
            .offset(x: -(Self.stub + 12), y: 52)
            .accessibilityHidden(true)
    }

    /// Hops up onto the stub once FREE lands, then breathes. Tap it and it hops again.
    private var brain: some View {
        Image("BrainExact")
            .resizable()
            .scaledToFit()
            .frame(width: 84)
            .rotationEffect(.degrees(brainUp ? 6 : -14))
            .scaleEffect(hop ? 1.12 : (brainUp ? 1 : 0.7), anchor: .bottom)
            .offset(x: -6, y: brainUp ? (bob ? -54 : -50) : -6)
            .opacity(brainUp ? 1 : 0)
            .onTapGesture(perform: hopOnce)
            .accessibilityHidden(true)
    }

    // MARK: Unlimited with Plus

    private var plusRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "infinity")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Ink.ink)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Ink.sun))
                .overlay(Circle().strokeBorder(Ink.ink, lineWidth: 2))
                .background(Circle().fill(Ink.ink).offset(y: 3))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text("Unlimited with").font(PrintFont.bold(19)).foregroundStyle(Ink.ink)
                    PlusBadge()
                }
                Text("Lock every session, any day.")
                    .font(PrintFont.body(14, .medium))
                    .foregroundStyle(Self.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Unlimited with Plus. Lock every session, any day.")
    }

    // MARK: Motion

    private func hopOnce() {
        guard brainUp, !effectiveReduceMotion(systemReduceMotion) else { return }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) { hop = true }
        ripples.append(FieldRipple(origin: UnitPoint(x: 0.82, y: 0.42), start: .now, amp: 0.5, speed: 420))
        Task {
            guard await printPause(0.15) else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { hop = false }
        }
    }

    private func play() async {
        if effectiveReduceMotion(systemReduceMotion) {
            ticketIn = true
            stamped = true
            brainUp = true
            plusIn = true
            return
        }
        guard await printPause(0.3) else { return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) { ticketIn = true }
        guard await printPause(0.32) else { return }
        ripples.append(FieldRipple(origin: UnitPoint(x: 0.5, y: 0.6), start: .now, amp: 0.7, speed: 460))
        guard await printPause(0.3) else { return }
        withAnimation(.spring(response: 0.26, dampingFraction: 0.6)) { stamped = true }
        ripples.append(FieldRipple(origin: UnitPoint(x: 0.55, y: 0.55), start: .now, amp: 1.15))
        guard await printPause(0.32) else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { brainUp = true }
        withAnimation(.easeInOut(duration: 0.9)) { shine = true }
        guard await printPause(0.3) else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { plusIn = true }
        guard await printPause(0.8) else { return }
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { bob = true }
    }
}

/// A ticket: rounded corners, with a half-circle bite out of the top and bottom where the stub tears off.
private struct TicketShape: Shape {
    var stub: CGFloat
    var notch: CGFloat = 11
    var corner: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        let card = Path(roundedRect: rect, cornerRadius: corner, style: .continuous)
        let cut = rect.maxX - stub
        var bites = Path()
        bites.addEllipse(in: CGRect(x: cut - notch, y: rect.minY - notch, width: notch * 2, height: notch * 2))
        bites.addEllipse(in: CGRect(x: cut - notch, y: rect.maxY - notch, width: notch * 2, height: notch * 2))
        return card.subtracting(bites)
    }
}

/// The dashed tear line between the ticket and its stub.
private struct Perforation: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return p
    }
}
