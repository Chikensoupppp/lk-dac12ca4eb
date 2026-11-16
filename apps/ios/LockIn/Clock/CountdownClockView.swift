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

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let ring = side * 0.92
            ZStack {
                Circle().stroke(FocusPaper.line, lineWidth: side * 0.01)
                    .frame(width: ring, height: ring)
                dialMarks
                if showsMascot {
                    Image("BrainExact")
                        .resizable().scaledToFit()
                        .accessibilityHidden(true)
                        .frame(width: side * 0.56)
                        .offset(y: side * (timing == nil ? -0.14 : -0.15))
                        .animation(motionLimited(systemReduceMotion) ? nil : .spring(response: 0.36, dampingFraction: 1), value: timing == nil)
                }
                TimelineView(.animation(minimumInterval: 1, paused: timing == nil)) { context in
                    let remaining = timing?.remaining(at: context.date) ?? duration
                    let seconds = Int(remaining.rounded(.up))
                    let fraction = timing.map { $0.fractionRemaining(at: context.date) } ?? idleFraction
                    let value = min(max(fraction, 0), 1)
                    ZStack {
                        Circle().trim(from: 0, to: value)
                            .stroke(flash == .endedEarly ? FocusPaper.secondary : FocusPaper.amber,
                                    style: StrokeStyle(lineWidth: side * (timing != nil && seconds <= 60 ? 0.026 : 0.02), lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: ring, height: ring)
                            .animation(timing == nil && !motionLimited(systemReduceMotion) ? .spring(response: 0.34, dampingFraction: 1) : nil, value: idleFraction)
                        Text(SessionTiming.display(seconds: seconds))
                            .font(AppFont.font(side * 0.23, .bold).monospacedDigit())
                            .tracking(-side * 0.013)
                            .foregroundStyle(FocusPaper.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(width: side * 0.82)
                            .offset(y: side * (showsMascot ? 0.16 : -0.02))
                        if !typeSize.isAccessibilitySize {
                            Text(caption)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(FocusPaper.secondary)
                                .multilineTextAlignment(.center)
                                .frame(width: side * 0.7)
                                .offset(y: side * (showsMascot ? 0.30 : 0.14))
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
    }

    private var dialMarks: some View {
        Canvas { drawing, size in
            var context = drawing
            let scale = size.width / 300
            context.scaleBy(x: scale, y: scale)
            for tick in 0..<36 {
                let major = tick.isMultiple(of: 3)
                var hand = context
                hand.translateBy(x: 150, y: 150)
                hand.rotate(by: .degrees(Double(tick) * 10))
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
