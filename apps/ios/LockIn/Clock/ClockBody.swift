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
        .system(size: size, weight: weight, design: .rounded)
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

    var diameter: CGFloat { total * 0.90 }
    var faceDiameter: CGFloat { diameter * 0.84 }
    var ringDiameter: CGFloat { diameter * 0.84 }
    var ringWidth: CGFloat { max(6, diameter * 0.053) }
}

/// Everything that never changes while the timer runs: a soft cream disc and its track.
/// Grouped for offscreen rendering with `drawingGroup`.
struct ClockBody: View {
    let geometry: ClockGeometry

    var body: some View {
        let d = geometry.diameter
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Cream.discHigh, Cream.discLow],
                        center: UnitPoint(x: 0.35, y: 0.25),
                        startRadius: 0,
                        endRadius: d * 0.8
                    )
                )
                .frame(width: d, height: d)
                .shadow(color: Cream.shadow.opacity(0.26), radius: d * 0.06, x: 0, y: d * 0.035)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: 1))

            Circle()
                .stroke(Cream.track, lineWidth: geometry.ringWidth)
                .frame(width: geometry.ringDiameter, height: geometry.ringDiameter)
        }
        .frame(width: geometry.total, height: geometry.total)
        .drawingGroup()
    }
}
