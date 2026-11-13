import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI

// The printed first-run slides. Each one is a different paper object in the same inks.
// Layout follows docs/design/ob-v2.html; every slide scrolls, so small phones keep the buttons.

private let hoursTabs = ["1\u{2013}2 HRS", "3\u{2013}4 HRS", "5\u{2013}6 HRS", "7+ HRS"]

// MARK: 1. Hook

struct HookStep: View {
    let next: () -> Void
    @State private var number = "?H ??M"
    @State private var noteShown = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        PrintScaffold(step: 1, background: Ink.orange, foreground: Ink.paper, title: "Where does\nthe time go?", titleSize: 58, grain: true,
                      primaryTitle: "TAKE A GUESS", primaryAction: next) {
            VStack(alignment: .leading, spacing: 6) {
                Text(number)
                    .font(PrintFont.head(128))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(Ink.paper)
                    .monospacedDigit()
                    .misprint()
                    .accessibilityLabel("Unknown hours a day")
                Text("How many hours do you spend on your phone each day?")
                    .font(PrintFont.mono(14))
                    .foregroundStyle(Ink.paper)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .top) {
                    Spacer()
                    ZStack(alignment: .bottomTrailing) {
                        HookArrow()
                            .trim(from: 0, to: noteShown ? 1 : 0)
                            .stroke(Ink.sun, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                            .frame(width: 110, height: 84)
                        Text("you?")
                            .font(PrintFont.hand(34))
                            .foregroundStyle(Ink.sun)
                            .rotationEffect(.degrees(-6))
                            .offset(x: 36, y: 34)
                            .scaleEffect(noteShown ? 1 : 0.3)
                            .opacity(noteShown ? 1 : 0)
                    }
                    .padding(.trailing, 40)
                }
                .frame(height: 120)
                .accessibilityHidden(true)
            }
        }
        .task {
            if effectiveReduceMotion(systemReduceMotion) { noteShown = true; return }
            guard await printPause(0.3) else { return }
            for _ in 0..<14 {
                number = "\(Int.random(in: 1...9))H \(String(format: "%02d", Int.random(in: 0...59)))M"
                guard await printPause(0.09) else { return }
            }
            number = "?H ??M"
            guard await printPause(0.3) else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { noteShown = true }
        }
    }
}

/// A hand-drawn arrow from the "you?" note up to the number.
private struct HookArrow: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.maxX - 14, y: r.maxY - 4))
        p.addCurve(to: CGPoint(x: r.minX + 14, y: r.minY + 14),
                   control1: CGPoint(x: r.maxX - 30, y: r.minY + 40),
                   control2: CGPoint(x: r.minX + 50, y: r.minY + 20))
        p.move(to: CGPoint(x: r.minX + 30, y: r.minY + 2))
        p.addLine(to: CGPoint(x: r.minX + 12, y: r.minY + 14))
        p.addLine(to: CGPoint(x: r.minX + 28, y: r.minY + 28))
        return p
    }
}

// MARK: 2. Guess

/// A "lost" poster. The user tears off the tab that matches their guess.
struct GuessStep: View {
    @Binding var guessIndex: Int?
    let next: () -> Void

    var body: some View {
        PrintScaffold(step: 2, title: "What\u{2019}s your\nguess?", titleSize: 46, grain: true,
                      primaryTitle: "SEE MY ACTUAL TIME", primaryEnabled: guessIndex != nil, primaryAction: next,
                      secondaryTitle: "Skip", secondaryAction: { guessIndex = nil; next() }) {
            VStack(alignment: .leading, spacing: 18) {
                poster
                if guessIndex != nil {
                    Stamp(text: "Just guess", color: Ink.ink, size: 18, tilt: -4, fill: nil)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.6), value: guessIndex)
        }
    }

    private var poster: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("LOST:\nA FEW HOURS")
                .font(PrintFont.head(76))
                .misprint()
                .lineSpacing(-14)
                .lineLimit(2)
                .minimumScaleFactor(0.55)
                // Room on the right for the torn-off tab, which sits over the poster's corner.
                .padding(.trailing, 64)
                .foregroundStyle(Ink.orange)
                .padding(.horizontal, 18)
                .padding(.top, 18)
            Text("Last seen: \u{201C}Just one more video.\u{201D}")
                .font(PrintFont.mono(14))
                .foregroundStyle(Ink.ink)
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 16)
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { i in
                    tab(i)
                    if i < 3 { DashedLine(vertical: true).frame(width: 2) }
                }
            }
            .frame(height: 150)
            .overlay(alignment: .top) { DashedLine(vertical: false).frame(height: 2) }
        }
        .background(Color.white)
        .shadow(color: .black.opacity(0.25), radius: 12, y: 10)
        .rotationEffect(.degrees(1.2))
        .overlay(alignment: .topTrailing) {
            if let guessIndex {
                looseTab(guessIndex)
                    .offset(x: 6, y: 10)
                    .transition(.asymmetric(insertion: .offset(x: -80, y: 260).combined(with: .opacity), removal: .opacity))
            }
        }
    }

    private func tab(_ i: Int) -> some View {
        let torn = guessIndex == i
        return Button { guessIndex = i } label: {
            ZStack {
                (torn ? Ink.paper : Color.white)
                if !torn {
                    Text(hoursTabs[i])
                        .font(PrintFont.head(28))
                        .foregroundStyle(Ink.ink)
                        .fixedSize()
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: torn)
        .accessibilityLabel(hoursTabs[i].replacingOccurrences(of: "HRS", with: "hours"))
        .accessibilityAddTraits(torn ? .isSelected : [])
    }

    private func looseTab(_ i: Int) -> some View {
        Text(hoursTabs[i])
            .font(PrintFont.head(28))
            .foregroundStyle(Ink.orange)
            .fixedSize()
            .rotationEffect(.degrees(-90))
            .frame(width: 72, height: 128)
            .background(Color.white)
            .overlay(alignment: .top) {
                Rectangle().fill(Ink.orange.opacity(0.65)).frame(width: 64, height: 22)
                    .rotationEffect(.degrees(6)).offset(y: -10)
            }
            .shadow(color: .black.opacity(0.3), radius: 8, y: 8)
            .rotationEffect(.degrees(9))
            .accessibilityHidden(true)
    }
}

/// The dashed cut line between poster tabs.
private struct DashedLine: View {
    let vertical: Bool

    var body: some View {
        GeometryReader { g in
            Path { p in
                p.move(to: .zero)
                p.addLine(to: vertical ? CGPoint(x: 0, y: g.size.height) : CGPoint(x: g.size.width, y: 0))
            }
            .stroke(Ink.ink.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
        }
    }
}

// MARK: 3. Why we ask

struct CheckStep: View {
    @ObservedObject var restrictions: RestrictionController
    let next: () -> Void
    let skip: () -> Void
    @State private var printed: CGFloat = 0
    @State private var rows = 0
    @State private var asking = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    private static let reasons = [
        "See your screen-time report.",
        "Choose your distracting apps.",
        "Block them during focus sessions."
    ]

    /// iOS shows its Screen Time box only once. After that the answer sticks until the app is
    /// deleted, so this slide says what the answer already is instead of silently moving on.
    private enum Access { case ask, on, off }

    private var access: Access {
        switch restrictions.status {
        case .needsAuthorization, .failed: return .ask
        case .denied: return .off
        default: return .on
        }
    }

    private var primaryTitle: String {
        if asking { return "ASKING..." }
        switch access {
        // Apple's guidance: the screen before a system permission box says "Continue", not "Allow".
        // This button opens Apple's Screen Time permission box.
        case .ask: return "ENABLE SCREEN TIME"
        case .on: return "NEXT"
        case .off: return "OPEN SETTINGS"
        }
    }

    var body: some View {
        PrintScaffold(step: 3, title: "Let\u{2019}s\ncheck.", grain: true,
                      primaryTitle: primaryTitle, primaryEnabled: !asking, primaryAction: ask,
                      secondaryTitle: access == .on ? nil : "Not now (keep my guess)", secondaryAction: skip) {
            VStack(alignment: .leading, spacing: 22) {
                Text("See how much time you spend on your phone and choose which apps Lock In can pause.")
                    .font(PrintFont.body(16))
                    .foregroundStyle(Ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
                printer
                if access == .on {
                    Stamp(text: "Screen Time is already on", color: Ink.blue, size: 20, tilt: -3)
                } else if access == .off {
                    Text("Screen Time is off for Lock In. iPhone only asks once, so turn it on in Settings > Screen Time > Apps with Screen Time Access.")
                        .font(PrintFont.body(15))
                        .foregroundStyle(Ink.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(Self.reasons.enumerated()), id: \.offset) { i, text in
                        HStack(spacing: 12) {
                            Text("\(i + 1)")
                                .font(PrintFont.mono(14, .heavy))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Ink.blue))
                            Text(text).font(PrintFont.bold(19)).foregroundStyle(Ink.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .opacity(rows > i ? 1 : 0)
                        .offset(x: rows > i ? 0 : -12)
                    }
                    // Kept from before: the privacy promise.
                    Text("Your screen-time data stays on this iPhone.")
                        .font(PrintFont.mono(12))
                        .foregroundStyle(Ink.ink.opacity(0.65))
                        .opacity(rows >= 3 ? 1 : 0)
                }
            }
        }
        // Coming back from Settings: pick up a changed answer.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { restrictions.refresh() }
        }
        .task {
            if effectiveReduceMotion(systemReduceMotion) { printed = 1; rows = 3; return }
            withAnimation(.easeOut(duration: 1.0)) { printed = 1 }
            guard await printPause(1.0) else { return }
            for i in 1...3 {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { rows = i }
                guard await printPause(0.4) else { return }
            }
        }
    }

    private var printer: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Ink.ink)
                Text("LOCK IN \u{00B7} PRINTER")
                    .font(PrintFont.mono(11)).tracking(2)
                    .foregroundStyle(Ink.paper.opacity(0.7))
                    .padding(.leading, 22).padding(.top, 18)
                Circle().fill(Ink.blue).frame(width: 12, height: 12)
                    .shadow(color: Ink.blue, radius: 6)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 22).padding(.top, 20)
                Capsule().fill(Color.black).frame(height: 12)
                    .padding(.horizontal, 22)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 16)
            }
            .frame(height: 92)
            .zIndex(1)

            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR SCREEN TIME").font(PrintFont.mono(14, .heavy)).tracking(2)
                    .frame(maxWidth: .infinity)
                ReceiptRow(label: "\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}", value: "?h ??m")
                ReceiptRow(label: "\u{2588}\u{2588}\u{2588}\u{2588}", value: "?h ??m")
                ReceiptRow(label: "TOTAL", value: "?h ??m", bold: true)
            }
            .padding(16)
            .padding(.bottom, 10)
            .background(ReceiptEdge().fill(Ink.receipt))
            .padding(.horizontal, 30)
            .offset(y: -10)
            .mask(alignment: .top) {
                Rectangle().frame(height: 200 * printed).frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A blank Screen Time receipt")
    }

    private func ask() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-onboarding") { next(); return }
        #endif
        switch access {
        case .ask:
            asking = true
            Task {
                await restrictions.requestAuthorization()
                asking = false
                next()
            }
        case .on:
            next()
        case .off:
            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        }
    }
}

// MARK: 4. Real hours

/// The real numbers, drawn by Apple's report view inside the LockInReport extension. Lock In
/// cannot read them, so the user taps the band that matches what they see.
struct RevealStep: View {
    let guessIndex: Int?
    @Binding var realIndex: Int?
    let next: () -> Void

    private var filter: DeviceActivityFilter {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Calendar.current.startOfDay(for: end)) ?? end
        return DeviceActivityFilter(segment: .daily(during: DateInterval(start: start, end: end)),
                                    users: .all, devices: .init([.iPhone]))
    }

    var body: some View {
        PrintScaffold(step: 4, grain: true,
                      primaryTitle: "NEXT", primaryEnabled: realIndex != nil, primaryAction: next) {
            VStack(alignment: .leading, spacing: 14) {
                DeviceActivityReport(.reveal(guess: guessIndex), filter: filter)
                    .frame(height: 540)
                    .frame(maxWidth: .infinity)
                Text("Tap the one that matches:")
                    .font(PrintFont.mono(14, .bold))
                    .foregroundStyle(Ink.ink)
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { i in
                        let on = realIndex == i
                        Button { realIndex = i } label: {
                            Text(hoursTabs[i])
                                .font(PrintFont.bold(16))
                                .foregroundStyle(on ? Ink.paper : Ink.ink)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Capsule().fill(on ? Ink.ink : Color.clear))
                                .overlay(Capsule().strokeBorder(Ink.ink, lineWidth: 2.5))
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.selection, trigger: on)
                        .accessibilityLabel(hoursTabs[i].replacingOccurrences(of: "HRS", with: "hours"))
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
        }
        .onAppear { if realIndex == nil { realIndex = guessIndex } }
    }
}

/// Whether this build carries the report extension. Without it the reveal slide is skipped.
enum ScreenTimeReport {
    static var isAvailable: Bool {
        guard let url = Bundle.main.builtInPlugInsURL,
              let items = try? FileManager.default.contentsOfDirectory(atPath: url.path) else { return false }
        return items.contains("LockInReport.appex")
    }
}

// MARK: 6. What pulls you in

/// A sheet of stickers. Tapping one "peels" it: it turns dark and gets a blue check.
struct PullsStep: View {
    @Binding var categories: Set<String>
    let next: () -> Void

    private enum Cut { case circle, pill, rounded, card, star, bubble }
    private static let stickers: [(name: String, cut: Cut, w: CGFloat, h: CGFloat, x: CGFloat, y: CGFloat, tilt: Double)] = [
        ("Video", .circle, 150, 150, 85, 83, -8),
        ("Games", .pill, 150, 96, 257, 52, 6),
        ("Social", .rounded, 140, 140, 262, 196, -5),
        ("Shopping", .card, 170, 88, 91, 232, 4),
        ("News", .star, 136, 136, 85, 372, 0),
        ("Chat", .bubble, 150, 100, 251, 352, -3)
    ]
    private static let canvas = CGSize(width: 345, height: 430)

    var body: some View {
        PrintScaffold(step: 6, title: "What pulls\nyou in?", grain: true,
                      primaryTitle: "NEXT", primaryEnabled: !categories.isEmpty, primaryAction: next,
                      secondaryTitle: "Skip", secondaryAction: next) {
            Text("Which apps tend to keep you longer than you planned?")
                .font(PrintFont.mono(14))
                .foregroundStyle(Ink.ink)
                .fixedSize(horizontal: false, vertical: true)
            GeometryReader { g in
                let scale = min(1, g.size.width / Self.canvas.width)
                ZStack(alignment: .topLeading) {
                    ForEach(Self.stickers, id: \.name) { s in
                        sticker(s.name, cut: s.cut, w: s.w, h: s.h)
                            .rotationEffect(.degrees(s.tilt))
                            .position(x: s.x, y: s.y)
                    }
                }
                .frame(width: Self.canvas.width, height: Self.canvas.height, alignment: .topLeading)
                .scaleEffect(scale, anchor: .topLeading)
            }
            .frame(height: Self.canvas.height * 0.95)
        }
    }

    private func shape(_ cut: Cut) -> AnyShape {
        switch cut {
        case .circle: return AnyShape(Circle())
        case .pill: return AnyShape(Capsule())
        case .rounded: return AnyShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        case .card: return AnyShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .star: return AnyShape(StarShape())
        case .bubble: return AnyShape(UnevenRoundedRectangle(topLeadingRadius: 50, bottomLeadingRadius: 8,
                                                             bottomTrailingRadius: 50, topTrailingRadius: 50))
        }
    }

    private func sticker(_ name: String, cut: Cut, w: CGFloat, h: CGFloat) -> some View {
        let on = categories.contains(name)
        let outline = shape(cut)
        return Button {
            if on { categories.remove(name) } else { categories.insert(name) }
        } label: {
            Text(name.uppercased())
                .font(PrintFont.head(26))
                .foregroundStyle(Ink.paper)
                .frame(width: w, height: h)
                .background(outline.fill(on ? Ink.ink : Ink.orange))
                .overlay(outline.stroke(Color.white, lineWidth: 6))
                .shadow(color: .black.opacity(0.3), radius: 8, y: 8)
                .overlay(alignment: .topTrailing) {
                    if on {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Ink.blue))
                            .overlay(Circle().stroke(Color.white, lineWidth: 3))
                            .offset(x: 6, y: -8)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .scaleEffect(on ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: on)
        .sensoryFeedback(.selection, trigger: on)
        .accessibilityLabel(name)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

private struct StarShape: Shape {
    func path(in r: CGRect) -> Path {
        let pts: [(CGFloat, CGFloat)] = [(0.5, 0), (0.61, 0.35), (0.98, 0.35), (0.68, 0.57), (0.79, 0.91),
                                         (0.5, 0.70), (0.21, 0.91), (0.32, 0.57), (0.02, 0.35), (0.39, 0.35)]
        var p = Path()
        for (i, pt) in pts.enumerated() {
            let point = CGPoint(x: r.minX + pt.0 * r.width, y: r.minY + pt.1 * r.height)
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath()
        return p
    }
}

// MARK: 7. Lock the apps

/// Screen Time's own app picker. If access was skipped earlier, this asks again ("Continue").
struct LockAppsStep: View {
    @ObservedObject var restrictions: RestrictionController
    let next: () -> Void
    @State private var picking = false
    @Environment(\.openURL) private var openURL

    private var lockedCount: Int {
        restrictions.selection.applicationTokens.count + restrictions.selection.categoryTokens.count
    }

    var body: some View {
        let has = restrictions.hasSelection
        PrintScaffold(step: 7, title: has ? "Locked." : "Pick what\nto pause.", grain: true,
                      primaryTitle: primaryTitle(has), primaryAction: { primary(has) },
                      secondaryTitle: has ? "Change apps" : "Skip for now",
                      secondaryAction: { has ? (picking = true) : next() }) {
            VStack(alignment: .leading, spacing: 18) {
                Text(has ? "They\u{2019}re blocked while your timer runs." : "Choose the apps you want to block while you\u{2019}re focusing.")
                    .font(PrintFont.mono(14))
                    .foregroundStyle(Ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("You can change your selection anytime.")
                    .font(PrintFont.mono(12))
                    .foregroundStyle(Ink.ink.opacity(0.65))
                tiles(has)
                if has {
                    Stamp(text: "\(lockedCount) locked", color: Ink.blue, size: 22, tilt: -5)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .familyActivityPicker(
            isPresented: $picking,
            selection: Binding(get: { restrictions.selection }, set: { restrictions.setSelection($0) })
        )
    }

    private func primaryTitle(_ has: Bool) -> String {
        if has { return "LOOKS RIGHT" }
        switch restrictions.status {
        case .denied: return "OPEN SETTINGS"
        case .needsAuthorization, .failed: return "CONTINUE"
        default: return "CHOOSE APPS"
        }
    }

    private func primary(_ has: Bool) {
        if has { next(); return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-onboarding") { next(); return }
        #endif
        switch restrictions.status {
        case .denied:
            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        case .needsAuthorization, .failed:
            Task { await restrictions.requestAuthorization() }
        default:
            picking = true
        }
    }

    @ViewBuilder
    /// Picked apps as their own icons, no box and no shadow, at about 30 pt: the biggest size
    /// that stays sharp (Screen Time only gives a tiny icon, so going bigger blurs it). A small
    /// lock sits on each corner. Before anything is picked, a grid of empty dashed slots.
    @ViewBuilder
    private func tiles(_ has: Bool) -> some View {
        let apps = Array(restrictions.selection.applicationTokens)
        let cats = Array(restrictions.selection.categoryTokens)
        if has {
            let columns = [GridItem(.adaptive(minimum: 44, maximum: 56), spacing: 18)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                ForEach(Array(apps.prefix(15).enumerated()), id: \.offset) { _, token in
                    lockedIcon { Label(token).labelStyle(.iconOnly) }
                }
                if apps.count < 15 {
                    ForEach(Array(cats.prefix(15 - apps.count).enumerated()), id: \.offset) { _, token in
                        lockedIcon { Label(token).labelStyle(.iconOnly) }
                    }
                }
                if lockedCount > 15 {
                    Text("+\(lockedCount - 15)")
                        .font(PrintFont.bold(16))
                        .foregroundStyle(Ink.paper)
                        .frame(width: 30, height: 30)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Ink.ink))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(lockedCount) apps chosen")
        } else {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(0..<12, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Ink.ink.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(Image(systemName: "plus").foregroundStyle(Ink.ink.opacity(0.5)))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("No apps chosen yet")
        }
    }

    private func lockedIcon<Icon: View>(@ViewBuilder icon: () -> Icon) -> some View {
        icon()
            .scaleEffect(2.8)
            .frame(width: 30, height: 30)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 15, height: 15)
                    .background(Circle().fill(Ink.ink))
                    .overlay(Circle().stroke(Ink.paper, lineWidth: 1.5))
                    .offset(x: 5, y: 5)
            }
            .frame(width: 44, height: 44)
    }
}

// MARK: 8. Your year

/// Bad news, then good news: a year of days, the phone's share crossed out in orange, then half of
/// it turned blue. Plain arithmetic from the hours answer, labeled as an estimate.
struct YearStep: View {
    let hoursIndex: Int
    let next: () -> Void
    @State private var shown = 0
    @State private var reveal = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var days: Int { OnboardingMath.daysPerYear(hoursIndex: hoursIndex) }
    /// Full days a 25-minute daily session adds up to in a 365-day year (6 at 25 minutes).
    private var focusDays: Int { OnboardingMath.focusDaysPerYear(minutesPerDay: 25) }

    var body: some View {
        PrintScaffold(step: 8, title: "Your next\nyear.", grain: true,
                      primaryTitle: "LET\u{2019}S DO IT", primaryAction: next) {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(shown) DAYS")
                    .font(PrintFont.head(92))
                    .misprint()
                    .foregroundStyle(Ink.orange)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityLabel("\(days) days")
                Text("That\u{2019}s how much time your current daily average would add up to over a year.")
                    .font(PrintFont.mono(15))
                    .foregroundStyle(Ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Canvas { ctx, size in
                    let cols = 26, rows = 14, gap: CGFloat = 2
                    let cell = (size.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
                    for i in 0..<(cols * rows) {
                        let rect = CGRect(x: CGFloat(i % cols) * (cell + gap), y: CGFloat(i / cols) * (cell + gap),
                                          width: cell, height: cell)
                        let color: Color = reveal && i < focusDays ? Ink.sun : (i < shown ? Ink.orange : Ink.ink.opacity(0.1))
                        ctx.fill(Path(rect), with: .color(color))
                    }
                }
                .aspectRatio(26.0 / 14.0, contentMode: .fit)
                .padding(14)
                .background(Color.white)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 8)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text("But here\u{2019}s another number.")
                        .font(PrintFont.mono(15))
                        .foregroundStyle(Ink.ink)
                    HStack(spacing: 14) {
                        Text("+\(focusDays)")
                            .font(PrintFont.head(40))
                            .foregroundStyle(Ink.ink)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(Ellipse().fill(Ink.sun))
                            .rotationEffect(.degrees(-4))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("25 MINUTES A DAY.")
                                .font(PrintFont.head(30))
                                .foregroundStyle(Ink.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text("That\u{2019}s more than \(OnboardingMath.spelled(focusDays)) full days of focused time over a year.")
                                .font(PrintFont.bold(17))
                                .foregroundStyle(Ink.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 10)
                .opacity(reveal ? 1 : 0)
                .accessibilityElement(children: .combine)
                Text("An estimate from your answer, in full 24-hour days.")
                    .font(PrintFont.mono(11, .regular))
                    .foregroundStyle(Ink.soft)
            }
        }
        .task {
            if effectiveReduceMotion(systemReduceMotion) { shown = days; reveal = true; return }
            for k in 1...30 {
                let t = Double(k) / 30
                shown = Int(Double(days) * (1 - pow(1 - t, 3)))
                guard await printPause(0.04) else { return }
            }
            shown = days
            guard await printPause(0.7) else { return }
            withAnimation(.easeOut(duration: 0.5)) { reveal = true }
        }
    }
}

// MARK: 9. Goals

/// A to-do list on notebook paper, in handwriting.
struct GoalsStep: View {
    @Binding var goals: Set<String>
    let next: () -> Void

    private static let items: [(key: String, text: String)] = [
        ("Study", "Studying"), ("Train", "Working out"), ("Create", "Creating something"),
        ("Sleep", "Getting more rest"), ("Read", "Reading"), ("People", "Spending time with people")
    ]

    var body: some View {
        PrintScaffold(step: 9, background: Ink.notebook, title: "What\u{2019}s worth\nyour time?",
                      primaryTitle: "NEXT", primaryEnabled: !goals.isEmpty, primaryAction: next,
                      secondaryTitle: "Skip", secondaryAction: next) {
            Text("What would you like to make more room for?")
                .font(PrintFont.mono(14))
                .foregroundStyle(Ink.ink)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Self.items, id: \.key) { item in
                    let on = goals.contains(item.key)
                    Button {
                        if on { goals.remove(item.key) } else { goals.insert(item.key) }
                    } label: {
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Ink.ink, lineWidth: 3)
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if on {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 26, weight: .black))
                                            .foregroundStyle(Ink.blue)
                                            .offset(x: 3, y: -6)
                                            .transition(.scale(scale: 0.3).combined(with: .opacity))
                                    }
                                }
                            Text(item.text)
                                .font(PrintFont.hand(30))
                                .foregroundStyle(Ink.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Spacer(minLength: 0)
                        }
                        .padding(.leading, 34)
                        .frame(height: 49)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.3, dampingFraction: 0.55), value: on)
                    .sensoryFeedback(.selection, trigger: on)
                    .accessibilityLabel(item.text)
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .background(alignment: .bottom) {
                        Rectangle().fill(Ink.blue.opacity(0.2)).frame(height: 2)
                    }
                }
            }
            .background(alignment: .leading) {
                Rectangle().fill(Ink.orange.opacity(0.4)).frame(width: 2).padding(.leading, 18)
            }
        }
    }
}

// MARK: 10. Making your plan

/// A dot-matrix print-out of the user's own answers. Moves on by itself.
struct PlanStep: View {
    let hoursIndex: Int?
    let categories: Set<String>
    let goals: Set<String>
    let next: () -> Void
    @State private var lines = 0
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var printout: [String] {
        var out = ["PLAN FOR: YOU", String(repeating: "-", count: 22)]
        if let hoursIndex { out.append("\u{2713} \(hoursTabs[min(max(hoursIndex, 0), 3)]) A DAY") }
        if !categories.isEmpty { out.append("\u{2713} " + categories.sorted().prefix(2).joined(separator: " + ").uppercased()) }
        if !goals.isEmpty { out.append("\u{2713} GOAL: " + goals.sorted().prefix(2).joined(separator: ", ").uppercased()) }
        out.append("\u{258C} DAILY LOCK: 25 MIN")
        return out
    }

    var body: some View {
        PrintScaffold(step: 10, title: "Your first\nsession.", grain: true) {
            VStack(spacing: 0) {
                Capsule().fill(Color.black).frame(height: 14)
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    .padding(.horizontal, 16)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(printout.enumerated()), id: \.offset) { i, line in
                        Text(line)
                            .font(PrintFont.mono(14))
                            .foregroundStyle(Ink.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .opacity(i < lines ? 1 : 0)
                    }
                    Text("\u{00B7} \u{00B7} \u{00B7}").font(PrintFont.mono(14)).foregroundStyle(Ink.ink.opacity(0.35))
                }
                .padding(18)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ReceiptEdge().fill(Color.white).shadow(color: .black.opacity(0.18), radius: 10, y: 8))
                .padding(.horizontal, 36)
                .offset(y: -6)
            }
            .padding(.top, 20)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Making your plan")
            VStack(alignment: .leading, spacing: 6) {
                Text("25 MINUTES. ONE THING.")
                    .font(PrintFont.head(34))
                    .foregroundStyle(Ink.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("A small start is still a start.")
                    .font(PrintFont.body(16))
                    .foregroundStyle(Ink.ink.opacity(0.75))
            }
            .padding(.top, 12)
            .opacity(lines >= printout.count ? 1 : 0)
            .animation(.easeOut(duration: 0.4), value: lines)
        }
        .task {
            let reduce = effectiveReduceMotion(systemReduceMotion)
            if reduce { lines = printout.count } else {
                for i in 1...printout.count {
                    guard await printPause(0.45) else { return }
                    lines = i
                }
            }
            guard await printPause(reduce ? 1.5 : 1.3) else { return }
            next()
        }
    }
}

// MARK: 11. Promise

/// A contract. Hold the button for 2 seconds to sign it. VoiceOver gets a plain "Sign" action.
struct PromiseStep: View {
    @Binding var signed: Bool
    /// The goals picked on slide 9; the first one names what the 25 minutes are for.
    var goals: Set<String> = []
    let next: () -> Void
    @State private var ink: CGFloat = 0
    @State private var holding = false
    @State private var done = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private static let holdSeconds = 2.0

    /// In slide 9's order, so the choice does not depend on set order.
    private static let activities: [(key: String, phrase: String)] = [
        ("Study", "my studies"), ("Train", "my workout"), ("Create", "my project"),
        ("Sleep", "my rest"), ("Read", "my reading"), ("People", "the people around me")
    ]

    private var activity: String {
        Self.activities.first { goals.contains($0.key) }?.phrase ?? "one thing"
    }

    var body: some View {
        PrintScaffold(step: 11, title: "One small\ncommitment.", grain: true,
                      primaryView: AnyView(holdButton),
                      secondaryTitle: "Not now", secondaryAction: { signed = false; next() }) {
            VStack(alignment: .leading, spacing: 12) {
                Text("AGREEMENT").font(PrintFont.mono(12)).tracking(2).foregroundStyle(Ink.ink.opacity(0.6))
                (Text("I\u{2019}ll give \(activity) my attention for ")
                 + Text("25 minutes").bold().foregroundColor(Ink.ink)
                 + Text("."))
                    .font(PrintFont.bold(24))
                    .foregroundStyle(Ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("If I get distracted, I\u{2019}ll come back to it.")
                    .font(PrintFont.bold(20))
                    .foregroundStyle(Ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("No need to be perfect.")
                    .font(PrintFont.mono(12))
                    .foregroundStyle(Ink.ink.opacity(0.6))
                ZStack(alignment: .bottomLeading) {
                    Signature()
                        .trim(from: 0, to: ink)
                        .stroke(Ink.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        .frame(width: 190, height: 56)
                        .padding(.leading, 6).padding(.bottom, 6)
                    Rectangle().fill(Ink.ink).frame(height: 3)
                }
                .frame(height: 76)
                .padding(.top, 20)
                .accessibilityHidden(true)
                Text("SIGNED, " + Date().formatted(.dateTime.day().month(.abbreviated)).uppercased())
                    .font(PrintFont.mono(12))
                    .foregroundStyle(Ink.ink.opacity(0.6))
            }
            .padding(22)
            .background(Color.white)
            .shadow(color: .black.opacity(0.2), radius: 12, y: 10)
        }
    }

    private var holdButton: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Ink.ink)
            GeometryReader { g in
                Rectangle().fill(Ink.orange).frame(width: g.size.width * ink)
            }
            Text(done ? "INTENTION SET" : holding ? "KEEP HOLDING" : "HOLD TO SET MY INTENTION")
                .font(PrintFont.bold(19)).tracking(2)
                .foregroundStyle(Ink.paper)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 60)
        .clipShape(Capsule())
        .contentShape(Capsule())
        .onLongPressGesture(minimumDuration: Self.holdSeconds, maximumDistance: 60) {
            commit()
        } onPressingChanged: { pressing in
            guard !done else { return }
            holding = pressing
            if pressing { withAnimation(.linear(duration: Self.holdSeconds)) { ink = 1 } }
            else { withAnimation(.easeOut(duration: 0.3)) { ink = 0 } }
        }
        .sensoryFeedback(.success, trigger: done)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hold to set your intention")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Sign") { commit() }
        .accessibilityIdentifier("hold-to-sign")
    }

    private func commit() {
        guard !done else { return }
        done = true
        holding = false
        ink = 1
        signed = true
        Task {
            _ = await printPause(effectiveReduceMotion(systemReduceMotion) ? 0.2 : 0.8)
            next()
        }
    }
}

/// A loose hand-written scribble, drawn as the user holds.
private struct Signature: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.move(to: CGPoint(x: 0, y: h * 0.7))
        p.addCurve(to: CGPoint(x: w * 0.18, y: h * 0.1), control1: CGPoint(x: w * 0.05, y: h * 0.2), control2: CGPoint(x: w * 0.12, y: 0))
        p.addCurve(to: CGPoint(x: w * 0.22, y: h * 0.85), control1: CGPoint(x: w * 0.26, y: h * 0.3), control2: CGPoint(x: w * 0.1, y: h * 0.9))
        p.addCurve(to: CGPoint(x: w * 0.45, y: h * 0.45), control1: CGPoint(x: w * 0.32, y: h * 0.8), control2: CGPoint(x: w * 0.36, y: h * 0.4))
        p.addCurve(to: CGPoint(x: w * 0.55, y: h * 0.75), control1: CGPoint(x: w * 0.52, y: h * 0.5), control2: CGPoint(x: w * 0.48, y: h * 0.85))
        p.addCurve(to: CGPoint(x: w * 0.72, y: h * 0.35), control1: CGPoint(x: w * 0.62, y: h * 0.65), control2: CGPoint(x: w * 0.64, y: h * 0.3))
        p.addCurve(to: CGPoint(x: w, y: h * 0.55), control1: CGPoint(x: w * 0.8, y: h * 0.4), control2: CGPoint(x: w * 0.9, y: h * 0.7))
        return p
    }
}
