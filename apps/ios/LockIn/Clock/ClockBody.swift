import SwiftUI

/// Proportions shared by the static clock body and the live readout layer.
struct ClockGeometry {
    let total: CGFloat

    var diameter: CGFloat { total * 0.90 }
    var wellDiameter: CGFloat { total * 0.985 }
    var rimWidth: CGFloat { diameter * 0.075 }
    var faceDiameter: CGFloat { diameter - rimWidth * 2 }
    var faceRadius: CGFloat { faceDiameter / 2 }
    var ringDiameter: CGFloat { faceDiameter * 0.90 }
    var ringWidth: CGFloat { max(1.5, diameter * 0.0085) }
}

enum ClockTone {
    /// Cool-neutral grey used for titanium and silver.
    static func metal(_ l: Double, _ opacity: Double = 1) -> Color {
        Color(red: l, green: l + 0.004, blue: min(l + 0.014, 1), opacity: opacity)
    }

    /// Gradient stops from (location, lightness) pairs.
    static func metalStops(_ pairs: [(Double, Double)]) -> [Gradient.Stop] {
        pairs.map { Gradient.Stop(color: metal($0.1), location: $0.0) }
    }

    /// Gradient stops from (location, white opacity) pairs.
    static func lightStops(_ pairs: [(Double, Double)]) -> [Gradient.Stop] {
        pairs.map { Gradient.Stop(color: Color.white.opacity($0.1), location: $0.0) }
    }
}

struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 2862933555777941757 &+ 3037000493 }

    /// Uniform value in [0, 1).
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / 9007199254740992.0
    }
}

/// Everything that never changes while the timer runs: recessed well, titanium rim,
/// machined face, groove and ticks. Grouped for offscreen rendering with `drawingGroup`;
/// caching and performance have not been measured.
struct ClockBody: View {
    let geometry: ClockGeometry

    var body: some View {
        ZStack {
            well
            rim
            face
            groove
            ticks
        }
        .frame(width: geometry.total, height: geometry.total)
        .drawingGroup()
    }

    // MARK: Well (the clock sits slightly sunk into the surface)

    private var well: some View {
        let w = geometry.wellDiameter
        return Circle()
            .fill(Color(white: 0.012))
            .frame(width: w, height: w)
            .overlay(
                Circle()
                    .stroke(Color.black, lineWidth: w * 0.05)
                    .blur(radius: w * 0.025)
                    .offset(y: w * 0.014)
                    .mask(Circle())
            )
            .overlay(
                Circle().strokeBorder(
                    LinearGradient(
                        colors: [Color.black.opacity(0.9), Color.white.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: max(1, w * 0.004)
                )
            )
    }

    // MARK: Rim (dark brushed titanium, light from the upper left)

    private var rim: some View {
        let d = geometry.diameter
        return ZStack {
            Circle()
                .fill(Color.black)
                .shadow(color: Color.black.opacity(0.75), radius: geometry.total * 0.03, x: 0, y: geometry.total * 0.018)

            Circle().fill(
                AngularGradient(
                    stops: ClockTone.metalStops([
                        (0.000, 0.17), (0.125, 0.34), (0.250, 0.15), (0.375, 0.10),
                        (0.500, 0.23), (0.625, 0.52), (0.750, 0.25), (0.875, 0.12), (1.000, 0.17)
                    ]),
                    center: .center
                )
            )

            brushLines(diameter: d)

            // Narrow anisotropic glints, as on machined metal.
            Circle()
                .fill(
                    AngularGradient(
                        stops: ClockTone.lightStops([
                            (0.00, 0), (0.09, 0), (0.125, 0.12), (0.16, 0),
                            (0.58, 0), (0.625, 0.26), (0.67, 0), (1.00, 0)
                        ]),
                        center: .center
                    )
                )
                .blendMode(.plusLighter)

            Circle().strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(0.42), Color.white.opacity(0.04), Color.black.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: max(1, d * 0.004)
            )
        }
        .frame(width: d, height: d)
    }

    private func brushLines(diameter d: CGFloat) -> some View {
        Canvas { context, size in
            var rng = SeededRandom(seed: 11)
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = size.width / 2
            let inner = outer * 0.82
            for _ in 0..<160 {
                let r = inner + (outer - inner) * CGFloat(rng.next())
                let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
                let bright = rng.next() > 0.5
                let a = 0.015 + 0.05 * rng.next()
                let color = bright ? Color.white.opacity(a) : Color.black.opacity(a * 1.6)
                context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 0.5)
            }
        }
        .frame(width: d, height: d)
        .clipShape(Circle())
    }

    // MARK: Face (near-black, matte, recessed)

    private var face: some View {
        let f = geometry.faceDiameter
        return ZStack {
            // Chamfer between rim and face: reads as concave, so light and dark swap sides.
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.black.opacity(0.95), ClockTone.metal(0.40, 0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(1, f * 0.012)
                )
                .frame(width: f * 1.024, height: f * 1.024)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.060), Color(white: 0.030), Color(white: 0.014)],
                        center: UnitPoint(x: 0.38, y: 0.30),
                        startRadius: 0,
                        endRadius: f * 0.8
                    )
                )
                .frame(width: f, height: f)
                .overlay(faceGrain(diameter: f))
                .overlay(
                    Circle()
                        .fill(
                            AngularGradient(
                                stops: ClockTone.lightStops([
                                    (0.000, 0), (0.125, 0.025), (0.250, 0),
                                    (0.500, 0), (0.625, 0.040), (0.750, 0), (1.000, 0)
                                ]),
                                center: .center
                            )
                        )
                        .blendMode(.plusLighter)
                )
                .overlay(
                    // Shadow the rim casts onto the lowered face.
                    Circle()
                        .stroke(Color.black, lineWidth: f * 0.06)
                        .blur(radius: f * 0.035)
                        .offset(x: f * 0.012, y: f * 0.03)
                        .mask(Circle())
                        .opacity(0.9)
                )
        }
    }

    private func faceGrain(diameter f: CGFloat) -> some View {
        Canvas { context, size in
            var rng = SeededRandom(seed: 3)
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = Double(size.width) / 2
            let count = Int(size.width * size.width / 24)
            for _ in 0..<count {
                let rad = radius * rng.next().squareRoot()
                let angle = rng.next() * 2 * Double.pi
                let x = c.x + CGFloat(rad * cos(angle))
                let y = c.y + CGFloat(rad * sin(angle))
                let a = 0.02 + 0.05 * rng.next()
                context.fill(Path(CGRect(x: x, y: y, width: 0.8, height: 0.8)), with: .color(Color.white.opacity(a)))
            }
        }
        .frame(width: f, height: f)
        .clipShape(Circle())
    }

    // MARK: Groove the progress indicator runs in

    private var groove: some View {
        let g = geometry
        return ZStack {
            Circle().stroke(
                LinearGradient(
                    colors: [Color.black.opacity(0.9), Color.white.opacity(0.09)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: g.ringWidth + 2
            )
            Circle().stroke(Color.black.opacity(0.95), lineWidth: g.ringWidth)
        }
        .frame(width: g.ringDiameter, height: g.ringDiameter)
    }

    // MARK: Ticks (60 divisions)

    private var ticks: some View {
        let g = geometry
        return Canvas { context, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = g.faceRadius * 0.80
            for i in 0..<60 {
                let major = i % 5 == 0
                let length = g.faceRadius * (major ? 0.075 : 0.035)
                let angle = Double(i) / 60 * 2 * Double.pi - Double.pi / 2
                let dx = CGFloat(cos(angle)), dy = CGFloat(sin(angle))
                var path = Path()
                path.move(to: CGPoint(x: c.x + dx * outer, y: c.y + dy * outer))
                path.addLine(to: CGPoint(x: c.x + dx * (outer - length), y: c.y + dy * (outer - length)))
                context.stroke(
                    path,
                    with: .color(Color.white.opacity(major ? 0.36 : 0.15)),
                    style: StrokeStyle(lineWidth: major ? 1.3 : 0.7, lineCap: .butt)
                )
            }
        }
        .frame(width: g.total, height: g.total)
    }
}
