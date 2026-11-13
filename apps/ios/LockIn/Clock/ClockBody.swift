import SwiftUI

/// Cream palette. One place for every color so the whole app stays warm and consistent.
enum Cream {
    static let top = Color(hex: 0xFFFBF3)
    static let bottom = Color(hex: 0xF8ECD6)
    static let ink = Color(hex: 0x45321F)
    /// Secondary text. About 5:1 on the cream background.
    static let inkSoft = Color(hex: 0x7D6249)
    static let discHigh = Color.white
    static let discLow = Color(hex: 0xFFF7E6)
    static let track = Color(hex: 0xEFE1C8)
    static let ringStart = Color(hex: 0xEFC38A)
    static let ringEnd = Color(hex: 0xD98550)
    static let butter = Color(hex: 0xF2C890)
    static let butterText = Color(hex: 0x45301D)
    static let quietText = Color(hex: 0x7A5A3E)
    static let quietFill = Color(hex: 0xFFFDF8).opacity(0.87)
    static let edge = Color(hex: 0xE9D8BB)
    static let pill = Color(hex: 0xFFFDF8).opacity(0.8)
    static let pillEdge = Color(hex: 0xEBDDC3)
    /// Warm brown used for every soft shadow.
    static let shadow = Color(hex: 0x8C6432)

    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        AppFont.font(size, weight)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }
}

/// Proportions shared by the static clock body and the live readout layer.
struct ClockGeometry {
    let total: CGFloat

    /// The bezel.
    var diameter: CGFloat { total * 0.96 }
    var faceDiameter: CGFloat { total * 0.806 }
    var ringDiameter: CGFloat { total * 0.865 }
    var ringWidth: CGFloat { max(6, total * 0.036) }
    var tickRadius: CGFloat { total * 0.361 }
}

/// Everything that never changes while the timer runs: bezel, face, dial marks and the ring track.
/// Grouped for offscreen rendering with `drawingGroup`.
struct ClockBody: View {
    let geometry: ClockGeometry

    var body: some View {
        let d = geometry.diameter
        ZStack {
            // The shadow sits outside the drawing group so it is never cut off at a square edge.
            Circle()
                .fill(Color(hex: 0xD3D5CC))
                .frame(width: d, height: d)
                .shadow(color: .black.opacity(0.16), radius: d * 0.06, x: 0, y: d * 0.05)

            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [
                                Color(hex: 0xEDEEE9), Color(hex: 0xCBCDC4), Color(hex: 0xE4E5DF),
                                Color(hex: 0xC2C4BB), Color(hex: 0xE9EAE5), Color(hex: 0xEDEEE9),
                            ],
                            center: .center,
                            angle: .degrees(210)
                        )
                    )
                    .frame(width: d, height: d)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 1))

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Matte.faceTop, Matte.faceMid, Matte.faceLow],
                            center: UnitPoint(x: 0.35, y: 0.25),
                            startRadius: 0,
                            endRadius: geometry.faceDiameter * 0.9
                        )
                    )
                    .frame(width: geometry.faceDiameter, height: geometry.faceDiameter)
                    .overlay(
                        Circle().strokeBorder(
                            LinearGradient(colors: [.black.opacity(0.14), .white.opacity(0.6)], startPoint: .top, endPoint: .bottom),
                            lineWidth: 2
                        )
                    )

                Canvas { context, size in
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    for i in 0..<60 {
                        let major = i % 5 == 0
                        let a = Double(i) / 60 * 2 * .pi
                        let r1 = geometry.tickRadius
                        let r2 = r1 - geometry.total * (major ? 0.029 : 0.016)
                        var path = Path()
                        path.move(to: CGPoint(x: c.x + cos(a) * r1, y: c.y + sin(a) * r1))
                        path.addLine(to: CGPoint(x: c.x + cos(a) * r2, y: c.y + sin(a) * r2))
                        context.stroke(path, with: .color(major ? Matte.tickMajor : Matte.tick), lineWidth: major ? 1.6 : 1)
                    }
                }
                .frame(width: geometry.total, height: geometry.total)

                Circle()
                    .stroke(Matte.trackShade, lineWidth: geometry.ringWidth + 4)
                    .frame(width: geometry.ringDiameter, height: geometry.ringDiameter)
                Circle()
                    .stroke(Matte.track, lineWidth: geometry.ringWidth)
                    .frame(width: geometry.ringDiameter, height: geometry.ringDiameter)
            }
            .frame(width: geometry.total, height: geometry.total)
            .drawingGroup()
        }
        .frame(width: geometry.total, height: geometry.total)
    }
}

/// Slow light glint around the bezel and faint ripples spreading from the clock.
/// Only drawn when motion is allowed.
struct ClockAmbient: View {
    let geometry: ClockGeometry
    let calm: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let u = geometry.total

                // Ripples: three rings, offset in time, growing and fading.
                let period = calm ? 16.0 : 9.0
                for k in 0..<3 {
                    var p = (t / period + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                    if p < 0 { p += 1 }
                    let r = u * (0.50 + 0.24 * p)
                    let alpha = p < 0.12 ? p / 0.12 * 0.45 : 0.45 * (1 - p)
                    let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
                    ctx.stroke(Path(ellipseIn: rect), with: .color(Color(hex: 0x3255A4).opacity(alpha * 0.6)), lineWidth: 1)
                }

                // Glint on the bezel rim.
                let glintR = u * 0.465
                let rect = CGRect(x: c.x - glintR, y: c.y - glintR, width: glintR * 2, height: glintR * 2)
                let gradient = Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.8),
                    .init(color: Color.white.opacity(0.7), location: 0.9),
                    .init(color: .clear, location: 1),
                ])
                ctx.stroke(
                    Path(ellipseIn: rect),
                    with: .conicGradient(gradient, center: c, angle: .degrees(t * 45)),
                    lineWidth: u * 0.035
                )
            }
            .frame(width: geometry.total * 1.7, height: geometry.total * 1.7)
        }
        .frame(width: geometry.total, height: geometry.total)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
