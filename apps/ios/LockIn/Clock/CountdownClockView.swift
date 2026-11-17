import SwiftUI

/// A timestamp-driven dial. The artwork and pencil marks never change with the countdown.
struct CountdownClockView: View {
    let duration: TimeInterval
    let timing: SessionTiming?
    let caption: String
    var idleFraction: Double = 1
    var flash: FocusMood?
    var showsMascot = true

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    /// When a session starts, the arc eases from the idle length to the live length instead of jumping,
    /// and the brain hops. With the one-hour dial both lengths match, so only the hop shows today.
    /// The sweep is computed from the clock (like the countdown), so it cannot drift from the timer.
    @State private var sweepFrom: Double?
    @State private var sweepStart: Date?
    private static let sweepSeconds = 0.9

    private var sweeping: Bool { sweepStart != nil }

    /// The arc length during the start sweep, eased in and out.
    private func swept(_ live: Double, at date: Date) -> Double {
        guard let sweepFrom, let sweepStart else { return live }
        let t = min(max(date.timeIntervalSince(sweepStart) / Self.sweepSeconds, 0), 1)
        let eased = t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
        return sweepFrom + (live - sweepFrom) * eased
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let ring = side * 0.92
            ZStack {
                // No grey track ring: the tick marks draw the dial, and the amber arc alone shows time.
                dialMarks
                if showsMascot {
                    Image("BrainExact")
                        .resizable().scaledToFit()
                        .accessibilityHidden(true)
                        .frame(width: side * 0.44)
                        .offset(y: side * (timing == nil ? -0.19 : -0.20))
                        // A small happy hop as the session starts.
                        .scaleEffect(sweeping ? 1.06 : 1)
                        .animation(motionLimited(systemReduceMotion) ? nil : .spring(response: 0.45, dampingFraction: 0.6), value: sweeping)
                        .animation(motionLimited(systemReduceMotion) ? nil : .spring(response: 0.36, dampingFraction: 1), value: timing == nil)
                }
                // Every frame during the start sweep, then once a second.
                TimelineView(.animation(minimumInterval: sweeping ? nil : 1, paused: timing == nil)) { context in
                    let remaining = timing?.remaining(at: context.date) ?? duration
                    let seconds = Int(remaining.rounded(.up))
                    // Kitchen-timer dial: the full ring is one hour, so 25 minutes fills 25/60 of it.
                    // Sessions longer than an hour keep a full ring until an hour is left.
                    let fraction = timing.map { _ in remaining / 3600 } ?? idleFraction
                    let value = swept(min(max(fraction, 0), 1), at: context.date)
                    ZStack {
                        Circle().trim(from: 0, to: value)
                            .stroke(flash == .endedEarly ? FocusPaper.secondary : FocusPaper.amber,
                                    style: StrokeStyle(lineWidth: side * (timing != nil && seconds <= 60 ? 0.026 : 0.02), lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: ring, height: ring)
                            .animation(timing == nil && !motionLimited(systemReduceMotion) ? .spring(response: 0.34, dampingFraction: 1) : nil, value: idleFraction)
                        Text(SessionTiming.display(seconds: seconds))
                            .font(AppFont.font(side * 0.22, .bold).monospacedDigit())
                            .tracking(-side * 0.013)
                            .foregroundStyle(FocusPaper.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(width: side * 0.82)
                            .offset(y: side * (showsMascot ? 0.09 : -0.02))
                        if !typeSize.isAccessibilitySize {
                            Text(caption)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(FocusPaper.secondary)
                                .multilineTextAlignment(.center)
                                .frame(width: side * 0.7)
                                .offset(y: side * (showsMascot ? 0.27 : 0.14))
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Focus timer")
                    .accessibilityValue(spokenValue(seconds: seconds))
                    .accessibilityAddTraits(.updatesFrequently)
                    .transaction { $0.animation = nil }
                }
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .onChange(of: timing == nil) { wasIdle, isIdle in
            guard wasIdle, !isIdle, !motionLimited(systemReduceMotion) else { return }
            sweepFrom = min(max(idleFraction, 0), 1)
            sweepStart = .now
        }
        .task(id: sweepStart) {
            guard sweepStart != nil else { return }
            do { try await Task.sleep(for: .seconds(Self.sweepSeconds)) } catch { return }
            sweepStart = nil
            sweepFrom = nil
        }
    }

    private var dialMarks: some View {
        Canvas { drawing, size in
            var context = drawing
            let scale = size.width / 300
            context.scaleBy(x: scale, y: scale)
            // One tick per minute; a long tick every 5 minutes.
            for tick in 0..<60 {
                let major = tick.isMultiple(of: 5)
                var hand = context
                hand.translateBy(x: 150, y: 150)
                hand.rotate(by: .degrees(Double(tick) * 6))
                var mark = Path()
                mark.move(to: CGPoint(x: 0, y: -129))
                mark.addLine(to: CGPoint(x: 0, y: major ? -122 : -126))
                hand.stroke(mark, with: .color(FocusPaper.secondary.opacity(major ? 0.9 : 0.42)), lineWidth: major ? 1.2 : 0.85)
            }
            var tally = Path()
            for (a, b) in [(CGPoint(x: 45, y: 238), CGPoint(x: 38, y: 244)),
                           (CGPoint(x: 50, y: 243), CGPoint(x: 45, y: 251)),
                           (CGPoint(x: 57, y: 248), CGPoint(x: 52, y: 255))] {
                tally.move(to: a)
                tally.addLine(to: b)
            }
            context.stroke(tally, with: .color(FocusPaper.ink), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .accessibilityHidden(true)
    }

    private func spokenValue(seconds: Int) -> String {
        let spoken = Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
        return timing == nil ? "\(caption), \(spoken)" : "\(spoken) remaining, \(caption)"
    }
}
