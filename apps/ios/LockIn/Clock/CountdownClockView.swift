import SwiftUI

/// Reusable circular countdown clock. Purely presentational: it renders `timing`
/// (the session's end timestamp) and never keeps a countdown of its own.
/// `timing == nil` shows the idle dial at `duration`.
struct CountdownClockView: View {
    let duration: TimeInterval
    let timing: SessionTiming?
    let caption: String

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { effectiveReduceMotion(systemReduceMotion) }

    var body: some View {
        GeometryReader { proxy in
            let g = ClockGeometry(total: min(proxy.size.width, proxy.size.height))
            ZStack {
                ClockBody(geometry: g)
                    .accessibilityHidden(true)

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
        // Reduce Motion: the arc steps once per second instead of sweeping continuously.
        let total = timing?.duration ?? duration
        let fraction = total > 0 ? (reduceMotion ? Double(seconds) / total : remaining / total) : 0

        ZStack {
            ProgressArc(fraction: fraction, diameter: g.ringDiameter, lineWidth: g.ringWidth)

            Text(SessionTiming.display(seconds: seconds))
                .font(Cream.rounded(g.diameter * 0.19, .light).monospacedDigit())
                .foregroundStyle(Cream.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: g.faceDiameter * 0.74)

            Text(caption.uppercased())
                .font(Cream.rounded(g.diameter * 0.036, .semibold))
                .tracking(g.diameter * 0.006)
                .foregroundStyle(Cream.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: g.faceDiameter * 0.6)
                .offset(y: g.diameter * 0.15)
        }
        .frame(width: g.total, height: g.total)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focus timer")
        .accessibilityValue(spokenValue(seconds: seconds))
        .accessibilityAddTraits(.updatesFrequently)
    }

    private func spokenValue(seconds: Int) -> String {
        let spoken = Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
        return timing == nil ? "Ready, \(spoken)" : "\(spoken) remaining"
    }
}

/// Thick caramel arc. It starts at 12 o'clock and its leading end retreats
/// clockwise as time runs out. The color gradient is fixed to the screen.
private struct ProgressArc: View {
    let fraction: Double
    let diameter: CGFloat
    let lineWidth: CGFloat

    private static let fill = LinearGradient(
        colors: [Cream.ringStart, Cream.ringEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        let f = min(max(fraction, 0), 1)
        ZStack {
            if f > 0.0005 {
                Circle()
                    .trim(from: 1 - f, to: 1)
                    .rotation(.degrees(-90))
                    .stroke(Self.fill, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
        }
        .frame(width: diameter, height: diameter)
    }
}
