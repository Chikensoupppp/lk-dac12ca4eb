# Task for Codex: build and finish the Lock In titanium clock

The SwiftUI code below is already in this repo (uncommitted) under `apps/ios/LockIn/`. It was written without a Swift toolchain, so it has never been compiled or rendered.

## Do this
1. Read `AGENTS.md`, `PROJECT_STATUS.md`, `HANDOFF.md`, and run `git status`.
2. On macOS, create or use an Xcode iOS app target (iOS 17+) that includes `apps/ios/LockIn/**`. The source is not yet in an Xcode project.
3. Build. Fix compile errors with minimal changes. Keep the design and the architecture below.
4. Run the `#Preview` and the simulator on iPhone SE and iPhone Pro Max sizes. Check no layout overflow.
5. Tune materials by eye (see "Known visual issues"). Keep it restrained: no neon, no glow halos.
6. Verify behaviour: start, end, run to zero (completion), background and return mid-session, Reduce Motion on, VoiceOver reads "Focus timer, N minutes remaining".
7. Update `PROJECT_STATUS.md` and `HANDOFF.md` honestly (what was compiled and verified). Do not claim anything works until tested.

## Architecture (keep)
- `SessionTiming` (Foundation only): `startedAt` + `duration`; the end timestamp is the single source of truth.
- `FocusView.timing: SessionTiming?` is the only session state (nil = idle). Clock never keeps its own countdown.
- `CountdownClockView` is presentational: renders `timing` via `TimelineView(.animation)`. Static layers (`ClockBody`) are rasterized once with `drawingGroup`; only the arc and digits update per frame.
- Completion: `.task(id: timing)` sleeps until `endsAt`; `scenePhase == .active` re-checks.
- Reduce Motion: arc steps once per second.
- Not yet done (milestone 2): connecting `startSession()` to the Windows companion. It is still a local model.

## Design intent
Premium industrial minimalism: matte black, dark brushed titanium rim, near-black recessed face, thin silver progress arc that recedes clockwise from 12 o'clock, tabular light-weight digits (45:00 default), one prominent LOCK IN button. Light from the upper left. No hourglass, no thick rings, no glow.

## Known visual issues (from a browser approximation, not the real render)
- Black band between rim and face was too wide. Already reduced (face inner shadow stroke `f*0.06`, blur `f*0.035`). Check it.
- Silver arc looked flat. Specular highlight already brightened. Check it.
- Everything in `ClockBody.swift` (rim lightness stops, glints, grain, sheen) is an untested guess.

## Files

### `apps/ios/LockIn/LockInApp.swift`

```swift
import SwiftUI

@main
struct LockInApp: App {
    var body: some Scene {
        WindowGroup { FocusView() }
    }
}
```

### `apps/ios/LockIn/FocusView.swift`

```swift
import SwiftUI

/// Focus screen. `timing` is the single source of truth for the session:
/// nil means idle, non-nil means a session is running until `timing.endsAt`.
/// The clock, labels and completion all derive from it.
struct FocusView: View {
    private static let durationOptions = [15, 25, 45, 60, 90]

    @State private var selectedMinutes = 45
    @State private var timing: SessionTiming?
    @State private var justCompleted = false
    @State private var completionCount = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var isLocked: Bool { timing != nil }

    private var stateAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.7)
    }

    private var clockCaption: String {
        if let timing {
            return "Ends " + timing.endsAt.formatted(date: .omitted, time: .shortened)
        }
        return justCompleted ? "Session complete" : "Ready"
    }

    var body: some View {
        ZStack {
            FocusBackdrop()

            GeometryReader { geo in
                let side = max(min(geo.size.width - 48, geo.size.height * 0.5), 200)

                VStack(spacing: 0) {
                    Text("LOCK IN")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(5)
                        .foregroundStyle(Color.white.opacity(isLocked ? 0.3 : 0.55))
                        .padding(.top, 12)

                    Spacer(minLength: 16)

                    CountdownClockView(
                        duration: TimeInterval(selectedMinutes * 60),
                        timing: timing,
                        caption: clockCaption
                    )
                    .frame(width: side, height: side)

                    Spacer(minLength: 16)

                    VStack(spacing: 10) {
                        Text("MINUTES")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(3)
                            .foregroundStyle(Color.white.opacity(0.3))
                        DurationSelector(options: Self.durationOptions, selection: $selectedMinutes)
                    }
                    .opacity(isLocked ? 0 : 1)
                    .allowsHitTesting(!isLocked)
                    .accessibilityHidden(isLocked)
                    .padding(.bottom, 24)

                    Button(action: isLocked ? endSession : startSession) {
                        Text(isLocked ? "END SESSION" : "LOCK IN")
                    }
                    .buttonStyle(TitaniumButtonStyle(prominent: !isLocked))
                    .accessibilityHint(isLocked ? "Ends the focus session" : "Starts a focus session")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.impact(weight: .medium), trigger: isLocked)
        .sensoryFeedback(.success, trigger: completionCount)
        // Fires when the end timestamp passes. Cancelled automatically when the session
        // changes or the view goes away.
        .task(id: timing) {
            guard let timing else { return }
            while !Task.isCancelled && !timing.isFinished(at: .now) {
                try? await Task.sleep(for: .seconds(max(timing.endsAt.timeIntervalSinceNow, 0.05)))
            }
            guard !Task.isCancelled else { return }
            completeSession()
        }
        // The task above can be suspended in the background; re-check on return.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, let timing, timing.isFinished(at: .now) {
                completeSession()
            }
        }
    }

    // MARK: Session transitions

    private func startSession() {
        let session = SessionTiming(startedAt: .now, duration: TimeInterval(selectedMinutes * 60))
        withAnimation(stateAnimation) {
            justCompleted = false
            timing = session
        }
    }

    private func endSession() {
        withAnimation(stateAnimation) {
            timing = nil
        }
    }

    private func completeSession() {
        guard timing != nil else { return }
        completionCount += 1
        withAnimation(stateAnimation) {
            justCompleted = true
            timing = nil
        }
    }
}

private struct FocusBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.065), Color(white: 0.028)],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [Color.white.opacity(0.05), Color.clear],
                center: UnitPoint(x: 0.3, y: 0),
                startRadius: 0,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

private struct DurationSelector: View {
    let options: [Int]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { minutes in
                let selected = minutes == selection
                Button {
                    selection = minutes
                } label: {
                    Text("\(minutes)")
                        .font(.system(size: 15, weight: selected ? .semibold : .regular).monospacedDigit())
                        .foregroundStyle(selected ? Color.white : Color.white.opacity(0.42))
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(Color.white.opacity(0.09))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                                    )
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(minutes) minutes")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.black.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .animation(.snappy(duration: 0.25), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

#Preview("Idle") { FocusView() }
```

### `apps/ios/LockIn/Clock/SessionTiming.swift`

```swift
import Foundation

/// Immutable timing for one focus session. The end timestamp is the single source of truth,
/// so every reader (clock, labels, completion) derives the same answer from `Date`
/// and nothing accumulates drift across backgrounding or relaunch.
struct SessionTiming: Equatable {
    let startedAt: Date
    let duration: TimeInterval

    var endsAt: Date { startedAt.addingTimeInterval(duration) }

    func remaining(at date: Date) -> TimeInterval {
        min(max(endsAt.timeIntervalSince(date), 0), duration)
    }

    func fractionRemaining(at date: Date) -> Double {
        duration > 0 ? remaining(at: date) / duration : 0
    }

    func isFinished(at date: Date) -> Bool {
        date >= endsAt
    }

    /// "MM:SS". Minutes are not wrapped, so 90 minutes reads "90:00".
    static func display(seconds: Int) -> String {
        let clamped = max(seconds, 0)
        return String(format: "%02d:%02d", clamped / 60, clamped % 60)
    }
}
```

### `apps/ios/LockIn/Clock/ClockBody.swift`

```swift
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
/// machined face, groove and ticks. Rasterized once with `drawingGroup`.
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
```

### `apps/ios/LockIn/Clock/CountdownClockView.swift`

```swift
import SwiftUI

/// Reusable circular countdown clock. Purely presentational: it renders `timing`
/// (the session's end timestamp) and never keeps a countdown of its own.
/// `timing == nil` shows the idle dial at `duration`.
struct CountdownClockView: View {
    let duration: TimeInterval
    let timing: SessionTiming?
    let caption: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let g = ClockGeometry(total: min(proxy.size.width, proxy.size.height))
            ZStack {
                ClockBody(geometry: g)
                    .accessibilityHidden(true)

                // Per-frame updates only touch this layer: the arc and the digits.
                TimelineView(.animation(minimumInterval: reduceMotion ? 0.25 : nil, paused: timing == nil)) { context in
                    readout(at: context.date, geometry: g)
                }
            }
            .frame(width: g.total, height: g.total)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func readout(at now: Date, geometry g: ClockGeometry) -> some View {
        let remaining = timing?.remaining(at: now) ?? duration
        let seconds = Int(remaining.rounded(.up))
        // Reduce Motion: the arc steps once per second instead of sweeping continuously.
        let fraction = reduceMotion ? Double(seconds) / duration : remaining / duration

        ZStack {
            ProgressArc(fraction: fraction, diameter: g.ringDiameter, lineWidth: g.ringWidth)

            Text(SessionTiming.display(seconds: seconds))
                .font(.system(size: g.diameter * 0.19, weight: .light).monospacedDigit())
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white.opacity(0.98), Color(white: 0.78)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color.black.opacity(0.7), radius: 0, x: 0, y: 1)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: g.faceDiameter * 0.66)

            Text(caption.uppercased())
                .font(.system(size: g.diameter * 0.034, weight: .medium))
                .tracking(g.diameter * 0.008)
                .foregroundStyle(Color.white.opacity(0.38))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: g.faceDiameter * 0.6)
                .offset(y: g.diameter * 0.15)
        }
        .frame(width: g.total, height: g.total)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focus timer")
        .accessibilityValue(spokenValue(seconds: seconds))
        .accessibilityAddTraits(.updatesFrequently)
    }

    private func spokenValue(seconds: Int) -> String {
        let spoken = Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
        return timing == nil ? "Ready, \(spoken)" : "\(spoken) remaining"
    }
}

/// Thin polished-silver arc. It starts at 12 o'clock and its leading end retreats
/// clockwise as time runs out. Highlights are fixed to the screen (light from the upper left).
private struct ProgressArc: View {
    let fraction: Double
    let diameter: CGFloat
    let lineWidth: CGFloat

    // Gradient angles are pre-rotation (the arc is rotated -90 degrees), so the
    // upper-left highlight sits at location 0.875.
    private static let silver = AngularGradient(
        stops: ClockTone.metalStops([
            (0.000, 0.50), (0.125, 0.40), (0.375, 0.72), (0.500, 0.52),
            (0.750, 0.38), (0.875, 0.93), (1.000, 0.50)
        ]),
        center: .center
    )

    private static let specular = AngularGradient(
        stops: ClockTone.lightStops([
            (0.000, 0), (0.340, 0), (0.375, 0.45), (0.410, 0),
            (0.820, 0), (0.875, 1.0), (0.930, 0), (1.000, 0)
        ]),
        center: .center
    )

    var body: some View {
        let f = min(max(fraction, 0), 1)
        ZStack {
            if f > 0.0005 {
                Circle()
                    .trim(from: 1 - f, to: 1)
                    .stroke(Self.silver, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                Circle()
                    .trim(from: 1 - f, to: 1)
                    .stroke(Self.specular, style: StrokeStyle(lineWidth: lineWidth * 0.38, lineCap: .round))
            }
        }
        .rotationEffect(.degrees(-90))
        .frame(width: diameter, height: diameter)
        .shadow(color: Color.black.opacity(0.7), radius: lineWidth * 0.6, x: 0, y: lineWidth * 0.5)
    }
}
```

### `apps/ios/LockIn/Clock/TitaniumButtonStyle.swift`

```swift
import SwiftUI

/// Primary button in matte titanium. `prominent == false` is the quiet in-session variant.
struct TitaniumButtonStyle: ButtonStyle {
    var prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        TitaniumButtonBody(configuration: configuration, prominent: prominent)
    }
}

private struct TitaniumButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let prominent: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .tracking(4)
            .foregroundStyle(prominent ? Color(white: 0.07) : Color(white: 0.70))
            .frame(maxWidth: .infinity, minHeight: 60)
            .background { plate(shape) }
            .contentShape(shape)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.35), value: prominent)
    }

    @ViewBuilder
    private func plate(_ shape: RoundedRectangle) -> some View {
        if prominent {
            shape
                .fill(LinearGradient(
                    colors: [ClockTone.metal(0.88), ClockTone.metal(0.68)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .overlay(
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.75), Color.black.opacity(0.35)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                )
                .shadow(color: Color.black.opacity(0.55), radius: 12, x: 0, y: 6)
        } else {
            shape
                .fill(Color.white.opacity(0.04))
                .overlay(shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        }
    }
}
```
