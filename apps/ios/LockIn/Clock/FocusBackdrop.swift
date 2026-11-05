import SwiftUI

/// Matte black backdrop with slow drifting glows and rising dust.
/// Glow color follows `FocusMood`. With Reduce Motion or Low Power Mode the drift and dust stop;
/// colors still change, with a short fade.
struct FocusBackdrop: View {
    let timing: SessionTiming?
    let flash: FocusMood?

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var motion: Bool { !motionLimited(systemReduceMotion) }

    var body: some View {
        TimelineView(.animation(minimumInterval: motion ? 1.0 / 20 : 1, paused: !motion && timing == nil)) { context in
            let mood = FocusMood.resolve(timing: timing, flash: flash, now: context.date)
            let t = motion ? context.date.timeIntervalSinceReferenceDate : 0
            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: Matte.bgTop, location: 0),
                        .init(color: Matte.bgMid, location: 0.6),
                        .init(color: Matte.bgBottom, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                MoodGlows(mood: mood, t: t, fade: motion ? 1.6 : 0.3)
                if motion { DustField(t: t, calm: mood.calm) }
                EllipticalGradient(
                    colors: [.clear, .black.opacity(0.45)],
                    center: UnitPoint(x: 0.5, y: 0.45),
                    startRadiusFraction: 0.55,
                    endRadiusFraction: 1
                )
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Warm cream backdrop kept for the sheets (Restrictions, PC).
struct CreamBackdrop: View {
    var body: some View {
        LinearGradient(colors: [Cream.top, Cream.bottom], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

private struct MoodGlows: View {
    let mood: FocusMood
    let t: Double
    let fade: Double

    private func drift(_ period: Double, _ phase: Double, _ amp: CGFloat) -> CGFloat {
        CGFloat(sin(t * 2 * .pi / period + phase)) * amp
    }

    private func blob(_ color: Color, size: CGFloat) -> some View {
        // Padding keeps the blur halo inside the rasterized bounds so it is not cut off.
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .padding(170)
            .blur(radius: 55)
            .drawingGroup()
            .opacity(0.8 * mood.glowAmount)
            .scaleEffect(mood.calm ? 0.92 : 1)
            .animation(.easeInOut(duration: fade), value: mood)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let k: CGFloat = mood.calm ? 0.4 : 1.0
            ZStack {
                blob(mood.glows[0], size: w * 0.87)
                    .position(x: w * 0.10, y: h * 0.25)
                    .offset(x: drift(14, 0, 40) * k, y: drift(14, 1.2, 60) * k)
                blob(mood.glows[1], size: w * 0.82)
                    .position(x: w * 0.95, y: h * 0.50)
                    .offset(x: drift(17, 2.0, 50) * k, y: drift(17, 0.4, 55) * k)
                blob(mood.glows[2], size: w * 0.92)
                    .position(x: w * 0.50, y: h * 1.0)
                    .offset(x: drift(19, 3.1, 45) * k, y: drift(19, 1.9, 40) * k)
            }
            .frame(width: w, height: h)
        }
        .allowsHitTesting(false)
    }
}

private struct DustField: View {
    let t: Double
    let calm: Bool

    private static func unit(_ n: Double) -> Double {
        let x = sin(n * 12.9898) * 43758.5453
        return x - x.rounded(.down)
    }

    var body: some View {
        Canvas { context, size in
            for i in 0..<16 {
                let n = Double(i + 1)
                let x = Self.unit(n) * size.width
                let period = 14 + Self.unit(n + 40) * 12
                let phase = Self.unit(n + 80)
                var p = (t / period + phase).truncatingRemainder(dividingBy: 1)
                if p < 0 { p += 1 }
                let alpha: Double
                if p < 0.15 { alpha = p / 0.15 * 0.55 }
                else if p > 0.85 { alpha = (1 - p) / 0.15 * 0.3 }
                else { alpha = 0.55 - (p - 0.15) / 0.7 * 0.25 }
                let y = size.height * (1 - p)
                let rect = CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)
                context.fill(Path(ellipseIn: rect), with: .color(Color(hex: 0xBFD8F5).opacity(alpha * (calm ? 0.35 : 1))))
            }
        }
        .allowsHitTesting(false)
    }
}
