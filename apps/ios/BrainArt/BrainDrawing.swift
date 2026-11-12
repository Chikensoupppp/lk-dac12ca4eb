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

    static let outline: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 70, y: 132))
        p.addCurve(to: CGPoint(x: 132, y: 48), control1: CGPoint(x: 36, y: 88), control2: CGPoint(x: 80, y: 32))
        p.addCurve(to: CGPoint(x: 232, y: 48), control1: CGPoint(x: 150, y: 10), control2: CGPoint(x: 216, y: 10))
        p.addCurve(to: CGPoint(x: 298, y: 126), control1: CGPoint(x: 282, y: 32), control2: CGPoint(x: 322, y: 82))
        p.addCurve(to: CGPoint(x: 264, y: 216), control1: CGPoint(x: 332, y: 154), control2: CGPoint(x: 314, y: 216))
        p.addCurve(to: CGPoint(x: 170, y: 232), control1: CGPoint(x: 252, y: 250), control2: CGPoint(x: 198, y: 260))
        p.addCurve(to: CGPoint(x: 74, y: 204), control1: CGPoint(x: 136, y: 260), control2: CGPoint(x: 74, y: 242))
        p.addCurve(to: CGPoint(x: 70, y: 132), control1: CGPoint(x: 34, y: 192), control2: CGPoint(x: 30, y: 142))
        p.closeSubpath()
        return p
    }()

    static let wrinkles: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 132, y: 50)); p.addCurve(to: CGPoint(x: 164, y: 98), control1: CGPoint(x: 126, y: 76), control2: CGPoint(x: 142, y: 92))
        p.move(to: CGPoint(x: 232, y: 50)); p.addCurve(to: CGPoint(x: 200, y: 98), control1: CGPoint(x: 238, y: 76), control2: CGPoint(x: 222, y: 92))
        p.move(to: CGPoint(x: 100, y: 176)); p.addCurve(to: CGPoint(x: 154, y: 192), control1: CGPoint(x: 122, y: 166), control2: CGPoint(x: 144, y: 176))
        p.move(to: CGPoint(x: 264, y: 168)); p.addCurve(to: CGPoint(x: 220, y: 188), control1: CGPoint(x: 248, y: 162), control2: CGPoint(x: 226, y: 172))
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

        // Body: soft offset shadow, halftone dots, cream outline, folds.
        c.fill(outline.applying(CGAffineTransform(translationX: 7, y: 6)), with: .color(color.opacity(0.35)))
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
            c.stroke(line([CGPoint(x: 86, y: 196), CGPoint(x: 104, y: 202), CGPoint(x: 98, y: 216), CGPoint(x: 114, y: 226)]),
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

        // Stem.
        c.stroke(line([CGPoint(x: 182, y: 268), CGPoint(x: 182, y: 294)]), with: .color(cream), style: StrokeStyle(lineWidth: 12, lineCap: .round))
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
