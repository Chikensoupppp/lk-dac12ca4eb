import FamilyControls
import ManagedSettings
import ManagedSettingsUI
import SwiftUI

/// First-run flow. Nine steps. Screen Time access and the app list are set on the real screens
/// here. PC pairing is not part of it: it comes after Plus is bought, from the PC sheet.
/// Nothing in this flow claims a feature that is not built: Plus is shown as "coming soon".
struct OnboardingFlow: View {
    static let stepCount = 9

    @ObservedObject var restrictions: RestrictionController
    /// `true` means the user asked to start a first session right away.
    let onFinish: (Bool) -> Void

    @State private var step = 1
    @State private var hoursIndex: Int?
    @State private var categories: Set<String> = []
    @State private var goals: Set<String> = []
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var reduceMotion: Bool { effectiveReduceMotion(systemReduceMotion) }

    @State private var goingBack = false

    /// The "Look at your year" step. It needs the hours answer, so it is left out when that
    /// question was skipped, rather than showing a number the user never earned.
    private static let yearStep = 7

    private func go(to target: Int, back: Bool) {
        goingBack = back
        let move = { step = min(max(target, 1), Self.stepCount) }
        if reduceMotion { withAnimation(.easeInOut(duration: 0.2), move) }
        else { withAnimation(.spring(response: 0.5, dampingFraction: 0.86), move) }
    }

    /// "Working it out" sits between Goals (6) and Year (7). It is not a numbered step: it
    /// keeps "6 of 9". It only shows when the hours answer exists, like the Year step.
    @State private var working = false

    private func next() {
        if step == Self.yearStep - 1 && hoursIndex != nil && !working {
            goingBack = false
            let move = { working = true }
            if reduceMotion { withAnimation(.easeInOut(duration: 0.2), move) }
            else { withAnimation(.spring(response: 0.5, dampingFraction: 0.86), move) }
            return
        }
        var target = step + 1
        if target == Self.yearStep && hoursIndex == nil { target += 1 }
        goingBack = false
        let move = { working = false; step = min(max(target, 1), Self.stepCount) }
        if reduceMotion { withAnimation(.easeInOut(duration: 0.2), move) }
        else { withAnimation(.spring(response: 0.5, dampingFraction: 0.86), move) }
    }

    private func back() {
        if working {
            goingBack = true
            let move = { working = false }
            if reduceMotion { withAnimation(.easeInOut(duration: 0.2), move) }
            else { withAnimation(.spring(response: 0.5, dampingFraction: 0.86), move) }
            return
        }
        var target = step - 1
        if target == Self.yearStep && hoursIndex == nil { target -= 1 }
        go(to: target, back: true)
    }

    private func finish(start: Bool) {
        OnboardingStore.save(hoursIndex: hoursIndex, categories: categories, goals: goals)
        onFinish(start)
    }

    var body: some View {
        ZStack {
            Matte.bgMid.ignoresSafeArea()
            Group {
                if working {
                    WorkingStep(done: next)
                } else {
                switch step {
                case 1: HeroStep(next: next)
                case 2: HoursStep(hoursIndex: $hoursIndex, next: next)
                case 3: CategoriesStep(categories: $categories, next: next)
                case 4: PermissionStep(restrictions: restrictions, next: next)
                case 5: ShieldStep(restrictions: restrictions, next: next)
                case 6: GoalsStep(goals: $goals, next: next)
                case 7: YearStep(hoursIndex: hoursIndex ?? 2, next: next)
                case 8: PlusStep(next: next)
                default: ReadyStep(start: { finish(start: true) }, later: { finish(start: false) })
                }
                }
            }
            .environment(\.obBack, step > 1 ? back : nil)
            .id(working ? 0 : step)
            .transition(reduceMotion
                ? .opacity
                : .asymmetric(
                    insertion: .move(edge: goingBack ? .leading : .trailing).combined(with: .opacity),
                    removal: .move(edge: goingBack ? .trailing : .leading).combined(with: .opacity)))
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: 1. Hero

private struct HeroStep: View {
    let next: () -> Void
    @State private var angle: Double = 0
    @State private var float = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduce: Bool { effectiveReduceMotion(systemReduceMotion) }

    var body: some View {
        OBScaffold(step: 1, title: "You lose hours\nto your phone.", subtitle: "Let\u{2019}s get them back.",
                   subtitleLarge: true, primaryTitle: "SHOW ME", primaryAction: next) {
            ZStack {
                Circle().fill(Matte.faceMid)
                    .overlay(Circle().strokeBorder(Matte.edge, lineWidth: 10))
                    .frame(width: 240, height: 240)
                Capsule().fill(Matte.text).frame(width: 10, height: 66).offset(y: -33)
                Capsule().fill(OB.ice).frame(width: 8, height: 86).offset(y: -43)
                    .rotationEffect(.degrees(angle))
                Circle().fill(Matte.text).frame(width: 20, height: 20)

                SymbolTile(symbol: "camera", color: Color(hex: 0xE4573D), tilt: -12)
                    .offset(x: -130, y: 90 + (float ? -10 : 0))
                SymbolTile(symbol: "play.fill", color: Color(hex: 0xD93636), tilt: 10)
                    .offset(x: 118, y: -105 + (float ? 8 : 0))
                SymbolTile(symbol: "xmark", color: Color(hex: 0x17181B), size: 60, tilt: -8)
                    .offset(x: 112, y: 112 + (float ? -8 : 0))
                StickerNote(text: "just one look", color: OB.ice, tilt: 6)
                    .offset(x: 62, y: -150)
            }
            .frame(maxWidth: .infinity, minHeight: 330)
            .accessibilityHidden(true)
        }
        .onAppear {
            guard !reduce else { angle = 90; return }
            withAnimation(.easeInOut(duration: 3.2)) { angle = 1080 + 90 }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { float = true }
        }
    }
}

// MARK: 2. Hours

private struct HoursStep: View {
    @Binding var hoursIndex: Int?
    let next: () -> Void

    var body: some View {
        OBScaffold(step: 2, title: "How long are you on your phone each day?",
                   primaryTitle: "NEXT", primaryEnabled: hoursIndex != nil, primaryAction: next,
                   secondaryTitle: "Skip", secondaryAction: next) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(OnboardingMath.hoursChoices.enumerated()), id: \.offset) { index, label in
                    ChoiceRow(title: label, selected: hoursIndex == index) { hoursIndex = index }
                }
                if let hoursIndex {
                    StickerNote(text: Self.reactions[min(hoursIndex, Self.reactions.count - 1)], color: OB.sage, tilt: -2)
                        .padding(.top, 8)
                        .id(hoursIndex)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: hoursIndex)
        }
    }

    /// One line per answer. It reacts to the answer and makes no promise about the app.
    private static let reactions = [
        "Not bad. Let\u{2019}s keep it that way.",
        "That adds up. Let\u{2019}s trim it.",
        "That is a lot. Let\u{2019}s fix it.",
        "That is a big part of your day. Let\u{2019}s fix it."
    ]
}

// MARK: 3. Categories

private struct CategoriesStep: View {
    @Binding var categories: Set<String>
    let next: () -> Void

    private static let items: [(String, String, UInt32)] = [
        ("Social", "camera", 0xE4573D), ("Video", "play.fill", 0xD93636),
        ("Games", "gamecontroller.fill", 0x8A3FA0), ("News", "newspaper.fill", 0x4B5563),
        ("Shopping", "bag.fill", 0xC46A2B), ("Chat", "bubble.left.fill", 0x3E7BD6)
    ]

    var body: some View {
        OBScaffold(step: 3, title: "Which apps pull you in the most?",
                   primaryTitle: "NEXT", primaryEnabled: !categories.isEmpty, primaryAction: next,
                   secondaryTitle: "Skip", secondaryAction: next) {
            VStack(alignment: .leading, spacing: 20) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 14) {
                    ForEach(Self.items, id: \.0) { item in
                        ChoiceTile(title: item.0, symbol: item.1, color: Color(hex: item.2), selected: categories.contains(item.0)) {
                            if categories.contains(item.0) { categories.remove(item.0) } else { categories.insert(item.0) }
                        }
                    }
                }
                Text("Got it. Next, we lock them.")
                    .font(Cream.rounded(18, .semibold))
                    .foregroundStyle(Matte.text)
            }
        }
    }
}

// MARK: 4. Permission

private struct PermissionStep: View {
    @ObservedObject var restrictions: RestrictionController
    let next: () -> Void
    @State private var asking = false

    var body: some View {
        OBScaffold(step: 4, title: "Now we lock them.", subtitle: "Your iPhone asks first. Tap Continue.",
                   primaryTitle: asking ? "ASKING..." : "CONTINUE", primaryEnabled: !asking, primaryAction: ask) {
            VStack(spacing: 12) {
                reassurance(symbol: "lock.fill", color: OB.sage, text: "You stay in control. You can end a session any time.")
                reassurance(symbol: "checkmark.shield.fill", color: OB.ice, text: "We never see which apps you pick.")
            }
        }
    }

    private func reassurance(symbol: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color)
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: symbol).font(.system(size: 20, weight: .semibold)).foregroundStyle(OB.ink))
            Text(text).font(Cream.rounded(18, .semibold)).foregroundStyle(Matte.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(OB.panel))
    }

    private func ask() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-onboarding") { next(); return }
        #endif
        asking = true
        Task {
            await restrictions.requestAuthorization()
            asking = false
            next()
        }
    }
}

// MARK: 5. Shield

private struct ShieldStep: View {
    @ObservedObject var restrictions: RestrictionController
    let next: () -> Void
    @State private var picking = false
    @Environment(\.openURL) private var openURL

    private var authorized: Bool {
        switch restrictions.status {
        case .needsAuthorization, .denied, .failed: return false
        default: return true
        }
    }

    private var lockedCount: Int {
        restrictions.selection.applicationTokens.count + restrictions.selection.categoryTokens.count
    }

    var body: some View {
        let has = restrictions.hasSelection
        OBScaffold(
            step: 5,
            title: has ? "These apps are locked." : "Choose the apps to lock.",
            subtitle: has ? "They lock when your timer runs." : "Pick them once. You can change them later.",
            primaryTitle: primaryTitle(has),
            primaryAction: { primary(has) },
            secondaryTitle: has ? "Change apps" : "Skip for now",
            secondaryAction: { has ? (picking = true) : next() }
        ) {
            VStack(alignment: .leading, spacing: 18) {
                if !authorized {
                    Text("Screen Time access is off, so apps cannot be locked yet.")
                        .font(Cream.rounded(16, .medium))
                        .foregroundStyle(Matte.textQuiet)
                }
                tiles(has)
                if has {
                    Text("\(lockedCount) \(lockedCount == 1 ? "app" : "apps") locked")
                        .font(Cream.rounded(20, .heavy))
                        .foregroundStyle(OB.ink)
                        .padding(.horizontal, 22).padding(.vertical, 11)
                        .background(Capsule().fill(Matte.text))
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
        // Apple's guidance: a screen before a system permission box uses "Continue", never "Allow".
        case .needsAuthorization, .failed: return "CONTINUE"
        default: return "CHOOSE APPS"
        }
    }

    private func primary(_ has: Bool) {
        if has { next(); return }
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
    private func tiles(_ has: Bool) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)
        let apps = Array(restrictions.selection.applicationTokens)
        let cats = Array(restrictions.selection.categoryTokens)
        LazyVGrid(columns: columns, spacing: 18) {
            if has {
                ForEach(Array(apps.prefix(11).enumerated()), id: \.offset) { index, token in
                    LockedTile(index: index) { Label(token).labelStyle(.iconOnly) }
                }
                if apps.count < 11 {
                    ForEach(Array(cats.prefix(11 - apps.count).enumerated()), id: \.offset) { index, token in
                        LockedTile(index: apps.count + index) { Label(token).labelStyle(.iconOnly) }
                    }
                }
                if lockedCount > 11 {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(OB.panel)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(Text("+\(lockedCount - 11)").font(Cream.rounded(20, .heavy)).foregroundStyle(OB.ice))
                }
            } else {
                ForEach(0..<12, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Matte.tickMajor, style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(Image(systemName: "plus").foregroundStyle(Matte.textDim))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(has ? "\(lockedCount) apps chosen" : "No apps chosen yet")
    }
}

/// A chosen app, drawn by iOS (we cannot read its name), dimmed with a lock that snaps on.
private struct LockedTile<Icon: View>: View {
    let index: Int
    let icon: () -> Icon
    @State private var locked = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    init(index: Int, @ViewBuilder icon: @escaping () -> Icon) {
        self.index = index
        self.icon = icon
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(Matte.faceTop)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                icon().scaleEffect(2.4).clipped()
            }
            .overlay {
                ZStack {
                    Color.black.opacity(locked ? 0.62 : 0)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(locked ? 1 : 3.2)
                        .opacity(locked ? 1 : 0)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .onAppear {
                if effectiveReduceMotion(systemReduceMotion) { locked = true; return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.55).delay(0.25 + Double(index) * 0.12)) { locked = true }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: locked)
    }
}

// MARK: 6. Goals

private struct GoalsStep: View {
    @Binding var goals: Set<String>
    let next: () -> Void

    private static let items: [(String, String)] = [
        ("Study", "book.fill"), ("Work", "briefcase.fill"), ("Sleep", "moon.fill"),
        ("Training", "bolt.fill"), ("Create", "pencil"), ("Read", "text.book.closed.fill")
    ]

    var body: some View {
        OBScaffold(step: 6, title: "What do you want to focus on?",
                   primaryTitle: "NEXT", primaryEnabled: !goals.isEmpty, primaryAction: next,
                   secondaryTitle: "Skip", secondaryAction: next) {
            VStack(alignment: .leading, spacing: 18) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    ForEach(Self.items, id: \.0) { item in
                        ChoiceTile(title: item.0, symbol: item.1, color: OB.ice, selected: goals.contains(item.0), darkTextWhenSelected: true) {
                            if goals.contains(item.0) { goals.remove(item.0) } else { goals.insert(item.0) }
                        }
                    }
                }
                StickerNote(text: goals.isEmpty ? "pick as many as you like" : "Good. Let\u{2019}s protect that time.", color: OB.sage, tilt: -3)
                    .id(goals.isEmpty)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: goals.isEmpty)
            }
        }
    }
}

// MARK: Working it out (between 6 and 7, no number of its own)

/// A short pause before the year. The bar fills over 4 seconds. Three checks land one by one.
/// It moves on by itself after a short rest. The sums are instant; this pause is only pacing.
/// Back stays available, so it is not a trap.
private struct WorkingStep: View {
    let done: () -> Void
    @State private var progress: CGFloat = 0
    @State private var checks = 0
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private static let rows = ["Your hours a day", "Your apps", "Your year"]

    var body: some View {
        OBScaffold(step: 6, title: "Working it out.") {
            VStack(alignment: .leading, spacing: 14) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(hex: 0x23262B))
                        Capsule().fill(OB.ice).frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 14)
                .padding(.bottom, 14)
                .accessibilityHidden(true)

                ForEach(Array(Self.rows.enumerated()), id: \.offset) { index, label in
                    HStack(spacing: 14) {
                        ZStack {
                            if checks > index {
                                Circle().fill(OB.sage).frame(width: 26, height: 26)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .heavy))
                                    .foregroundStyle(OB.ink)
                            } else if checks == index {
                                ProgressView().tint(OB.ice)
                            } else {
                                Circle().strokeBorder(Matte.edge, lineWidth: 3).frame(width: 26, height: 26)
                            }
                        }
                        .frame(width: 26, height: 26)
                        Text(label)
                            .font(Cream.rounded(20, .bold))
                            .foregroundStyle(checks > index ? Matte.text : OB.soft)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 18)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(OB.panel))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(checks > index ? "\(label), done" : label)
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: checks)
        .task {
            if effectiveReduceMotion(systemReduceMotion) {
                progress = 1
                checks = Self.rows.count
                try? await Task.sleep(for: .milliseconds(900))
                if !Task.isCancelled { done() }
                return
            }
            withAnimation(.linear(duration: 4.0)) { progress = 1 }
            for i in 1...Self.rows.count {
                try? await Task.sleep(for: .milliseconds(1300))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { checks = i }
            }
            try? await Task.sleep(for: .milliseconds(1100))
            guard !Task.isCancelled else { return }
            done()
        }
    }
}

// MARK: 7. Year

private struct YearStep: View {
    let hoursIndex: Int
    let next: () -> Void
    @State private var shown = 0
    @State private var reveal = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var days: Int { OnboardingMath.daysPerYear(hoursIndex: hoursIndex) }
    private var back: Int { OnboardingMath.daysBackIfHalved(hoursIndex: hoursIndex) }

    var body: some View {
        OBScaffold(step: 7, title: "Look at your year.", primaryTitle: "LET\u{2019}S DO IT", primaryAction: next) {
            VStack(alignment: .leading, spacing: 14) {
                Text("\(shown) days")
                    .font(Cream.rounded(80, .heavy))
                    .kerning(-3)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(OB.warm)
                    .monospacedDigit()
                    .accessibilityLabel("\(days) days a year")
                Text("on your phone each year.")
                    .font(Cream.rounded(20, .medium))
                    .foregroundStyle(OB.soft)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 26), spacing: 3) {
                    ForEach(0..<365, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(color(i))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
                .padding(.top, 8)
                .accessibilityHidden(true)

                Text("Cut it in half. Get \(back) days back.")
                    .font(Cream.rounded(24, .heavy))
                    .foregroundStyle(OB.sage)
                    .opacity(reveal ? 1 : 0)
                Text("An estimate from your answer, in full 24-hour days.")
                    .font(Cream.rounded(13, .medium))
                    .foregroundStyle(Matte.textSoft)
            }
        }
        .task {
            if effectiveReduceMotion(systemReduceMotion) { shown = days; reveal = true; return }
            let steps = 30
            for k in 1...steps {
                let t = Double(k) / Double(steps)
                shown = Int(Double(days) * (1 - pow(1 - t, 3)))
                try? await Task.sleep(for: .milliseconds(45))
            }
            shown = days
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(.easeOut(duration: 0.5)) { reveal = true }
        }
    }

    private func color(_ i: Int) -> Color {
        guard i < shown else { return Color(hex: 0x23262B) }
        return reveal && i >= shown - back ? OB.sage : OB.warm
    }
}

// MARK: 8. Plus (preview only)

private struct PlusStep: View {
    let next: () -> Void

    private static let items: [(String, String, String)] = [
        ("1", "It saves your work.", "It remembers your tabs and files."),
        ("2", "It locks your PC too.", "Phone and PC lock together."),
        ("3", "It brings your work back.", "One tap, and it is all open again.")
    ]

    var body: some View {
        OBScaffold(step: 8, title: "Plus works on your PC.", subtitle: "You link your PC after you get Plus.", primaryTitle: "NOT NOW", primaryAction: next) {
            VStack(alignment: .leading, spacing: 14) {
                StickerNote(text: "coming soon", color: OB.warm, tilt: -3)
                ForEach(Self.items, id: \.0) { item in
                    HStack(alignment: .top, spacing: 16) {
                        Text(item.0).font(Cream.rounded(34, .heavy)).foregroundStyle(OB.ice)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.1).font(Cream.rounded(20, .bold)).foregroundStyle(Matte.text)
                            Text(item.2).font(Cream.rounded(15, .regular)).foregroundStyle(Matte.textSoft)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(OB.panel))
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

// MARK: 9. Ready

/// Hold the button for 3 seconds to start the first session. The ring fills while you hold.
/// Let go early and it empties. VoiceOver and Switch Control get a plain "Start now" action,
/// because a long hold can be hard to do.
private struct ReadyStep: View {
    static let holdSeconds = 3.0

    let start: () -> Void
    let later: () -> Void
    @State private var ring: CGFloat = 0
    @State private var holding = false
    @State private var locked = false
    @State private var burst = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var reduce: Bool { effectiveReduceMotion(systemReduceMotion) }

    private var holdLabel: String {
        if locked { return "LOCKED IN" }
        return holding ? "KEEP HOLDING" : "HOLD TO START"
    }

    var body: some View {
        OBScaffold(
            step: 9, title: "Make a promise.", subtitle: "25 minutes. Phone down.",
            primaryView: AnyView(holdButton),
            secondaryTitle: "Not now", secondaryAction: later
        ) {
            ZStack {
                Circle().stroke(Color(hex: 0x23262B), lineWidth: 14)
                Circle().trim(from: 0, to: ring)
                    .stroke(OB.ice, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("25:00").font(Cream.rounded(58, .heavy)).kerning(-2).foregroundStyle(Matte.text).monospacedDigit()
                    Text(locked ? "locked in" : holding ? "keep holding" : "hold the button")
                        .font(Cream.rounded(16, .medium)).foregroundStyle(Matte.textSoft)
                }
                ConfettiBurst(go: burst)
            }
            .frame(width: 260, height: 260)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("25 minutes")
        }
    }

    private var holdButton: some View {
        Text(holdLabel)
            .font(Cream.rounded(17, .heavy))
            .tracking(1)
            .foregroundStyle(OB.ink)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(OB.ice))
            .scaleEffect(holding && !locked ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: holding)
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: Self.holdSeconds, maximumDistance: 60) {
                commit()
            } onPressingChanged: { pressing in
                guard !locked else { return }
                holding = pressing
                if pressing {
                    withAnimation(.linear(duration: Self.holdSeconds)) { ring = 1 }
                } else {
                    withAnimation(.easeOut(duration: 0.3)) { ring = 0 }
                }
            }
            .sensoryFeedback(.success, trigger: locked)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Hold to start 25 minutes")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Start now") { commit() }
            .accessibilityIdentifier("hold-to-start")
    }

    private func commit() {
        guard !locked else { return }
        locked = true
        holding = false
        ring = 1
        if !reduce { burst = true }
        Task {
            try? await Task.sleep(for: .milliseconds(reduce ? 200 : 800))
            start()
        }
    }
}

/// Small dots that fly out from the middle once.
private struct ConfettiBurst: View {
    let go: Bool
    @State private var started = false
    @State private var flying = false
    @State private var fading = false
    private static let colors = [OB.ice, OB.sage, OB.warm]

    var body: some View {
        ZStack {
            ForEach(0..<18, id: \.self) { i in
                let angle = Double(i) / 18 * 2 * Double.pi
                Circle()
                    .fill(Self.colors[i % Self.colors.count])
                    .frame(width: 9, height: 9)
                    .offset(x: flying ? cos(angle) * 150 : 0, y: flying ? sin(angle) * 150 : 0)
                    .opacity(started && !fading ? 1 : 0)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: go) { _, now in
            guard now else { return }
            started = true
            withAnimation(.easeOut(duration: 0.9)) { flying = true }
            withAnimation(.easeIn(duration: 0.5).delay(0.4)) { fading = true }
        }
    }
}
