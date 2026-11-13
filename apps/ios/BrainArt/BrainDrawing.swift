import SwiftUI

/// The printed pink brain and its heart trace. Shared by the onboarding brain slide (app) and the
/// home screen widget, so both draw the same brain. Stages: 0 fresh ... 5 rotten.
enum BrainDrawing {
    static func rgb(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    static let bg = rgb(0x0B1A16)
    static let panel = rgb(0x10241F)
    static let grid = rgb(0x16332B)
    static let green = rgb(0x4BFF9A)
    static let alarm = rgb(0xFF3B3B)
    static let yellow = rgb(0xFFC233)
    static let cream = rgb(0xF2ECE1)
    static let tear = rgb(0x7FD8FF)
    static let tongueColor = rgb(0xFF8FB8)
    static let stink = rgb(0x8C9670)
    /// Body color per stage: hot pink drains to a sick grey-green.
    static let body: [Color] = ([0xFF5FA2, 0xFF7AA6, 0xEE93A0, 0xCFA08C, 0xADA37A, 0x8C9670] as [UInt32]).map { rgb($0) }
    static let bpmBase = [72, 98, 126, 154, 188, 0]

    // MARK: Heart trace

    /// The trace. It scrolls at a fixed speed, so a faster heart puts beats closer together.
    /// Stage 3 skips beats, stage 4 has no clear beats. Stage 5 is flat, unless `neverFlat`
    /// (the widget), where it is a weak, slow, uneven beat: still alive.
    static func ecg(stage: Int, t: Double, width: CGFloat, mid: CGFloat = 58, scale: CGFloat = 1,
                    beat: Double = 90, neverFlat: Bool = false) -> Path {
        let weak = stage == 5 && neverFlat
        let amp: CGFloat = ([34, 34, 32, 30, 0, weak ? 26 : 0] as [CGFloat])[stage] * scale
        let bpm = weak ? 38 : bpmBase[stage]
        let period = bpm > 0 ? beat * 72 / Double(bpm) : beat
        var p = Path()
        p.move(to: CGPoint(x: 0, y: mid))
        var x: CGFloat = 0
        while x <= width {
            var y = mid
            let xd = Double(x)
            if stage == 4 {
                y = mid + CGFloat(sin(xd * 0.21 / Double(scale) + t * 9) * 11 + sin(xd * 0.53 / Double(scale) + t * 13) * 7
                                  + sin(xd * 0.09 / Double(scale) - t * 5) * 6) * scale
            } else if amp > 0 {
                let pos = (xd + t * 108 * Double(scale)) / period
                let n = Int(pos.rounded(.down))
                let ph = pos - Double(n)
                let skip = stage == 3 && n % 4 == 2
                var a = amp
                if stage == 3 && n % 3 == 0 { a *= 0.7 }
                if weak && n % 2 == 1 { a *= 0.6 }
                if !skip {
                    if ph > 0.30 && ph < 0.36 { y = mid - a * 0.22 }
                    else if ph > 0.42 && ph < 0.46 { y = mid + a * 0.22 }
                    else if ph >= 0.46 && ph < 0.50 { y = mid - a }
                    else if ph >= 0.50 && ph < 0.54 { y = mid + a * 0.45 }
                    else if ph > 0.64 && ph < 0.76 { y = mid - a * 0.22 }
                }
            }
            p.addLine(to: CGPoint(x: x, y: y))
            x += 2
        }
        return p
    }

    static func traceColor(_ stage: Int) -> Color { stage == 5 ? alarm : green }

    static func levelColor(_ stage: Int) -> Color {
        switch stage {
        case 4, 5: return alarm
        case 3: return yellow
        default: return green
        }
    }

    // MARK: The brain, in a 364 by 300 drawing space

    // A side view, like a real brain but cartoon: big round frontal lobe on the left, a narrower
    // back, the temporal lobe hanging under the middle, the cerebellum tucked underneath, and the
    // brainstem. The edge is lumpy (each stretch bulges out a little) so it reads as folds.

    /// Clockwise points around the cerebrum, from the forehead, and how far each stretch bulges.
    private static let cerebrumPoints: [(CGFloat, CGFloat)] = [
        (46, 140), (50, 98), (80, 58), (124, 32), (176, 22), (228, 26), (274, 44), (308, 76), (326, 114),
        (318, 150), (290, 176), (246, 198), (198, 218), (152, 222), (114, 208), (96, 190), (112, 176), (78, 176)
    ]
    private static let cerebrumBumps: [CGFloat] = [12, 12, 11, 10, 10, 10, 9, 8, 7, 7, 6, 6, 6, 7, 6, 3, -4, 8]
    private static let cerebellumPoints: [(CGFloat, CGFloat)] = [
        (244, 184), (278, 166), (312, 158), (332, 178), (326, 208), (294, 224), (256, 216)
    ]
    private static let cerebellumBumps: [CGFloat] = [5, 5, 6, 6, 6, 5, 4]

    /// A closed outline whose stretches bulge outward (points go clockwise on screen).
    private static func lumpy(_ pts: [(CGFloat, CGFloat)], _ bumps: [CGFloat]) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
        for i in pts.indices {
            let a = pts[i], b = pts[(i + 1) % pts.count]
            let dx = b.0 - a.0, dy = b.1 - a.1
            let len = max(sqrt(dx * dx + dy * dy), 1)
            let k = bumps[i]
            p.addQuadCurve(to: CGPoint(x: b.0, y: b.1),
                           control: CGPoint(x: (a.0 + b.0) / 2 + dy / len * k, y: (a.1 + b.1) / 2 - dx / len * k))
        }
        p.closeSubpath()
        return p
    }

    static let outline: Path = lumpy(cerebrumPoints, cerebrumBumps)
    static let cerebellum: Path = lumpy(cerebellumPoints, cerebellumBumps)

    static let wrinkles: Path = {
        var p = Path()
        func c(_ a: (CGFloat, CGFloat), _ c1: (CGFloat, CGFloat), _ c2: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat)) {
            p.move(to: CGPoint(x: a.0, y: a.1))
            p.addCurve(to: CGPoint(x: b.0, y: b.1), control1: CGPoint(x: c1.0, y: c1.1), control2: CGPoint(x: c2.0, y: c2.1))
        }
        func q(_ a: (CGFloat, CGFloat), _ ctl: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat)) {
            p.move(to: CGPoint(x: a.0, y: a.1))
            p.addQuadCurve(to: CGPoint(x: b.0, y: b.1), control: CGPoint(x: ctl.0, y: ctl.1))
        }
        // Lateral fissure, kept clear of the face, with its short upward branch.
        c((112, 180), (150, 188), (204, 184), (252, 166))
        q((252, 166), (262, 150), (280, 146))
        // Central sulcus.
        c((200, 24), (184, 46), (210, 66), (186, 104))
        // Frontal folds.
        c((80, 72), (100, 60), (112, 86), (136, 74))
        c((56, 112), (74, 100), (90, 126), (114, 110))
        c((142, 40), (156, 56), (130, 70), (148, 92))
        q((70, 152), (88, 140), (108, 150))
        // Parietal and occipital folds.
        c((236, 38), (222, 60), (256, 70), (238, 102))
        c((270, 60), (286, 78), (262, 92), (282, 112))
        c((304, 92), (290, 110), (316, 120), (300, 138))
        // Temporal fold, right of the mouth.
        q((222, 206), (240, 192), (268, 188))
        return p
    }()

    /// The cerebellum's stripes.
    static let folia: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 258, y: 194)); p.addQuadCurve(to: CGPoint(x: 326, y: 184), control: CGPoint(x: 292, y: 182))
        p.move(to: CGPoint(x: 262, y: 208)); p.addQuadCurve(to: CGPoint(x: 324, y: 200), control: CGPoint(x: 294, y: 198))
        return p
    }()

    /// The halftone dots, built once.
    static let dots: Path = {
        var p = Path()
        var y: CGFloat = 0
        while y < 300 {
            var x: CGFloat = 0
            while x < 364 {
                p.addEllipse(in: CGRect(x: x + 0.8, y: y + 0.8, width: 5.4, height: 5.4))
                x += 7
            }
            y += 7
        }
        return p
    }()

    private static func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    private static func line(_ pts: [CGPoint]) -> Path {
        var p = Path()
        if let first = pts.first { p.move(to: first) }
        for pt in pts.dropFirst() { p.addLine(to: pt) }
        return p
    }

    private static func bandage(_ ctx: inout GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                                angle: Double, pivot: CGPoint, slits: Bool) {
        var c = ctx
        c.translateBy(x: pivot.x, y: pivot.y)
        c.rotate(by: .degrees(angle))
        c.translateBy(x: -pivot.x, y: -pivot.y)
        let rect = Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: 6)
        c.fill(rect, with: .color(cream))
        c.stroke(rect, with: .color(bg), lineWidth: 4)
        if slits {
            var s = Path()
            for sx in [x + 22, x + 30, x + 38] { s.move(to: CGPoint(x: sx, y: y + 4)); s.addLine(to: CGPoint(x: sx, y: y + 18)) }
            c.stroke(s, with: .color(bg), lineWidth: 2.5)
        }
    }

    /// Draws the brain for `stage` at time `t` (0 for a still picture) into a 364 by 300 space.
    static func drawBrain(in ctx: inout GraphicsContext, stage st: Int, t: Double) {
        let color = body[st]
        let ink = bg
        let round = StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
        let sway = st >= 3 ? sin(t * 1.4) * Double(st - 2) * 1.6 : sin(t * 2) * 1.2
        let droop: CGFloat = ([0, 0, 0, 6, 10, 18] as [CGFloat])[st]
        let shake: CGFloat = st == 4 ? CGFloat(sin(t * 40) * 1.4) : 0

        var c = ctx
        c.translateBy(x: shake, y: droop)
        c.translateBy(x: 182, y: 150)
        c.rotate(by: .degrees(sway + Double(droop) * 0.4))
        c.translateBy(x: -182, y: -150)

        // Brainstem first, so it comes out from under the brain.
        c.stroke(line([CGPoint(x: 226, y: 196), CGPoint(x: 220, y: 292)]), with: .color(cream), style: StrokeStyle(lineWidth: 12, lineCap: .round))

        // Body: soft offset shadow, halftone dots, cream outline, folds. The cerebellum sits
        // behind the cerebrum in a slightly deeper shade.
        let shadow = CGAffineTransform(translationX: 7, y: 6)
        c.fill(cerebellum.applying(shadow), with: .color(color.opacity(0.35)))
        c.fill(outline.applying(shadow), with: .color(color.opacity(0.35)))
        var back = c
        back.clip(to: cerebellum)
        back.fill(dots, with: .color(color.opacity(0.85)))
        c.stroke(cerebellum, with: .color(cream), style: StrokeStyle(lineWidth: 7, lineJoin: .round))
        c.stroke(folia, with: .color(cream.opacity(0.7)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        c.fill(outline, with: .color(bg))
        var dotted = c
        dotted.clip(to: outline)
        dotted.fill(dots, with: .color(color))
        c.stroke(outline, with: .color(cream), style: StrokeStyle(lineWidth: 7, lineJoin: .round))
        c.stroke(wrinkles, with: .color(cream.opacity(0.7)), style: StrokeStyle(lineWidth: 5, lineCap: .round))

        // Damage that stays.
        if st == 1 {
            var drop = Path()
            drop.move(to: CGPoint(x: 262, y: 96))
            drop.addQuadCurve(to: CGPoint(x: 262, y: 118), control: CGPoint(x: 270, y: 110))
            drop.addQuadCurve(to: CGPoint(x: 262, y: 96), control: CGPoint(x: 254, y: 110))
            c.fill(drop, with: .color(tear))
            c.stroke(drop, with: .color(ink), lineWidth: 3)
        }
        if st >= 2 { bandage(&c, x: 92, y: 78, w: 60, h: 22, angle: -24, pivot: CGPoint(x: 120, y: 90), slits: true) }
        if st >= 3 {
            c.stroke(line([CGPoint(x: 232, y: 60), CGPoint(x: 222, y: 82), CGPoint(x: 236, y: 90), CGPoint(x: 224, y: 114)]),
                     with: .color(ink), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
        if st >= 4 {
            c.stroke(line([CGPoint(x: 62, y: 120), CGPoint(x: 80, y: 128), CGPoint(x: 72, y: 140), CGPoint(x: 90, y: 150)]),
                     with: .color(ink), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            bandage(&c, x: 244, y: 160, w: 56, h: 20, angle: 20, pivot: CGPoint(x: 270, y: 170), slits: false)
        }
        if st == 5 {
            for i in 0..<3 {
                let x = CGFloat(130 + i * 50)
                let y0 = CGFloat(40 - (t * 30 + Double(i) * 10).truncatingRemainder(dividingBy: 30))
                var s = Path()
                s.move(to: CGPoint(x: x, y: y0))
                s.addQuadCurve(to: CGPoint(x: x, y: y0 - 20), control: CGPoint(x: x - 8, y: y0 - 10))
                s.addQuadCurve(to: CGPoint(x: x, y: y0 - 40), control: CGPoint(x: x + 8, y: y0 - 30))
                c.stroke(s, with: .color(stink.opacity(0.8)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
            for i in 0..<2 {
                let a = t * 3 + Double(i) * 3
                let fx = CGFloat(182 + cos(a) * 130), fy = CGFloat(120 + sin(a * 1.3) * 60)
                c.fill(circle(fx, fy, 4), with: .color(cream))
                c.fill(Path(ellipseIn: CGRect(x: fx - 9, y: fy - 8, width: 10, height: 6)), with: .color(cream.opacity(0.5)))
            }
        }

        // Eyes.
        let ey: CGFloat = 150
        for (i, x) in [CGFloat(150), CGFloat(214)].enumerated() {
            switch st {
            case 0:
                c.fill(circle(x, ey, 17), with: .color(cream)); c.stroke(circle(x, ey, 17), with: .color(ink), lineWidth: 5)
                c.fill(circle(x + 3, ey + 2, 8), with: .color(ink)); c.fill(circle(x + 6, ey - 2, 3), with: .color(cream))
            case 1:
                c.fill(circle(x, ey, 16), with: .color(cream)); c.stroke(circle(x, ey, 16), with: .color(ink), lineWidth: 5)
                c.fill(circle(x, ey + 3, 7), with: .color(ink))
                let tilt: CGFloat = i == 1 ? 6 : -6
                c.stroke(line([CGPoint(x: x - 16, y: ey - 26 - tilt), CGPoint(x: x + 16, y: ey - 26 + tilt)]), with: .color(ink), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            case 2:
                c.fill(circle(x, ey, 17), with: .color(cream)); c.stroke(circle(x, ey, 17), with: .color(ink), lineWidth: 5)
                var spiral = Path()
                let spin = t * 300 * .pi / 180
                for k in 0...60 {
                    let f = Double(k) / 60
                    let ang = f * 5 * .pi + spin
                    let r = 1 + f * 10
                    let pt = CGPoint(x: x + CGFloat(cos(ang) * r), y: ey + CGFloat(sin(ang) * r))
                    if k == 0 { spiral.move(to: pt) } else { spiral.addLine(to: pt) }
                }
                c.stroke(spiral, with: .color(ink), lineWidth: 3.2)
            case 3:
                c.fill(circle(x, ey + 4, 15), with: .color(cream)); c.stroke(circle(x, ey + 4, 15), with: .color(ink), lineWidth: 5)
                c.fill(circle(x, ey + 9, 6), with: .color(ink))
                var lid = Path()
                lid.move(to: CGPoint(x: x - 16, y: ey + 1))
                lid.addQuadCurve(to: CGPoint(x: x + 16, y: ey + 1), control: CGPoint(x: x, y: ey - 20))
                lid.closeSubpath()
                c.fill(lid, with: .color(color))
                c.stroke(line([CGPoint(x: x - 17, y: ey + 2), CGPoint(x: x + 17, y: ey + 2)]), with: .color(ink), style: round)
            case 4:
                var shut = Path()
                shut.move(to: CGPoint(x: x - 15, y: ey + 2))
                shut.addQuadCurve(to: CGPoint(x: x + 15, y: ey + 2), control: CGPoint(x: x, y: ey - 12))
                c.stroke(shut, with: .color(ink), style: round)
                let k = CGFloat((t * 60).truncatingRemainder(dividingBy: 20))
                let dx: CGFloat = i == 1 ? 8 : -8
                var tearPath = Path()
                tearPath.move(to: CGPoint(x: x + dx, y: ey + 8))
                tearPath.addQuadCurve(to: CGPoint(x: x + dx, y: ey + 38 + k), control: CGPoint(x: x + dx + (i == 1 ? 4 : -4), y: ey + 26 + k))
                c.stroke(tearPath, with: .color(tear.opacity(0.9)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            default:
                var xs = Path()
                xs.move(to: CGPoint(x: x - 12, y: ey - 12)); xs.addLine(to: CGPoint(x: x + 12, y: ey + 12))
                xs.move(to: CGPoint(x: x + 12, y: ey - 12)); xs.addLine(to: CGPoint(x: x - 12, y: ey + 12))
                c.stroke(xs, with: .color(ink), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            }
        }

        // Mouth.
        let mx: CGFloat = 182, my: CGFloat = 200
        switch st {
        case 0:
            var m = Path()
            m.move(to: CGPoint(x: mx - 26, y: my - 6))
            m.addQuadCurve(to: CGPoint(x: mx + 26, y: my - 6), control: CGPoint(x: mx, y: my + 20))
            m.closeSubpath()
            c.fill(m, with: .color(ink)); c.stroke(m, with: .color(ink), style: round)
            var tongue = Path()
            tongue.move(to: CGPoint(x: mx - 12, y: my + 5))
            tongue.addQuadCurve(to: CGPoint(x: mx + 12, y: my + 5), control: CGPoint(x: mx, y: my + 13))
            c.fill(tongue, with: .color(tongueColor))
        case 1:
            var m = Path()
            m.move(to: CGPoint(x: mx - 24, y: my))
            m.addQuadCurve(to: CGPoint(x: mx - 8, y: my), control: CGPoint(x: mx - 16, y: my - 8))
            m.addQuadCurve(to: CGPoint(x: mx + 8, y: my), control: CGPoint(x: mx, y: my + 8))
            m.addQuadCurve(to: CGPoint(x: mx + 24, y: my), control: CGPoint(x: mx + 16, y: my - 8))
            c.stroke(m, with: .color(ink), style: round)
        case 2:
            c.fill(Path(ellipseIn: CGRect(x: mx - 11, y: my - 14, width: 22, height: 28)), with: .color(ink))
        case 3:
            c.stroke(line([CGPoint(x: mx - 22, y: my + 2), CGPoint(x: mx + 22, y: my + 2)]), with: .color(ink), style: round)
        case 4:
            var m = Path()
            m.move(to: CGPoint(x: mx - 26, y: my + 12))
            m.addQuadCurve(to: CGPoint(x: mx + 26, y: my + 12), control: CGPoint(x: mx, y: my - 14))
            m.closeSubpath()
            c.fill(m, with: .color(ink)); c.stroke(m, with: .color(ink), style: StrokeStyle(lineWidth: 5, lineJoin: .round))
        default:
            c.stroke(line([CGPoint(x: mx - 24, y: my), CGPoint(x: mx + 24, y: my)]), with: .color(ink), style: round)
            var tongue = Path()
            tongue.move(to: CGPoint(x: mx + 2, y: my))
            tongue.addLine(to: CGPoint(x: mx + 2, y: my + 16))
            tongue.addQuadCurve(to: CGPoint(x: mx + 20, y: my + 16), control: CGPoint(x: mx + 11, y: my + 34))
            tongue.addLine(to: CGPoint(x: mx + 20, y: my))
            c.fill(tongue, with: .color(tongueColor))
            c.stroke(tongue, with: .color(ink), lineWidth: 5)
        }

    }
}

/// The brain as a view: fits a 364 by 300 drawing into whatever space it gets.
struct BrainCanvas: View {
    let stage: Int
    var t: Double = 0

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width / 364, size.height / 300)
            ctx.translateBy(x: (size.width - 364 * s) / 2, y: (size.height - 300 * s) / 2)
            ctx.scaleBy(x: s, y: s)
            BrainDrawing.drawBrain(in: &ctx, stage: min(max(stage, 0), 5), t: t)
        }
    }
}
