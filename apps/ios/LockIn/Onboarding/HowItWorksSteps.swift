import FamilyControls
import ManagedSettings
import SwiftUI

// Three "how it works" slides between the goals and the plan (mock: docs/design/how-it-works-v2.html).
// They share one moving background, a riso halftone field, and each slide is something the user does:
// slide the real lock slider, swipe notifications away to "Later", watch the week stack up.
// One short line each. No help paragraphs.

// MARK: Moving halftone background

/// A wave that spreads out through the dots from one point, then fades.
struct FieldRipple: Identifiable {
    let id = UUID()
    /// Where it starts, as a fraction of the screen.
    let origin: UnitPoint
    let start: Date
    var amp: Double = 0.9
    var speed: Double = 520
}

/// Two inks a little off-register, like a real riso print: blue dots everywhere the wave is,
/// sunflower dots only on its crest. The wave drifts slowly up and across (no back-and-forth pulse)
/// and stays low on the page so the headline is always clean. Still when motion is limited.
struct HalftoneField: View {
    /// Where the dots begin, as a fraction of the height. They fade in over the next 35%.
    var fadeStart: CGFloat = 0.55
    var ripples: [FieldRipple] = []
    @State private var born = Date()
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        let still = motionLimited(systemReduceMotion)
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: still)) { context in
            let t = still ? 2.0 : context.date.timeIntervalSince(born)
            let live = still ? [] : ripples
            Canvas { ctx, size in
                Self.draw(in: &ctx, size: size, t: t, now: context.date, fadeStart: Double(fadeStart), ripples: live)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private struct LiveRipple {
        let x: Double, y: Double, dt: Double, amp: Double, speed: Double
    }

    private static func draw(in ctx: inout GraphicsContext, size: CGSize, t: Double, now: Date,
                             fadeStart: Double, ripples: [FieldRipple]) {
        let width = Double(size.width), height = Double(size.height)
        let top = height * fadeStart, fade = height * 0.35
        let live = ripples.compactMap { r -> LiveRipple? in
            let dt = now.timeIntervalSince(r.start)
            guard dt >= 0, dt < 4 else { return nil }
            return LiveRipple(x: Double(r.origin.x) * width, y: Double(r.origin.y) * height, dt: dt, amp: r.amp, speed: r.speed)
        }
        let step = 15.0
        var blue = Path(), sun = Path()
        var row = 0
        var y = step / 2
        while y < height + step {
            var x = row.isMultiple(of: 2) ? 0 : step / 2
            while x < width + step {
                let v = value(x: x, y: y, t: t, top: top, fade: fade, ripples: live)
                if v > 0.05 {
                    let rb = 5.4 * min(v, 1)
                    if rb > 0.4 { blue.addEllipse(in: CGRect(x: x - rb, y: y - rb, width: rb * 2, height: rb * 2)) }
                    let rs = 5.6 * min(max((v - 0.62) / 0.5, 0), 1)
                    if rs > 0.4 { sun.addEllipse(in: CGRect(x: x + 2.2 - rs, y: y + 1.6 - rs, width: rs * 2, height: rs * 2)) }
                }
                x += step
            }
            y += step
            row += 1
        }
        // Tone-on-tone: darker and lighter cream dots on the paper, so the objects carry the color.
        ctx.fill(sun, with: .color(Color(hex: 0xC9CAC1).opacity(0.9)))
        ctx.fill(blue, with: .color(Color(hex: 0xB9BAB0).opacity(0.55)))
    }

    private static func value(x: Double, y: Double, t: Double, top: Double, fade: Double, ripples: [LiveRipple]) -> Double {
        let m = min(max((y - top) / fade, 0), 1)
        if m <= 0 { return 0 }
        let a = sin(x * 0.014 - y * 0.010 + t * 0.62 + 1.4 * sin(y * 0.006 + t * 0.18))
        let b = sin(y * 0.012 + x * 0.006 + t * 0.47)
        var v = m * (0.50 + 0.30 * a + 0.20 * b)
        let reach = min(m * 1.8, 1)
        for r in ripples {
            let d = hypot(x - r.x, y - r.y)
            let k = (d - r.dt * r.speed) / 52
            v += r.amp * exp(-k * k) * exp(-r.dt) * reach
        }
        return v
    }
}

/// The caption under the headline. The old line leaves first, then the new one arrives,
/// so the two never overlap.
private struct SwapCaption: View {
    let first: String
    let second: String
    let swapped: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(first)
                .opacity(swapped ? 0 : 1)
                .offset(y: swapped ? -6 : 0)
                .animation(.easeOut(duration: 0.18), value: swapped)
            Text(second)
                .opacity(swapped ? 1 : 0)
                .offset(y: swapped ? 0 : 6)
                .animation(.easeOut(duration: 0.3).delay(0.16), value: swapped)
        }
        .font(PrintFont.mono(14))
        .foregroundStyle(Ink.ink)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(swapped ? second : first)
    }
}

private var compactScreen: Bool { UIScreen.main.bounds.height < 700 }

// MARK: One slide. You're in.

/// The intro's last slide: the real "slide to lock in" control, with the brain as the knob. It
/// follows the finger 1:1, and a flick counts too. A tap also locks it (VoiceOver, UI tests). Sliding
/// starts the first session for real, the one the plan made a few slides back (its task and minutes),
/// over the apps the user picked: after a beat to see LOCKED IN, the intro closes on the running
/// session. "Not now" ends the intro without starting it. NEXT stays for VoiceOver.
struct SlideToLockStep: View {
    @ObservedObject var restrictions: RestrictionController
    let next: () -> Void
    let notNow: () -> Void
    /// The plan made a few slides back: its session length, what the time is for, sessions a day.
    private let plan = PlanStore.load()
    @State private var x: CGFloat = 0
    @State private var locked = false
    @State private var lockedAt: Date?
    @State private var pop = false
    @State private var ripples: [FieldRipple] = []
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    private let height: CGFloat = 76
    private let knob: CGFloat = 64

    var body: some View {
        // No NEXT: the slider sits where it was and moves on by itself. VoiceOver gets a Next after.
        PrintScaffold(step: OnboardingFlow.stepCount, tag: "Start", title: "Slide to start\nyour first\nsession.",
                      primaryView: AnyView(track.padding(.bottom, 6)),
                      secondaryTitle: locked ? (voiceOver ? "Next" : nil) : "Not now",
                      secondaryAction: locked ? next : notNow,
                      backdrop: AnyView(HalftoneField(fadeStart: 0.55, ripples: ripples))) {
            SessionPreview(minutes: plan?.minutes ?? 25, task: plan?.task, sessionsPerDay: plan?.sessionsPerDay ?? 1,
                           restrictions: restrictions, locked: locked, lockedAt: lockedAt)
                .padding(.top, 6)
        }
        .sensoryFeedback(.success, trigger: locked)
        // Sliding is the "next": after a beat to see LOCKED IN, the session takes over by itself.
        // VoiceOver users keep the NEXT button instead of being moved on. Cancelled if they leave first.
        .task(id: locked) {
            guard locked, !voiceOver else { return }
            guard await printPause(1.1) else { return }
            next()
        }
    }

    private var track: some View {
        GeometryReader { proxy in
            let maxX = max(proxy.size.width - height, 1)
            let progress = Double(min(x / maxX, 1))
            ZStack(alignment: .leading) {
                Capsule().fill(Ink.ink)
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: 0x2B4C97), Ink.blue], startPoint: .leading, endPoint: .trailing))
                    .frame(width: height + x)
                    .opacity(x > 0 ? 1 : 0)
                ShimmerLabel(text: "SLIDE TO LOCK IN")
                    .frame(maxWidth: .infinity)
                    .padding(.leading, height - 8)
                    .opacity(1 - min(progress * 2, 1))
                Text("LOCKED IN")
                    .font(.system(size: 15, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.trailing, height - 8)
                    .opacity(locked ? 1 : 0)
                    .accessibilityHidden(true)
                knobView
                    .offset(x: x)
                    .gesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { value in
                                guard !locked else { return }
                                x = min(max(value.translation.width, 0), maxX)
                            }
                            .onEnded { value in
                                guard !locked else { return }
                                // Commit on where the flick was going, not only where the finger let go.
                                if x > maxX * 0.7 || value.predictedEndTranslation.width > maxX { lock(maxX) }
                                else { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { x = 0 } }
                            }
                    )
                    .onTapGesture { lock(maxX) }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(locked ? "Locked in" : "Slide to lock in")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("onboarding-slide-knob")
                    .accessibilityAction { lock(maxX) }
            }
        }
        .frame(height: height)
        .compositingGroup()
        .shadow(color: Ink.ink.opacity(0.22), radius: 15, y: 14)
    }

    private var knobView: some View {
        Circle()
            .fill(RadialGradient(colors: [.white, Color(hex: 0xECEDE8)], center: UnitPoint(x: 0.35, y: 0.3),
                                 startRadius: 0, endRadius: knob * 0.7))
            .frame(width: knob, height: knob)
            .overlay(Image("BrainExact").resizable().scaledToFit().frame(width: knob + 6).offset(y: 1))
            .overlay(alignment: .bottomTrailing) {
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Ink.ink))
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .offset(x: 3, y: 3)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                }
            }
            .shadow(color: .black.opacity(0.35), radius: 7, y: 6)
            .scaleEffect(pop ? 1.08 : 1)
            .padding((height - knob) / 2)
    }

    private func lock(_ maxX: CGFloat) {
        guard !locked else { return }
        lockedAt = .now
        if effectiveReduceMotion(systemReduceMotion) {
            x = maxX
            locked = true
            return
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            x = maxX
            locked = true
        }
        ripples.append(FieldRipple(origin: UnitPoint(x: 0.84, y: 0.62), start: .now, amp: 1.2))
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { pop = true }
        Task {
            guard await printPause(0.16) else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { pop = false }
        }
    }
}

/// What sliding starts, so the space above the slider shows the session: the plan's first session
/// (its task and minutes, and when it would end), and the apps the user picked, drawn by Apple from the
/// Screen Time picks, each getting a lock when it starts. Nothing made up (Brandon, 2026-11-20).
private struct SessionPreview: View {
    let minutes: Int
    let task: String?
    let sessionsPerDay: Int
    @ObservedObject var restrictions: RestrictionController
    let locked: Bool
    let lockedAt: Date?

    private var length: TimeInterval { TimeInterval(minutes * 60) }
    private static let soft = Color(hex: 0x45473F)
    private static let maxIcons = 5

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = remaining(at: context.date)
            let ends = (lockedAt ?? context.date).addingTimeInterval(length)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(locked ? "LOCKED IN" : "READY")
                            .font(PrintFont.mono(11, .bold)).tracking(1.4)
                            .foregroundStyle(locked ? Ink.blue : Self.soft)
                        Text(clock(left))
                            .font(PrintFont.head(64))
                            .monospacedDigit()
                            .foregroundStyle(Ink.ink)
                            .contentTransition(.numericText(countsDown: true))
                        Text(task.map { "\($0), session 1" } ?? "Your first session")
                            .font(PrintFont.bold(17)).foregroundStyle(Ink.ink)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 8)
                    ZStack {
                        Circle().stroke(Ink.ink.opacity(0.12), lineWidth: 9)
                        Circle()
                            .trim(from: 0, to: locked ? max(0.04, 1 - left / length) : 0)
                            .stroke(Ink.blue, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 84, height: 84)
                }
                HStack(spacing: 6) {
                    chip("Ends \(ends.formatted(date: .omitted, time: .shortened))")
                    if sessionsPerDay > 1 { chip("1 of \(sessionsPerDay) today") }
                }
                .padding(.top, 14)
                Text(hasApps ? "THESE WAIT TILL YOU\u{2019}RE DONE" : "NO APPS PICKED YET")
                    .font(PrintFont.mono(11, .bold)).tracking(1.4)
                    .foregroundStyle(Self.soft)
                    .padding(.top, 14)
                if hasApps {
                    appRow
                        .padding(.top, 10)
                        .padding(.bottom, 6)
                } else {
                    Text("Pick them on the Focus screen anytime.")
                        .font(PrintFont.body(14, .medium))
                        .foregroundStyle(Self.soft)
                        .padding(.top, 6)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(Color(hex: 0xF4F4F0)))
        .overlay(shape.strokeBorder(Ink.ink, lineWidth: 2))
        .background(shape.fill(Ink.ink).offset(y: 5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var hasApps: Bool { restrictions.hasSelection }

    /// Picked apps, then picked categories, then websites when that switch is on; "+N" for the rest.
    private var appRow: some View {
        let apps = Array(restrictions.selection.applicationTokens)
        let cats = Array(restrictions.selection.categoryTokens)
        let web = RestrictionNaming.blocksWeb(BrainLevel.shared)
        let shownApps = Array(apps.prefix(Self.maxIcons))
        let shownCats = Array(cats.prefix(max(0, Self.maxIcons - shownApps.count)))
        let extra = apps.count + cats.count - shownApps.count - shownCats.count
        return HStack(spacing: 14) {
            ForEach(Array(shownApps.enumerated()), id: \.offset) { i, token in
                tile(i) { Label(token).labelStyle(.iconOnly) }
            }
            ForEach(Array(shownCats.enumerated()), id: \.offset) { i, token in
                tile(shownApps.count + i) { Label(token).labelStyle(.iconOnly) }
            }
            if extra > 0 {
                Text("+\(extra)")
                    .font(PrintFont.bold(16))
                    .foregroundStyle(Ink.ink)
                    .frame(width: 44, height: 44)
            } else if web {
                tile(shownApps.count + shownCats.count) { AppKindIcon(kind: .web, size: 44) }
            }
        }
    }

    /// One picked app: its real icon, greyed when locked, with a lock that pops on one by one.
    private func tile<Icon: View>(_ i: Int, @ViewBuilder icon: () -> Icon) -> some View {
        icon()
            .frame(width: 44, height: 44)
            .saturation(locked ? 0.2 : 1)
            .opacity(locked ? 0.8 : 1)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Ink.ink))
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                    .offset(x: 7, y: 7)
                    .scaleEffect(locked ? 1 : 0.01)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.55).delay(locked ? 0.15 + Double(i) * 0.12 : 0), value: locked)
    }

    private var accessibilityText: String {
        let what = task.map { "\($0), " } ?? ""
        let apps = hasApps ? "Your picked apps wait till you're done." : "No apps picked yet."
        return locked ? "Locked in. \(what)\(minutes) minutes. \(apps)" : "Ready: \(what)\(minutes) minutes. \(apps)"
    }

    private func remaining(at now: Date) -> TimeInterval {
        guard locked, let lockedAt else { return length }
        return max(length - now.timeIntervalSince(lockedAt), 0)
    }

    private func clock(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .bold))
            .foregroundStyle(Ink.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white))
            .overlay(Capsule().strokeBorder(Ink.ink.opacity(0.18), lineWidth: 1.5))
    }
}

/// "SLIDE TO LOCK IN" with a soft light sweeping across it, left to right.
private struct ShimmerLabel: View {
    let text: String
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        let still = motionLimited(systemReduceMotion)
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: still)) { context in
            let phase = (context.date.timeIntervalSinceReferenceDate * 0.55).truncatingRemainder(dividingBy: 1.4) - 0.2
            label(Ink.paper.opacity(still ? 0.75 : 0.4))
                .overlay {
                    if !still {
                        label(.white)
                            .mask {
                                LinearGradient(stops: [.init(color: .clear, location: 0),
                                                       .init(color: .white, location: 0.5),
                                                       .init(color: .clear, location: 1)],
                                               startPoint: UnitPoint(x: phase - 0.18, y: 0.5),
                                               endPoint: UnitPoint(x: phase + 0.18, y: 0.5))
                            }
                    }
                }
        }
        .accessibilityHidden(true)
    }

    private func label(_ color: Color) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .bold))
            .tracking(3)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

// MARK: Swipe later.

/// A printed lock screen during a session with four pings stacked on it (mock:
/// docs/design/slides-4-7-v2.html, slide 7). The user swipes them right, or they go by themselves
/// after a moment, and each drops into the sunflower "Later" pocket below, which counts them and
/// says when they come back.
struct LaterStep: View {
    let next: () -> Void
    @State private var shown = 0
    @State private var gone: [Int] = []
    @State private var drag: [Int: CGFloat] = [:]
    @State private var ripples: [FieldRipple] = []
    @State private var opened = Date.now
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    /// A ping: a stand-in app icon for its kind of app (`AppKindIcon`, never a real app's), the kind as
    /// the app name, and the line.
    private struct Note {
        let kind: AppKindIcon.Kind
        let app: String
        let text: String
    }

    private static let notes = [
        Note(kind: .social, app: "Social", text: "Mia and 11 others liked your post"),
        Note(kind: .video, app: "Video", text: "Up next in 5\u{2026} 4\u{2026} 3\u{2026}"),
        Note(kind: .games, app: "Games", text: "Your free spin is ready"),
        Note(kind: .chat, app: "Chat", text: "3 new messages in Squad"),
    ]

    private var allGone: Bool { gone.count == Self.notes.count }

    var body: some View {
        PrintScaffold(step: 5, tag: "How it works", title: "Apps and pings\nwait till\nyou\u{2019}re done.", primaryTitle: "NEXT", primaryAction: next,
                      backdrop: AnyView(HalftoneField(fadeStart: 0.62, ripples: ripples))) {
            VStack(spacing: 16) {
                lockScreen
                pocket
            }
            .padding(.top, 4)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: gone.count)
        .sensoryFeedback(.success, trigger: allGone)
        .task { await run() }
    }

    // MARK: The lock screen

    private var lockScreen: some View {
        let shape = RoundedRectangle(cornerRadius: 34, style: .continuous)
        return ZStack(alignment: .top) {
            shape.fill(LinearGradient(colors: [Color(hex: 0x3D4A6B), Color(hex: 0x26304A)], startPoint: .top, endPoint: .bottom))
            Canvas { ctx, size in
                // Sunflower halftone in the lower half, like a riso wallpaper.
                for y in stride(from: size.height * 0.35, to: size.height, by: 12) {
                    let k = (y - size.height * 0.35) / (size.height * 0.65)
                    for x in stride(from: 6.0, to: size.width, by: 12) {
                        let r = 2.2 * k
                        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                                 with: .color(Ink.sun.opacity(0.25)))
                    }
                }
            }
            VStack(spacing: 4) {
                Text(opened.formatted(date: .omitted, time: .shortened).replacingOccurrences(of: " AM", with: "").replacingOccurrences(of: " PM", with: ""))
                    .font(PrintFont.head(compactScreen ? 44 : 56))
                    .foregroundStyle(.white.opacity(0.94))
                Text("\(opened.formatted(.dateTime.weekday(.wide))) \u{00B7} Locked in \u{00B7} 24:12 left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(.top, 20)
            ZStack(alignment: .top) {
                ForEach(Array(Self.notes.indices.reversed()), id: \.self) { i in noteRow(i) }
            }
            .padding(.horizontal, 12)
            .padding(.top, compactScreen ? 84 : 104)
        }
        .frame(height: compactScreen ? 232 : 312)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Ink.ink, lineWidth: 2))
        .background(shape.fill(Ink.ink).offset(y: 6))
        .accessibilityElement(children: .contain)
    }

    private func noteRow(_ i: Int) -> some View {
        let note = Self.notes[i]
        let isIn = i < shown
        let isGone = gone.contains(i)
        let dx: CGFloat = drag[i] ?? 0
        return HStack(spacing: 10) {
            AppKindIcon(kind: note.kind, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(note.app).font(.system(size: 13, weight: .bold)).foregroundStyle(Ink.ink)
                    Spacer()
                    Text("now").font(.system(size: 11, weight: .medium)).foregroundStyle(Ink.soft)
                }
                Text(note.text)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Ink.ink.opacity(0.82))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 62)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.7)))
        }
        .shadow(color: .black.opacity(0.18), radius: 10, y: 8)
        .scaleEffect(isGone ? 0.45 : 1 - CGFloat(i) * 0.04)
        .rotationEffect(.degrees(isGone ? 8 : Double(dx / 300) * 6))
        .offset(x: isGone ? 40 : dx, y: isGone ? 230 : (isIn ? CGFloat(i) * (compactScreen ? 30 : 50) : CGFloat(i) * (compactScreen ? 30 : 50) - 40))
        .opacity(isIn && !isGone ? 1 : 0)
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { value in
                    guard isIn, !isGone else { return }
                    let w = value.translation.width
                    // Right follows the finger; left gives a little and then resists.
                    drag[i] = w >= 0 ? w : -(-w * 40) / (40 + -w)
                }
                .onEnded { value in
                    guard isIn, !isGone else { return }
                    if value.translation.width > 80 || value.predictedEndTranslation.width > 200 { fling(i) }
                    else { withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { drag[i] = 0 } }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(note.app): \(note.text)")
        .accessibilityAction(named: "Swipe to later") { fling(i) }
        .accessibilityHidden(!isIn || isGone)
    }

    // MARK: The Later pocket

    private var pocket: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let back = opened.addingTimeInterval(24 * 60).formatted(date: .omitted, time: .shortened)
        return HStack(spacing: 12) {
            Text("\(gone.count)")
                .font(PrintFont.head(24))
                .foregroundStyle(Ink.sun)
                .contentTransition(.numericText(value: Double(gone.count)))
                .frame(width: 44, height: 44)
                .background(Circle().fill(Ink.ink))
            VStack(alignment: .leading, spacing: 3) {
                Text("Later").font(.system(size: 17, weight: .heavy)).foregroundStyle(Ink.ink)
                if gone.isEmpty {
                    Text("Waiting till you\u{2019}re done").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Ink.ink.opacity(0.75))
                } else {
                    HStack(spacing: -4) {
                        ForEach(gone, id: \.self) { i in
                            Circle().fill(Self.notes[i].tile)
                                .overlay(Circle().strokeBorder(Ink.paper, lineWidth: 1.5))
                                .frame(width: 14, height: 14)
                                .transition(.scale.combined(with: .opacity))
                        }
                        Text("waiting").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Ink.ink.opacity(0.75))
                            .padding(.leading, 10)
                    }
                }
            }
            Spacer(minLength: 6)
            Text("BACK AT \(back.uppercased())")
                .font(PrintFont.mono(11, .bold))
                .foregroundStyle(Ink.sun)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Capsule().fill(Ink.ink))
        }
        .padding(.horizontal, 14)
        .frame(height: 74)
        .background(shape.fill(Ink.sun))
        .overlay(shape.strokeBorder(Ink.ink, lineWidth: 2))
        .background(shape.fill(Ink.ink).offset(y: 5))
        .keyframeAnimator(initialValue: CGFloat(1), trigger: gone.count) { view, s in
            view.scaleEffect(s)
        } keyframes: { _ in
            KeyframeTrack { CubicKeyframe(1.06, duration: 0.12); SpringKeyframe(1, duration: 0.3) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(gone.isEmpty ? "Later: waiting till you're done" : "Later: \(gone.count) waiting, back at \(back)")
    }

    // MARK: Motion

    private func fling(_ i: Int) {
        guard !gone.contains(i) else { return }
        if effectiveReduceMotion(systemReduceMotion) {
            gone.append(i)
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { gone.append(i) }
            ripples.append(FieldRipple(origin: UnitPoint(x: 0.5, y: 0.85), start: Date.now.addingTimeInterval(0.3), amp: 0.7, speed: 480))
        }
    }

    private func run() async {
        if effectiveReduceMotion(systemReduceMotion) {
            shown = Self.notes.count
        } else {
            guard await printPause(0.4) else { return }
            for k in 1...Self.notes.count {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) { shown = k }
                guard await printPause(0.18) else { return }
            }
        }
        // A moment for the user to swipe them away; then the rest go by themselves.
        guard await printPause(2.2) else { return }
        for i in 0..<Self.notes.count where !gone.contains(i) {
            fling(i)
            guard await printPause(0.4) else { return }
        }
    }
}

// MARK: Watch your week fill up.

/// Monday to Sunday drop in and stack with a little squash, Sunday in sunflower,
/// and the brain lands on top. Tap the brain and it hops.
struct StackDaysStep: View {
    let next: () -> Void
    @State private var dropped = 0
    @State private var squash: Int?
    @State private var brainIn = false
    @State private var hop = false
    @State private var bob = false
    @State private var ripples: [FieldRipple] = []
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private static let days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    private static let widths: [CGFloat] = [228, 214, 222, 208, 218, 204, 192]
    private static let tilts: [Double] = [-1, 0.8, -0.6, 1.1, -0.9, 0.5, -1.4]
    private static let shifts: [CGFloat] = [0, 6, -5, 8, -3, 4, -6]

    var body: some View {
        PrintScaffold(step: 6, tag: "How it works", title: "Every session\nfills in\na day.", primaryTitle: "NEXT", primaryAction: next,
                      backdrop: AnyView(HalftoneField(fadeStart: 0.6, ripples: ripples))) {
            VStack(spacing: compactScreen ? 4 : 6) {
                brain
                ForEach((0..<7).reversed(), id: \.self) { i in block(i) }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, compactScreen ? 4 : 18)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Seven days stacked, Monday to Sunday, with the brain on top")
        }
        .sensoryFeedback(.impact(weight: .light), trigger: dropped)
        .sensoryFeedback(.impact(weight: .heavy), trigger: brainIn)
        .task { await run() }
    }

    private var brain: some View {
        Image("BrainExact")
            .resizable()
            .scaledToFit()
            .frame(width: compactScreen ? 70 : 86)
            .rotationEffect(.degrees(brainIn ? -4 : -18))
            // Drops from just above the stack; from higher up it fell through the headline.
            .offset(y: brainIn ? (bob ? -3 : 3) : -90)
            .scaleEffect(hop ? 1.12 : 1)
            .opacity(brainIn ? 1 : 0)
            .onTapGesture(perform: hopOnce)
    }

    private func block(_ i: Int) -> some View {
        let isSun = i == 6
        let isIn = i < dropped
        let fill: Color = isSun ? Ink.sun : (i.isMultiple(of: 2) ? Ink.blue : Color(hex: 0x3A5EAD))
        return HStack {
            Text(Self.days[i])
                .font(PrintFont.mono(13))
                .tracking(1)
            Spacer()
            Image(systemName: isSun ? "star.fill" : "checkmark")
                .font(.system(size: 12, weight: .heavy))
        }
        .foregroundStyle(isSun ? Ink.ink : Ink.receipt)
        .padding(.horizontal, 16)
        .frame(width: Self.widths[i], height: compactScreen ? 34 : 40)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(fill))
        .shadow(color: Ink.ink.opacity(0.16), radius: 7, y: 6)
        .scaleEffect(x: squash == i ? 1.07 : 1, y: squash == i ? 0.88 : 1, anchor: .bottom)
        .rotationEffect(.degrees(Self.tilts[i]))
        .offset(x: Self.shifts[i], y: isIn ? 0 : -330)
        .opacity(isIn ? 1 : 0)
    }

    private func hopOnce() {
        guard brainIn, !effectiveReduceMotion(systemReduceMotion) else { return }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) { hop = true }
        Task {
            guard await printPause(0.15) else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { hop = false }
        }
    }

    private func run() async {
        if effectiveReduceMotion(systemReduceMotion) {
            dropped = Self.days.count
            brainIn = true
            return
        }
        guard await printPause(0.5) else { return }
        for i in 0..<Self.days.count {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) { dropped = i + 1 }
            guard await printPause(0.2) else { return }
            withAnimation(.spring(response: 0.16, dampingFraction: 0.6)) { squash = i }
            ripples.append(FieldRipple(origin: UnitPoint(x: 0.5, y: 0.86 - 0.054 * Double(i)), start: .now, amp: 0.45, speed: 420))
            guard await printPause(0.1) else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { squash = nil }
            guard await printPause(0.04) else { return }
        }
        guard await printPause(0.15) else { return }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) { brainIn = true }
        guard await printPause(0.16) else { return }
        ripples.append(FieldRipple(origin: UnitPoint(x: 0.5, y: 0.45), start: .now, amp: 0.9))
        guard await printPause(0.7) else { return }
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { bob = true }
    }
}
