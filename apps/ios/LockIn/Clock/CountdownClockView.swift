import SwiftUI

/// Reusable circular countdown clock. Purely presentational: it renders `timing`
/// (the session's end timestamp) and never keeps a countdown of its own.
/// `timing == nil` shows the idle dial at `duration`, with the ring at `idleFraction`.
struct CountdownClockView: View {
    let duration: TimeInterval
    let timing: SessionTiming?
    let caption: String
    /// Ring length while idle (selected minutes out of 90). Changes animate.
    var idleFraction: Double = 1
    var flash: FocusMood?
    /// Changes when a session finishes; plays one light sweep across the face.
    var sweepTrigger: Int = 0

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { effectiveReduceMotion(systemReduceMotion) }
    private var motion: Bool { !motionLimited(systemReduceMotion) }

    /// How long the ring takes to grow from its idle length to full when a session starts.
    private static let growTime: TimeInterval = 0.7

    var body: some View {
        GeometryReader { proxy in
            let g = ClockGeometry(total: min(proxy.size.width, proxy.size.height))
            ZStack {
                ClockBody(geometry: g)
                    .accessibilityHidden(true)

                if motion {
                    ClockAmbient(geometry: g, calm: timing != nil)
                }

                LightSweep(trigger: sweepTrigger, diameter: g.faceDiameter, enabled: motion)

                // Per-frame updates only touch this layer: the arc and the digits.
                TimelineView(.animation(minimumInterval: reduceMotion ? 1 : nil, paused: timing == nil)) { context in
                    readout(at: context.date, geometry: g)
                        // The clock is driven by timestamps; interpolating the reset arc
                        // during the surrounding layout transition distorts the dial.
                        .transaction { $0.animation = nil }
                }
            }
            .frame(width: g.total, height: g.total)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func readout(at now: Date, geometry g: ClockGeometry) -> some View {
        let remaining = timing?.remaining(at: now) ?? duration
        let seconds = Int(remaining.rounded(.up))
        let mood = FocusMood.resolve(timing: timing, flash: flash, now: now)
        let fraction = ringFraction(now: now, remaining: remaining, seconds: seconds)
        let arcKey: Double = timing == nil ? idleFraction : -1
        let arcFade: Double = reduceMotion ? 0.2 : 1.4

        ZStack {
            ProgressArc(
                fraction: fraction,
                diameter: g.ringDiameter,
                lineWidth: g.ringWidth,
                colors: mood.ring
            )
            .animation(reduceMotion ? nil : .smooth(duration: 0.7), value: arcKey)
            .animation(.easeInOut(duration: arcFade), value: mood)

            if timing != nil, fraction > 0.005, fraction < 0.999 {
                tipDot(fraction: fraction, now: now, geometry: g)
            }

            timeText(seconds: seconds, geometry: g)

            captionText(geometry: g)
        }
        .frame(width: g.total, height: g.total)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focus timer")
        .accessibilityValue(spokenValue(seconds: seconds))
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// Ring length. Grows from the idle length to full when a session starts, then drains.
    /// A pure function of timestamps. Reduce Motion: steps once per second instead of sweeping.
    private func ringFraction(now: Date, remaining: TimeInterval, seconds: Int) -> Double {
        guard let timing else { return idleFraction }
        let total: Double = timing.duration
        let remainingFraction: Double = total > 0 ? (reduceMotion ? Double(seconds) / total : remaining / total) : 0
        let grow: Double = min(max(now.timeIntervalSince(timing.startedAt) / Self.growTime, 0), 1)
        let eased: Double = reduceMotion ? 1 : grow * grow * (3 - 2 * grow)
        return idleFraction + (remainingFraction - idleFraction) * eased
    }

    private func tipDot(fraction: Double, now: Date, geometry g: ClockGeometry) -> some View {
        let angle: Double = (1 - fraction) * 2 * Double.pi - Double.pi / 2
        let r: Double = Double(g.ringDiameter) / 2
        let t: Double = now.timeIntervalSinceReferenceDate * 2 * Double.pi / 2.2
        let beat: Double = reduceMotion ? 0 : 0.5 - 0.5 * cos(t)
        let size: CGFloat = g.ringWidth * 0.3
        return Circle()
            .fill(Matte.tip)
            .frame(width: size, height: size)
            .scaleEffect(1 + 0.9 * beat)
            .opacity(0.95 - 0.45 * beat)
            .offset(x: CGFloat(cos(angle) * r), y: CGFloat(sin(angle) * r))
    }

    private func timeText(seconds: Int, geometry g: ClockGeometry) -> some View {
        Text(SessionTiming.display(seconds: seconds))
            .font(Cream.rounded(g.total * 0.2, .semibold).monospacedDigit())
            .foregroundStyle(Matte.text)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: g.faceDiameter * 0.82)
            .contentTransition(.numericText())
            .animation(reduceMotion ? nil : .smooth(duration: 0.5), value: timing == nil ? seconds : -1)
    }

    private func captionText(geometry g: ClockGeometry) -> some View {
        Text(caption.uppercased())
            .font(Cream.rounded(g.total * 0.039, .bold))
            .tracking(g.total * 0.007)
            .foregroundStyle(Matte.textSoft)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: g.faceDiameter * 0.6)
            .offset(y: g.total * 0.14)
    }

    private func spokenValue(seconds: Int) -> String {
        let spoken = Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
        return timing == nil ? "Ready, \(spoken)" : "\(spoken) remaining"
    }
}

/// Ring arc. It starts at 12 o'clock and its leading end retreats
/// clockwise as time runs out. `fraction` is animatable so idle length changes glide.
private struct ArcShape: Shape {
    var fraction: Double

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let f = min(max(fraction, 0), 1)
        guard f > 0.0005 else { return Path() }
        // Same construction as the previous trim + rotation: the arc ends at 12 o'clock.
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let turn = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: -.pi / 2)
            .translatedBy(x: -center.x, y: -center.y)
        return Circle().trim(from: 1 - f, to: 1).path(in: rect).applying(turn)
    }
}

private struct ProgressArc: View {
    let fraction: Double
    let diameter: CGFloat
    let lineWidth: CGFloat
    let colors: [Color]

    var body: some View {
        ArcShape(fraction: fraction)
            .stroke(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .shadow(color: (colors.count > 1 ? colors[1] : .clear).opacity(0.5), radius: lineWidth * 0.6)
            .frame(width: diameter, height: diameter)
    }
}

/// One light sweep across the clock face when `trigger` changes.
private struct LightSweep: View {
    let trigger: Int
    let diameter: CGFloat
    let enabled: Bool

    @State private var x: CGFloat = -0.8
    @State private var opacity: Double = 0

    var body: some View {
        Rectangle()
            .fill(LinearGradient(
                colors: [.clear, Color(hex: 0xDCF0FF).opacity(0.45), .clear],
                startPoint: .leading,
                endPoint: .trailing
            ))
            .frame(width: diameter * 0.4, height: diameter * 1.5)
            .rotationEffect(.degrees(20))
            .offset(x: x * diameter)
            .opacity(opacity)
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onChange(of: trigger) { _, _ in
                guard enabled else { return }
                Task { @MainActor in
                    var reset = Transaction()
                    reset.disablesAnimations = true
                    withTransaction(reset) { x = -0.8; opacity = 1 }
                    await Task.yield()
                    withAnimation(.easeInOut(duration: 1.3)) { x = 0.8 }
                    withAnimation(.easeOut(duration: 0.4).delay(0.9)) { opacity = 0 }
                }
            }
    }
}
