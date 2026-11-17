import SwiftUI

/// "Looking for your PC": the brain sways up and down and a ring leaves it every 1.2 s, the moment it
/// has just come back down to the middle (600 ms into each swing). Same timing as the PC window.
struct SonarBrain: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let side: CGFloat = 220
    private let period = 1200.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { context in
            let ms = reduceMotion ? 1000.0 : (context.date.timeIntervalSinceReferenceDate * 1000)
            ZStack {
                Canvas { drawing, size in
                    let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                    let r0 = size.width * 0.13
                    let r1 = size.width * 0.48
                    let t = (ms + 3600 - 600).truncatingRemainder(dividingBy: 3600) / 3600
                    for k in 0..<3 {
                        let q = (t + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                        let grow = 1 - pow(1 - q, 2.2)
                        let radius = r0 + (r1 - r0) * CGFloat(grow)
                        let alpha = 0.92 * (1 - q) * min(1, q / 0.1)
                        guard alpha > 0.015 else { continue }
                        let ring = Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius,
                                                          width: radius * 2, height: radius * 2))
                        drawing.stroke(ring, with: .color(FocusPaper.amber.opacity(alpha)), lineWidth: 3)
                    }
                }
                Image("BrainExact")
                    .resizable().scaledToFit()
                    .frame(width: side * 0.4)
                    .offset(y: reduceMotion ? 0 : -CGFloat(sin(ms.truncatingRemainder(dividingBy: period) / period * 2 * .pi)) * 6)
            }
            .frame(width: side, height: side)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Looking for your PC")
        .accessibilityIdentifier("pc-searching")
    }
}
