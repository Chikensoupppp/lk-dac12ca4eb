import SwiftUI

/// Reusable circular countdown clock. Purely presentational: it renders `timing`
/// (the session's end timestamp) and never keeps a countdown of its own.
/// `timing == nil` shows the idle dial at `duration`.
struct CountdownClockView: View {
    let duration: TimeInterval
    let timing: SessionTiming?
    let caption: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let g = ClockGeometry(total: min(proxy.size.width, proxy.size.height))
            ZStack {
                ClockBody(geometry: g)
                    .accessibilityHidden(true)

                // Per-frame updates only touch this layer: the arc and the digits.
                TimelineView(.animation(minimumInterval: reduceMotion ? 0.25 : nil, paused: timing == nil)) { context in
                    readout(at: context.date, geometry: g)
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
        let fraction = reduceMotion ? Double(seconds) / duration : remaining / duration

        ZStack {
            ProgressArc(fraction: fraction, diameter: g.ringDiameter, lineWidth: g.ringWidth)

            Text(SessionTiming.display(seconds: seconds))
                .font(.system(size: g.diameter * 0.19, weight: .light).monospacedDigit())
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white.opacity(0.98), Color(white: 0.78)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color.black.opacity(0.7), radius: 0, x: 0, y: 1)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: g.faceDiameter * 0.66)

            Text(caption.uppercased())
                .font(.system(size: g.diameter * 0.034, weight: .medium))
                .tracking(g.diameter * 0.008)
                .foregroundStyle(Color.white.opacity(0.38))
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

/// Thin polished-silver arc. It starts at 12 o'clock and its leading end retreats
/// clockwise as time runs out. Highlights are fixed to the screen (light from the upper left).
private struct ProgressArc: View {
    let fraction: Double
    let diameter: CGFloat
    let lineWidth: CGFloat

    // Gradient angles are pre-rotation (the arc is rotated -90 degrees), so the
    // upper-left highlight sits at location 0.875.
    private static let silver = AngularGradient(
        stops: ClockTone.metalStops([
            (0.000, 0.50), (0.125, 0.40), (0.375, 0.72), (0.500, 0.52),
            (0.750, 0.38), (0.875, 0.93), (1.000, 0.50)
        ]),
        center: .center
    )

    private static let specular = AngularGradient(
        stops: ClockTone.lightStops([
            (0.000, 0), (0.340, 0), (0.375, 0.45), (0.410, 0),
            (0.820, 0), (0.875, 1.0), (0.930, 0), (1.000, 0)
        ]),
        center: .center
    )

    var body: some View {
        let f = min(max(fraction, 0), 1)
        ZStack {
            if f > 0.0005 {
                Circle()
                    .trim(from: 1 - f, to: 1)
                    .stroke(Self.silver, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                Circle()
                    .trim(from: 1 - f, to: 1)
                    .stroke(Self.specular, style: StrokeStyle(lineWidth: lineWidth * 0.38, lineCap: .round))
            }
        }
        .rotationEffect(.degrees(-90))
        .frame(width: diameter, height: diameter)
        .shadow(color: Color.black.opacity(0.7), radius: lineWidth * 0.6, x: 0, y: lineWidth * 0.5)
    }
}
