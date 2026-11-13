import SwiftUI

/// The coach uses the same mascot, with a few expressions for pointing and celebrating.
enum CoachExpression { case normal, lookDown, keen, cheer }

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
    static let tongueColor = rgb(0xFF6E8C)
    static let stink = rgb(0x8C9670)
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

    // The mascot: a soft plush cartoon brain (Brandon picked it 2026-11-13, made in Figma:
    // docs/design/brain-mascot-chosen.png). Pastel pink, a darker pink lower half, short glossy
    // marks, swirl folds and a split on top, a soft plum outline inside a cream sticker border. As phone time adds
    // up it fades from pink to grey-green, loses its shine and sparkles, and gets bandages,
    // cracks and a sadder face. Drawn in a 364 by 300 space.

    static let outlineInk = rgb(0x40162A)
    /// The body outline: a softer plum than the eyes.
    static let edgeInk = rgb(0x6B4561)
    static let gold = rgb(0xFFC440)
    static let blush = rgb(0xF08DB0)
    /// Body, bottom shade and fold color for each stage, 0 fresh to 5 rotten.
    static let palette: [(body: Color, shade: Color, fold: Color)] = ([
        (0xF9BAD2, 0xF1A2C1, 0xE597B8), (0xF7B4C8, 0xEC9DB6, 0xDF8FAA), (0xF0A0AA, 0xDA7888, 0xCE6C7C),
        (0xD6A696, 0xBC8476, 0xB2786C), (0xBAAA82, 0xA08E68, 0x968260), (0x989E76, 0x7E845E, 0x747A58)
    ] as [(UInt32, UInt32, UInt32)]).map { (rgb($0.0), rgb($0.1), rgb($0.2)) }

    /// 15 even points on an oval wider than tall; each stretch between two bulges outward: a squishy
    /// plush brain. Keep in step with Outline() in apps/windows-companion/Watch/BrainArt.cs.
    static let outline: Path = {
        // A smooth round dome on top (small bumps), puffy bumps around the sides and bottom.
        let n = 15
        let pts: [CGPoint] = (0..<n).map { i in
            let a = 2 * Double.pi * Double(i) / Double(n) - Double.pi / 2
            let up = sin(a) < 0
            return CGPoint(x: (182 + 120 * cos(a)).rounded(), y: (160 + (up ? 112 : 94) * sin(a)).rounded())
        }
        let bumps: [CGFloat] = (0..<n).map { i in
            let mid = 2 * Double.pi * Double(i) / Double(n) - Double.pi / 2 + Double.pi / Double(n)
            let top = max(0, -sin(mid))
            return CGFloat(20 - 13 * top * top)
        }
        var p = Path()
        p.move(to: pts[0])
        for i in pts.indices {
            let a = pts[i], b = pts[(i + 1) % pts.count]
            let dx = b.x - a.x, dy = b.y - a.y
            let len = max(sqrt(dx * dx + dy * dy), 1)
            p.addQuadCurve(to: b, control: CGPoint(x: (a.x + b.x) / 2 + dy / len * bumps[i],
                                                   y: (a.y + b.y) / 2 - dx / len * bumps[i]))
        }
        p.closeSubpath()
        return p
    }()

    /// Soft curls, mirrored left and right, and a split down the top middle.
    static let folds: Path = {
        var p = Path()
        // A three-quarter loop (angles in degrees, y down, like GDI+ AddArc) with a tail off its end.
        func curl(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, right: Bool, start: CGFloat) {
            let sweep: CGFloat = right ? -270 : 270
            let steps = 28
            for k in 0...steps {
                let a = Double(start + sweep * CGFloat(k) / CGFloat(steps)) * Double.pi / 180
                let pt = CGPoint(x: cx + r * CGFloat(cos(a)), y: cy + r * CGFloat(sin(a)))
                if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            let end = Double(start + sweep) * Double.pi / 180
            let ex = cx + r * CGFloat(cos(end)), ey = cy + r * CGFloat(sin(end))
            let tail: CGFloat = right ? -1 : 1
            p.addQuadCurve(to: CGPoint(x: ex - tail * r * 0.5, y: ey + r * 1.5),
                           control: CGPoint(x: ex + tail * r * 0.2, y: ey + r * 0.9))
        }
        func pair(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ start: CGFloat) {
            curl(x, y, r, right: false, start: start)
            curl(364 - x, y, r, right: true, start: 180 - start)
        }
        pair(142, 78, 19, 180); pair(92, 112, 15, 200); pair(140, 136, 13, 190)
        pair(80, 168, 14, 210); pair(96, 222, 13, 230)
        p.move(to: CGPoint(x: 182, y: 52))
        p.addCurve(to: CGPoint(x: 182, y: 124), control1: CGPoint(x: 176, y: 78), control2: CGPoint(x: 188, y: 100))
        p.addCurve(to: CGPoint(x: 182, y: 152), control1: CGPoint(x: 178, y: 136), control2: CGPoint(x: 184, y: 146))
        p.move(to: CGPoint(x: 182, y: 244)); p.addLine(to: CGPoint(x: 182, y: 262))
        return p
    }()

    private static func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    private static func oval(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2))
    }

    private static func line(_ pts: [CGPoint]) -> Path {
        var p = Path()
        if let first = pts.first { p.move(to: first) }
        for pt in pts.dropFirst() { p.addLine(to: pt) }
        return p
    }

    /// A four-point twinkle star.
    private static func star(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
        var p = Path()
        for i in 0..<8 {
            let a = Double.pi / 4 * Double(i) - Double.pi / 2
            let rr = i % 2 == 0 ? r : r * 0.28
            let pt = CGPoint(x: x + rr * CGFloat(cos(a)), y: y + rr * CGFloat(sin(a)))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    private static func bandage(_ ctx: inout GraphicsContext) {
        let x: CGFloat = 98, y: CGFloat = 92, w: CGFloat = 58, h: CGFloat = 20
        var c = ctx
        c.translateBy(x: x + w / 2, y: y + h / 2)
        c.rotate(by: .degrees(-24))
        c.translateBy(x: -(x + w / 2), y: -(y + h / 2))
        let rect = Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: 6)
        c.fill(rect, with: .color(cream))
        c.stroke(rect, with: .color(outlineInk), lineWidth: 4)
        var s = Path()
        for sx in [x + 22, x + 29, x + 36] { s.move(to: CGPoint(x: sx, y: y + 5)); s.addLine(to: CGPoint(x: sx, y: y + 15)) }
        c.stroke(s, with: .color(outlineInk), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    }

    /// Draws the brain for `stage` at time `t` (0 for a still picture) into a 364 by 300 space.
    static func drawBrain(in ctx: inout GraphicsContext, stage st: Int, t: Double, expression: CoachExpression = .normal) {
        let colors = palette[st]
        let ink = outlineInk
        let round = StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round)
        let sway = st >= 3 ? sin(t * 1.4) * Double(st - 2) * 1.6 : sin(t * 2) * 1.2
        let droop: CGFloat = ([0, 0, 0, 6, 10, 18] as [CGFloat])[st]
        let shake: CGFloat = st == 4 ? CGFloat(sin(t * 40) * 1.4) : 0

        // Sparkles while it is still doing well; they twinkle.
        if st <= 1 {
            for (i, s) in [(56.0, 50.0, 16.0), (320.0, 66.0, 11.0), (322.0, 236.0, 9.0)].enumerated() {
                let k = 1 + 0.15 * sin(t * 3 + Double(i) * 2)
                ctx.fill(star(s.0, s.1, s.2 * k), with: .color(gold))
            }
        }

        var c = ctx
        c.translateBy(x: shake, y: droop)
        c.translateBy(x: 182, y: 150)
        c.rotate(by: .degrees(sway + Double(droop) * 0.4))
        // The round brain is narrower than the space; scale it up so it fills about as much as
        // the old brain did.
        c.translateBy(x: 0, y: 2)
        c.scaleBy(x: 1.08, y: 1.08)
        c.translateBy(x: -182, y: -150)

        // Body: cream sticker border, bottom shade, pink body lifted up-left so the shade shows,
        // shine, folds, outline.
        c.stroke(outline, with: .color(cream), style: StrokeStyle(lineWidth: 18, lineJoin: .round))
        c.fill(outline, with: .color(colors.shade))
        var inside = c
        inside.clip(to: outline)
        inside.fill(outline.applying(CGAffineTransform(translationX: -3, y: -40)), with: .color(colors.body))
        if st <= 2 {
            // Short glossy marks on the top bumps.
            var shine = Path()
            for (a, ctl, b) in [((86.0, 120.0), (88.0, 104.0), (100.0, 94.0)), ((134.0, 76.0), (144.0, 70.0), (156.0, 70.0)),
                                ((208.0, 70.0), (220.0, 70.0), (230.0, 76.0)), ((266.0, 94.0), (278.0, 102.0), (280.0, 118.0))] {
                shine.move(to: CGPoint(x: a.0, y: a.1))
                shine.addQuadCurve(to: CGPoint(x: b.0, y: b.1), control: CGPoint(x: ctl.0, y: ctl.1))
            }
            let a = (200 - Double(st) * 50) / 255
            inside.stroke(shine, with: .color(.white.opacity(a)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        }
        inside.stroke(folds, with: .color(colors.fold), style: round)

        // Damage that stays.
        if st >= 2 { bandage(&c) }
        if st >= 3 {
            c.stroke(line([CGPoint(x: 236, y: 60), CGPoint(x: 226, y: 80), CGPoint(x: 240, y: 88), CGPoint(x: 230, y: 110)]),
                     with: .color(ink), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
        if st >= 4 {
            c.stroke(line([CGPoint(x: 84, y: 128), CGPoint(x: 100, y: 136), CGPoint(x: 92, y: 150), CGPoint(x: 108, y: 158)]),
                     with: .color(ink), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
        if st == 5 {
            for i in 0..<3 {
                let x = CGFloat(130 + i * 50)
                let y0 = CGFloat(34 - (t * 30 + Double(i) * 10).truncatingRemainder(dividingBy: 30))
                var s = Path()
                s.move(to: CGPoint(x: x, y: y0))
                s.addQuadCurve(to: CGPoint(x: x, y: y0 - 20), control: CGPoint(x: x - 8, y: y0 - 10))
                s.addQuadCurve(to: CGPoint(x: x, y: y0 - 40), control: CGPoint(x: x + 8, y: y0 - 30))
                c.stroke(s, with: .color(stink.opacity(0.8)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
            for i in 0..<2 {
                let a = t * 3 + Double(i) * 3
                let fx = CGFloat(182 + cos(a) * 140), fy = CGFloat(120 + sin(a * 1.3) * 60)
                c.fill(circle(fx, fy, 4), with: .color(cream))
                c.fill(Path(ellipseIn: CGRect(x: fx - 9, y: fy - 8, width: 10, height: 6)), with: .color(cream.opacity(0.5)))
            }
        }
        c.stroke(outline, with: .color(edgeInk), style: StrokeStyle(lineWidth: 6, lineJoin: .round))

        // Eyes: big and set low, like a baby face.
        let ey: CGFloat = 168
        for (i, x) in [CGFloat(140), CGFloat(224)].enumerated() {
            let side: CGFloat = i == 1 ? 1 : -1
            switch st {
            case 0:
                let look: CGFloat = expression == .lookDown ? 5 : 0
                c.fill(oval(x, ey + look, 13, 15), with: .color(ink))
                c.fill(circle(x - 4, ey - 6 + look, 5.5), with: .color(.white))
                c.fill(circle(x + 5, ey + 7 + look, 2.6), with: .color(.white))
            case 1:
                // Sleepy: the lid covers the top half.
                c.fill(circle(x, ey + 3, 14), with: .color(ink))
                c.fill(circle(x - 4, ey + 2, 4), with: .color(.white))
                c.fill(Path(CGRect(x: x - 17, y: ey - 16, width: 34, height: 15)), with: .color(colors.body))
                c.stroke(line([CGPoint(x: x - 15, y: ey - 1), CGPoint(x: x + 15, y: ey - 1)]), with: .color(ink), style: round)
            case 2:
                var spiral = Path()
                let spin = t * 300 * .pi / 180 + Double(i)
                for k in 0...60 {
                    let f = Double(k) / 60
                    let ang = f * 5 * .pi + spin
                    let r = 1 + f * 12
                    let pt = CGPoint(x: x + CGFloat(cos(ang) * r), y: ey + CGFloat(sin(ang) * r))
                    if k == 0 { spiral.move(to: pt) } else { spiral.addLine(to: pt) }
                }
                c.stroke(spiral, with: .color(ink), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            case 3:
                // Drooping, half shut, a little uneven.
                c.fill(oval(x, ey + 5, 13, 12), with: .color(ink))
                c.fill(Path(CGRect(x: x - 16, y: ey - 12, width: 32, height: 16)), with: .color(colors.body))
                c.stroke(line([CGPoint(x: x - 14, y: ey + 3 + (i == 1 ? 0 : 3)), CGPoint(x: x + 14, y: ey + 3 + (i == 1 ? 3 : 0))]),
                         with: .color(ink), style: round)
            case 4:
                var shut = Path()
                shut.move(to: CGPoint(x: x - 13, y: ey + 4))
                shut.addQuadCurve(to: CGPoint(x: x + 13, y: ey + 4), control: CGPoint(x: x, y: ey - 10))
                c.stroke(shut, with: .color(ink), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                let k = CGFloat((t * 60).truncatingRemainder(dividingBy: 16))
                var tearPath = Path()
                tearPath.move(to: CGPoint(x: x + 8 * side, y: ey + 10))
                tearPath.addQuadCurve(to: CGPoint(x: x + 8 * side, y: ey + 40 + k), control: CGPoint(x: x + 12 * side, y: ey + 26 + k))
                c.stroke(tearPath, with: .color(tear.opacity(0.9)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            default:
                var xs = Path()
                xs.move(to: CGPoint(x: x - 11, y: ey - 11)); xs.addLine(to: CGPoint(x: x + 11, y: ey + 11))
                xs.move(to: CGPoint(x: x + 11, y: ey - 11)); xs.addLine(to: CGPoint(x: x - 11, y: ey + 11))
                c.stroke(xs, with: .color(ink), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }
        }
        if st == 0 && expression == .keen {
            for x in [CGFloat(140), CGFloat(224)] {
                var brow = Path()
                brow.move(to: CGPoint(x: x - 15, y: ey - 21))
                brow.addQuadCurve(to: CGPoint(x: x + 15, y: ey - 21), control: CGPoint(x: x, y: ey - 32))
                c.stroke(brow, with: .color(ink), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
        }
        if st <= 2 {
            c.fill(oval(110, 196, 16, 8.5), with: .color(blush))
            c.fill(oval(254, 196, 16, 8.5), with: .color(blush))
        }
        if st == 1 {
            var drop = Path()
            drop.move(to: CGPoint(x: 266, y: 74))
            drop.addQuadCurve(to: CGPoint(x: 266, y: 98), control: CGPoint(x: 276, y: 94))
            drop.addQuadCurve(to: CGPoint(x: 266, y: 74), control: CGPoint(x: 256, y: 94))
            c.fill(drop, with: .color(tear))
            c.stroke(drop, with: .color(ink), lineWidth: 3)
        }

        // Mouth.
        let mx: CGFloat = 182, my: CGFloat = 196
        switch st {
        case 0:
            var m = Path()
            let half: CGFloat = expression == .cheer ? 19 : 11
            m.move(to: CGPoint(x: mx - half, y: my))
            m.addQuadCurve(to: CGPoint(x: mx + half, y: my), control: CGPoint(x: mx, y: my + (expression == .cheer ? 27 : 20)))
            m.closeSubpath()
            c.fill(m, with: .color(ink))
            c.stroke(m, with: .color(ink), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            c.fill(oval(mx, my + 8, 5.5, 3.5), with: .color(tongueColor))
        case 1:
            var m = Path()
            m.move(to: CGPoint(x: mx - 14, y: my + 4))
            m.addQuadCurve(to: CGPoint(x: mx, y: my + 4), control: CGPoint(x: mx - 7, y: my - 2))
            m.addQuadCurve(to: CGPoint(x: mx + 14, y: my + 4), control: CGPoint(x: mx + 7, y: my + 10))
            c.stroke(m, with: .color(ink), style: round)
        case 2:
            c.fill(oval(mx, my + 6, 9, 12), with: .color(ink))
        case 3:
            c.stroke(line([CGPoint(x: mx - 16, y: my + 6), CGPoint(x: mx + 16, y: my + 6)]), with: .color(ink), style: round)
        case 4:
            var m = Path()
            m.move(to: CGPoint(x: mx - 18, y: my + 16))
            m.addQuadCurve(to: CGPoint(x: mx + 18, y: my + 16), control: CGPoint(x: mx, y: my - 8))
            m.closeSubpath()
            c.fill(m, with: .color(ink))
        default:
            c.stroke(line([CGPoint(x: mx - 18, y: my + 4), CGPoint(x: mx + 18, y: my + 4)]), with: .color(ink), style: round)
            var tongue = Path()
            tongue.move(to: CGPoint(x: mx + 2, y: my + 4))
            tongue.addLine(to: CGPoint(x: mx + 2, y: my + 18))
            tongue.addQuadCurve(to: CGPoint(x: mx + 20, y: my + 18), control: CGPoint(x: mx + 11, y: my + 32))
            tongue.addLine(to: CGPoint(x: mx + 20, y: my + 4))
            tongue.closeSubpath()
            c.fill(tongue, with: .color(tongueColor))
            c.stroke(tongue, with: .color(ink), lineWidth: 3)
        }
    }
}

/// The brain as a view: fits a 364 by 300 drawing into whatever space it gets.
struct BrainCanvas: View {
    let stage: Int
    var t: Double = 0
    var expression: CoachExpression = .normal

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width / 364, size.height / 300)
            ctx.translateBy(x: (size.width - 364 * s) / 2, y: (size.height - 300 * s) / 2)
            ctx.scaleBy(x: s, y: s)
            BrainDrawing.drawBrain(in: &ctx, stage: min(max(stage, 0), 5), t: t, expression: expression)
        }
    }
}
