import SwiftUI

/// First-run flow, "printed" version (docs/ONBOARDING_V2.md, mock docs/design/ob-v2.html).
///
/// The long way is the default: the first slide opens it, and "Skip intro" ends it so the Focus screen's
/// coach takes over (task, minutes, distracting apps, one hold to start). The introduction goes:
/// guess, why we ask, real hours, brain, what pulls you in, lock apps,
/// your year, goals, three how-it-works slides, making your plan. There is no promise to sign and no Plus offer here; Plus is
/// shown once, after the first finished free session.
/// The real hours can only be drawn by Apple's report extension (Lock In can never read them), so
/// slides 4 and 5 are drawn by it. Without Screen Time access, or without the extension, slide 5
/// uses the guess. Order: the problem (1-5), how SwipeLater fixes it (6-8), make it yours (9-11),
/// the plan (12).
struct OnboardingFlow: View {
    static let stepCount = 12

    enum Step: Int {
        case hook = 1, guess, check, reveal, brain, slide, appsWait, comeBack, pulls, lock, goals, plan

        /// Every slide is light now (calm palette), so the status bar text stays dark.
        var isDark: Bool { false }
    }

    @ObservedObject var restrictions: RestrictionController
    let onFinish: () -> Void

    @State private var step: Step = .hook
    @State private var history: [Step] = []
    @State private var goingBack = false
    /// The poster tab the user tore off (0 = 1-2 hours ... 3 = 7+).
    @State private var guessIndex: Int?
    /// The real-hours report was shown. The app cannot read that number (Apple keeps it inside the
    /// report), so later slides that need it are drawn by the report too, or left out.
    @State private var usedReport = false
    @State private var categories: Set<String> = []
    @State private var goals: Set<String> = []
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var reduceMotion: Bool { effectiveReduceMotion(systemReduceMotion) }
    /// The hours answer the rest of the flow uses.
    private var hoursIndex: Int? { guessIndex }

    private var screenTimeOn: Bool {
        switch restrictions.status {
        case .needsAuthorization, .denied, .failed: return false
        default: return true
        }
    }

    // MARK: Moving between slides

    private func move(to target: Step, back: Bool) {
        goingBack = back
        let change = { step = target }
        if reduceMotion { withAnimation(.easeInOut(duration: 0.2), change) }
        else { withAnimation(.spring(response: 0.5, dampingFraction: 0.86), change) }
    }

    private func advance(to target: Step) {
        history.append(step)
        move(to: target, back: false)
    }

    private func back() {
        guard let previous = history.popLast() else { return }
        move(to: previous, back: true)
    }

    /// Slides that need an hours answer are left out when there is none, rather than show a
    /// number the user never gave.
    private func next() {
        switch step {
        case .hook: advance(to: .guess)
        case .guess: advance(to: .check)
        case .check:
            if screenTimeOn && ScreenTimeReport.isAvailable { usedReport = true; advance(to: .reveal) }
            else { advance(to: hoursIndex == nil ? .slide : .brain) }
        case .reveal: advance(to: .brain)
        case .brain: advance(to: .slide)
        case .slide: advance(to: .appsWait)
        case .appsWait: advance(to: .comeBack)
        case .comeBack: advance(to: .pulls)
        case .pulls: advance(to: .lock)
        case .lock: advance(to: .goals)
        case .goals: advance(to: .plan)
        case .plan: finish()
        }
    }

    /// "Not now (keep my guess)" on the why-we-ask slide.
    private func skipCheck() {
        usedReport = false
        advance(to: hoursIndex == nil ? .slide : .brain)
    }

    private func finish() {
        OnboardingStore.save(hoursIndex: hoursIndex, categories: categories, goals: goals)
        onFinish()
    }

    // MARK: Body

    var body: some View {
        ZStack {
            Group {
                switch step {
                case .hook: HookStep(next: next, startNow: finish)
                case .guess: GuessStep(guessIndex: $guessIndex, next: next)
                case .check: CheckStep(restrictions: restrictions, next: next, skip: skipCheck)
                case .reveal: RevealStep(guessIndex: guessIndex, next: next)
                case .brain: HeartBrainStep(hoursIndex: hoursIndex, useReport: usedReport, next: next)
                case .pulls: PullsStep(categories: $categories, next: next)
                case .lock: LockAppsStep(restrictions: restrictions, next: next)
                case .goals: GoalsStep(goals: $goals, next: next)
                case .slide: SlideToLockStep(next: next)
                case .appsWait: LaterStep(next: next)
                case .comeBack: StackDaysStep(next: next)
                case .plan: PlanStep(hoursIndex: hoursIndex, realShown: usedReport, categories: categories, goals: goals, next: next)
                }
            }
            .environment(\.obBack, history.isEmpty || step == .plan ? nil : back)
            .id(step)
            .transition(reduceMotion
                ? .opacity
                : .asymmetric(
                    insertion: .move(edge: goingBack ? .leading : .trailing).combined(with: .opacity),
                    removal: .move(edge: goingBack ? .trailing : .leading).combined(with: .opacity)))
        }
        .preferredColorScheme(step.isDark ? .dark : .light)
        #if DEBUG
        .onAppear {
            if let n = DebugShot.onboardingStep, let target = Step(rawValue: n) {
                guessIndex = 2
                history = [.hook]
                step = target
            }
        }
        #endif
    }
}
