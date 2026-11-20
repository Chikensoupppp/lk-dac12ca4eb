import SwiftUI
import UIKit

/// What a finished session shows. It replaces CompletionCard and, for today's first finished session,
/// the separate streak screen. The ring from the Focus dial closes around the brain, the time lands,
/// today fills in and, on a new day, sends a spark up into the streak number, which rolls over.
///
/// The design was approved as a Rive render (apps/rive/complete, same coordinates and timing). It is
/// drawn natively because Rive's free plan puts a splash screen over every runtime file.
/// Everything is laid out on a 390 x 844 pt design frame scaled to the screen (`s`), top aligned.
/// Reduce Motion or Low Power Mode shows the finished state at once: nothing travels, nothing drifts.
struct SessionDoneView: View {
    let info: CompletionInfo
    /// Keep the same task and length for next time (they are already saved; this just closes).
    let keep: () -> Void
    /// Close, then open the task picker.
    let change: () -> Void

    private let still: Bool
    private let before: Int
    private let after: Int
    private let letters: [String]
    private let past: [Bool]

    @State private var m = Motion()
    @State private var closed = false
    @State private var rolled = false
    /// Waves through the dots: one when today fills in, one when the streak rolls over.
    @State private var ripples: [FieldRipple] = []
    @State private var nudgeSet = false
    @State private var nudgeAsking = false

    init(info: CompletionInfo, keep: @escaping () -> Void, change: @escaping () -> Void) {
        self.info = info
        self.keep = keep
        self.change = change
        still = motionLimited(UIAccessibility.isReduceMotionEnabled)
        let streakAfter = info.streakAfter ?? StreakStore.current()
        after = streakAfter
        before = info.streakBefore ?? streakAfter
        let week = StreakStore.around()
        letters = week.letters
        past = week.past
    }

    /// This session started a new day of the streak, so the number rolls over.
    private var newDay: Bool { after != before }

    var body: some View {
        ZStack {
            GeometryReader { geo in
                let s = min(geo.size.width / 390, geo.size.height / 844)
                ZStack(alignment: .top) {
                    Done.paper
                    // The onboarding's moving halftone dots over the whole screen (Brandon: "dots are
                    // everywhere"). A start above the top edge means the fade is already done at y = 0.
                    // Still under Reduce Motion.
                    HalftoneField(fadeStart: -0.36, ripples: ripples)
                        .frame(width: geo.size.width, height: geo.size.height)
                    stage(s)
                        .frame(width: 390 * s, height: 844 * s)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                nudge
                Spacer(minLength: 0)
                footer
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
            .opacity(m.footer ? 1 : 0)
        }
        .preferredColorScheme(.light)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("completion-card")
        .sensoryFeedback(.success, trigger: closed)
        .sensoryFeedback(.impact(weight: .light), trigger: rolled)
        .task {
            if still {
                settle()
            } else {
                do { try await play() } catch {}
            }
        }
    }

    // MARK: - The picture

    private func stage(_ s: CGFloat) -> some View {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
        return ZStack {
            // Warm bloom behind the ring when it closes.
            Circle()
                .stroke(Done.bloom, lineWidth: 30 * s)
                .frame(width: 252 * s, height: 252 * s)
                .blur(radius: 11 * s)
                .opacity(m.glow)
                .position(p(195, 262))
                .accessibilityHidden(true)

            // The dial: face, track, and the honey ring that draws itself closed.
            ZStack {
                Circle()
                    .fill(Done.face)
                    .frame(width: 238 * s, height: 238 * s)
                    .shadow(color: Done.shadow.opacity(0.18), radius: 15 * s, y: 16 * s)
                Circle()
                    .stroke(Done.track, lineWidth: 11 * s)
                    .frame(width: 250 * s, height: 250 * s)
                Circle()
                    .trim(from: 0, to: m.ring)
                    .rotation(.degrees(-90))
                    .stroke(Done.honey, style: StrokeStyle(lineWidth: 11 * s, lineCap: .round))
                    .frame(width: 250 * s, height: 250 * s)
                    .opacity(m.ring > 0.001 ? 1 : 0)
            }
            .scaleEffect(m.pop)
            .position(p(195, 262))
            .accessibilityHidden(true)

            // Spark burst: scaling the group pushes every dash outward.
            ZStack {
                ForEach(0..<10, id: \.self) { i in
                    Capsule()
                        .fill(i.isMultiple(of: 2) ? Done.amber : Done.rose)
                        .frame(width: 5 * s, height: (i.isMultiple(of: 2) ? 15 : 11) * s)
                        .offset(y: -(i.isMultiple(of: 2) ? 150 : 146) * s)
                        .rotationEffect(.degrees(18 + Double(i) * 36))
                }
            }
            .scaleEffect(m.burstScale)
            .opacity(m.burst)
            .position(p(195, 262))
            .accessibilityHidden(true)

            // The brain sits in the dial and hops when the ring closes.
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: still)) { timeline in
                BrainCanvas(stage: 0,
                            t: still ? 0 : timeline.date.timeIntervalSinceReferenceDate,
                            expression: m.cheer ? .cheer : .normal)
            }
            .frame(width: 188 * s, height: 155 * s)
            .scaleEffect(x: 2 - m.squash, y: m.squash, anchor: .bottom)
            .offset(y: m.hop * s)
            .position(p(195, 264))
            .accessibilityHidden(true)

            // The time, and what it was spent on.
            Text(FocusLog.format(minutes: info.minutes))
                .font(AppFont.font(66 * s, .heavy))
                .tracking(-2.5 * s)
                .foregroundStyle(Done.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: 350 * s)
                .accessibilityLabel("Focused \(FocusLog.format(minutes: info.minutes))")
                .accessibilityIdentifier("completion-minutes")
                .opacity(m.headline ? 1 : 0)
                .offset(y: m.headline ? 0 : 18 * s)
                .position(p(195, 446))

            subline(s)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 342 * s)
                .accessibilityIdentifier(info.firstEver ? "first-lock-in-stamp" : "completion-task")
                .opacity(m.subline ? 1 : 0)
                .offset(y: m.subline ? 0 : 14 * s)
                .position(p(195, 494))

            panel(s)
                .opacity(m.panel ? 1 : 0)
                .offset(y: m.panel ? 0 : 26 * s)
                .position(p(195, 596))

            // The spark today sends up into the counter, and the ring where it lands.
            Circle()
                .fill(Done.amber)
                .frame(width: 11 * s, height: 11 * s)
                .shadow(color: Done.bloom, radius: 6 * s)
                .opacity(m.spark)
                .modifier(Arc(progress: m.flight, from: p(195, 606), control: p(116, 440), to: p(53, 563)))
                .accessibilityHidden(true)
            Circle()
                .stroke(Done.amber, lineWidth: 2.5 * s)
                .frame(width: 22 * s, height: 22 * s)
                .scaleEffect(m.impact ? 2.8 : 0.5)
                .opacity(m.impactOpacity)
                .position(p(53, 563))
                .accessibilityHidden(true)
        }
    }

    private func subline(_ s: CGFloat) -> Text {
        let lead: String
        if info.task != nil {
            lead = info.firstEver ? "first lock-in on " : "locked in on "
        } else {
            lead = info.firstEver ? "your first lock-in" : "locked in"
        }
        return Text(lead).font(AppFont.font(18 * s, .medium)).foregroundStyle(Done.soft)
            + Text(info.task ?? "").font(AppFont.font(18 * s, .semibold)).foregroundStyle(Done.ink)
    }

    /// The week panel: streak number on top, seven days below with today in the middle.
    private func panel(_ s: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26 * s, style: .continuous)
                .fill(Done.sheet)
                .overlay(RoundedRectangle(cornerRadius: 26 * s, style: .continuous).strokeBorder(Done.edge, lineWidth: 1))
                .shadow(color: Done.shadow.opacity(0.14), radius: 11 * s, y: 10 * s)

            HStack(alignment: .firstTextBaseline, spacing: 7 * s) {
                Text("\(m.streak)")
                    .font(AppFont.font(30 * s, .heavy))
                    .tracking(-0.5 * s)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(m.streak)))
                Text("day streak")
                    .font(AppFont.font(17 * s, .semibold))
            }
            .foregroundStyle(Done.ink)
            .scaleEffect(m.rowPop, anchor: .leading)
            .frame(width: 302 * s, alignment: .leading)
            .offset(y: -33 * s)

            ForEach(0..<7, id: \.self) { i in
                bead(i, s)
                    .scaleEffect(m.days > i ? 1 : 0.6)
                    .opacity(m.days > i ? 1 : 0)
                    .offset(x: beadX(i) * s, y: 10 * s)
                Text(i == 3 ? "Today" : letters[i])
                    .font(AppFont.font(12 * s, i == 3 ? .heavy : .semibold))
                    .foregroundStyle(i == 3 ? Done.ink : Done.soft)
                    .opacity(m.days > i ? 1 : 0)
                    .offset(x: beadX(i) * s, y: 41 * s)
            }
        }
        .frame(width: 342 * s, height: 140 * s)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(after == 1 ? "1 day streak" : "\(after) day streak")
    }

    private func beadX(_ i: Int) -> CGFloat { -136 + CGFloat(i) * 45.333 }

    @ViewBuilder private func bead(_ i: Int, _ s: CGFloat) -> some View {
        if i < 3 {
            if past[i] {
                filledBead(s)
            } else {
                Circle().strokeBorder(Done.hairline, lineWidth: 2 * s).frame(width: 28 * s, height: 28 * s)
            }
        } else if i == 3 {
            ZStack {
                Circle()
                    .fill(Done.bloom.opacity(0.25))
                    .frame(width: 42 * s, height: 42 * s)
                    .scaleEffect(m.halo ? 1.7 : 1)
                    .opacity(m.halo ? 0 : 1)
                Circle().strokeBorder(Done.amber, lineWidth: 2 * s).frame(width: 30 * s, height: 30 * s)
                Circle().fill(Done.amber).frame(width: 30 * s, height: 30 * s).scaleEffect(m.todayFill)
                CheckMark()
                    .trim(from: 0, to: m.check)
                    .stroke(Done.paper, style: StrokeStyle(lineWidth: 3.2 * s, lineCap: .round, lineJoin: .round))
                    .frame(width: 30 * s, height: 30 * s)
            }
        } else {
            Circle().strokeBorder(Done.hairline, lineWidth: 2 * s).frame(width: 28 * s, height: 28 * s)
        }
    }

    private func filledBead(_ s: CGFloat) -> some View {
        ZStack {
            Circle().fill(Done.amber)
            CheckMark().stroke(Done.paper, style: StrokeStyle(lineWidth: 3.2 * s, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 30 * s, height: 30 * s)
    }

    // MARK: - Controls (real buttons, inside the safe area)

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

    // MARK: - Timing (same beats as the approved Rive scene, plus 0.35 s for the cover to slide up)

    private func play() async throws {
        m.streak = before
        let start = ContinuousClock.now
        func at(_ seconds: Double) async throws {
            try await Task.sleep(until: start + .milliseconds(Int(seconds * 1000)), clock: .continuous)
        }
        let strongOut = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.5)
        let o = 0.35

        try await at(o + 0.10)
        withAnimation(.timingCurve(0.33, 0, 0.12, 1, duration: 0.63)) { m.ring = 1 }

        try await at(o + 0.73)
        closed.toggle()
        m.burst = 1
        withAnimation(.timingCurve(0.23, 1, 0.32, 1, duration: 0.13)) { m.pop = 1.055 }
        withAnimation(.easeOut(duration: 0.17)) { m.glow = 0.95 }
        withAnimation(.timingCurve(0.23, 1, 0.32, 1, duration: 0.55)) { m.burstScale = 1.3 }

        try await at(o + 0.86)
        withAnimation(.easeInOut(duration: 0.2)) { m.pop = 0.99 }
        withAnimation(strongOut) { m.headline = true }

        try await at(o + 0.92)
        m.cheer = true
        withAnimation(.easeInOut(duration: 0.97)) { m.glow = 0.35 }
        withAnimation(.easeIn(duration: 0.36)) { m.burst = 0 }
        withAnimation(.timingCurve(0.23, 1, 0.32, 1, duration: 0.18)) { m.hop = -16; m.squash = 1.04 }

        try await at(o + 1.00)
        withAnimation(strongOut) { m.subline = true }

        try await at(o + 1.06)
        withAnimation(.easeInOut(duration: 0.17)) { m.pop = 1 }

        try await at(o + 1.10)
        withAnimation(.spring(duration: 0.45, bounce: 0.45)) { m.hop = 0; m.squash = 1 }

        try await at(o + 1.30)
        withAnimation(strongOut) { m.panel = true }
        for i in 0..<7 {
            try await at(o + 1.43 + Double(i) * 0.05)
            withAnimation(.spring(duration: 0.3, bounce: 0.45)) { m.days = i + 1 }
        }

        try await at(o + 1.75)
        withAnimation(.easeOut(duration: 0.35)) { m.footer = true }

        try await at(o + 1.93)
        withAnimation(.spring(duration: 0.4, bounce: 0.5)) { m.todayFill = 1 }
        withAnimation(.easeOut(duration: 0.5)) { m.halo = true }
        // Today's dot sits about 72% down the screen, centred.
        ripples.append(FieldRipple(origin: UnitPoint(x: 0.5, y: 0.715), start: .now))

        try await at(o + 2.07)
        withAnimation(.timingCurve(0.33, 0, 0.12, 1, duration: 0.23)) { m.check = 1 }

        guard newDay else { return }
        try await at(o + 2.13)
        m.spark = 1
        withAnimation(.timingCurve(0.5, 0, 0.6, 1, duration: 0.37)) { m.flight = 1 }

        try await at(o + 2.47)
        m.impactOpacity = 1

        try await at(o + 2.50)
        m.spark = 0
        rolled.toggle()
        ripples.append(FieldRipple(origin: UnitPoint(x: 0.15, y: 0.667), start: .now, amp: 0.7))
        withAnimation(.timingCurve(0.23, 1, 0.32, 1, duration: 0.37)) { m.impact = true; m.impactOpacity = 0 }
        withAnimation(.spring(duration: 0.45, bounce: 0.3)) { m.streak = after }
        withAnimation(.timingCurve(0.23, 1, 0.32, 1, duration: 0.12)) { m.rowPop = 1.07 }

        try await at(o + 2.62)
        withAnimation(.spring(duration: 0.35, bounce: 0.3)) { m.rowPop = 1 }
    }

    /// Reduce Motion / Low Power Mode: the finished picture, at once.
    private func settle() {
        m.ring = 1
        m.glow = 0.35
        m.cheer = true
        m.headline = true
        m.subline = true
        m.panel = true
        m.days = 7
        m.todayFill = 1
        m.halo = true
        m.check = 1
        m.streak = after
        m.footer = true
        closed.toggle()
    }
}

/// Everything that moves, in one place.
private struct Motion {
    var ring: CGFloat = 0
    var pop: CGFloat = 1
    var glow: Double = 0
    var burst: Double = 0
    var burstScale: CGFloat = 0.9
    var hop: CGFloat = 0
    var squash: CGFloat = 1
    var cheer = false
    var headline = false
    var subline = false
    var panel = false
    var days = 0
    var todayFill: CGFloat = 0
    var halo = false
    var check: CGFloat = 0
    var flight: CGFloat = 0
    var spark: Double = 0
    var impact = false
    var impactOpacity: Double = 0
    var streak = 0
    var rowPop: CGFloat = 1
    var footer = false
}

/// Moves a view along a quadratic curve as `progress` goes from 0 to 1 (the spark's arc).
private struct Arc: ViewModifier, Animatable {
    var progress: CGFloat
    let from: CGPoint
    let control: CGPoint
    let to: CGPoint

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let t = progress, u = 1 - progress
        let x = u * u * from.x + 2 * u * t * control.x + t * t * to.x
        let y = u * u * from.y + 2 * u * t * control.y + t * t * to.y
        return content.position(x: x, y: y)
    }
}

/// The check in a 30 pt day dot.
private struct CheckMark: Shape {
    func path(in rect: CGRect) -> Path {
        let k = rect.width / 30
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 9 * k, y: rect.minY + 15.5 * k))
        path.addLine(to: CGPoint(x: rect.minX + 13.5 * k, y: rect.minY + 20 * k))
        path.addLine(to: CGPoint(x: rect.minX + 21.5 * k, y: rect.minY + 10.5 * k))
        return path
    }
}

/// The scene's colors (same as apps/rive/complete): warm paper, ink, honey amber, the brain's pink.
private enum Done {
    static let paper = Color(hex: 0xF6F3EC)
    static let sheet = Color(hex: 0xFDFBF7)
    static let face = Color(hex: 0xFCFAF6)
    static let edge = Color(hex: 0xEDE7DC)
    static let track = Color(hex: 0xEDE6DA)
    static let hairline = Color(hex: 0xE4DED3)
    static let ink = Color(hex: 0x171513)
    static let soft = Color(hex: 0x6F6A60)
    static let amber = Color(hex: 0xDE9440)
    static let rose = Color(hex: 0xE9A3BC)
    static let bloom = Color(hex: 0xF6CB80)
    static let shadow = Color(hex: 0x6B4F2A)
    static let honey = LinearGradient(colors: [Color(hex: 0xF4C26E), Color(hex: 0xD9832E)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
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
