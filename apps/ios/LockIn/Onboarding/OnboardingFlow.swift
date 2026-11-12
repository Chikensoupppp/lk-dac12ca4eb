import SwiftUI

/// First-run flow, "printed" version (docs/ONBOARDING_V2.md, mock docs/design/ob-v2.html).
///
/// Order: hook, guess, why we ask, real hours, brain, what pulls you in, lock apps, your year,
/// goals, making your plan, promise, Plus. The real hours can only be drawn by Apple's report
/// extension (Lock In can never read them), so the user taps the band that matches what they see.
/// Without Screen Time access, or without the extension, the rest of the flow uses the guess.
struct OnboardingFlow: View {
    static let stepCount = 12

    enum Step: Int {
        case hook = 1, guess, check, reveal, brain, pulls, lock, year, goals, plan, promise, plus

        /// Dark slides get light status bar text.
        var isDark: Bool { self == .brain || self == .plan || self == .plus }
    }

    @ObservedObject var restrictions: RestrictionController
    @ObservedObject var plus: PlusStore
    /// `true` means the user signed the promise, so the first session starts right away.
    let onFinish: (Bool) -> Void

    @State private var step: Step = .hook
    @State private var history: [Step] = []
    @State private var goingBack = false
    /// The poster tab the user tore off (0 = 1-2 hours ... 3 = 7+).
    @State private var guessIndex: Int?
    /// The band the user matched on the real-hours slide. Wins over the guess.
    @State private var realIndex: Int?
    @State private var categories: Set<String> = []
    @State private var goals: Set<String> = []
    @State private var signed = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var reduceMotion: Bool { effectiveReduceMotion(systemReduceMotion) }
    /// The hours answer the rest of the flow uses.
    private var hoursIndex: Int? { realIndex ?? guessIndex }

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
            if screenTimeOn && ScreenTimeReport.isAvailable { advance(to: .reveal) }
            else { advance(to: hoursIndex == nil ? .pulls : .brain) }
        case .reveal: advance(to: hoursIndex == nil ? .pulls : .brain)
        case .brain: advance(to: .pulls)
        case .pulls: advance(to: .lock)
        case .lock: advance(to: hoursIndex == nil ? .goals : .year)
        case .year: advance(to: .goals)
        case .goals: advance(to: .plan)
        case .plan: advance(to: .promise)
        case .promise: advance(to: .plus)
        case .plus: finish()
        }
    }

    /// "Not now (keep my guess)" on the why-we-ask slide.
    private func skipCheck() {
        advance(to: hoursIndex == nil ? .pulls : .brain)
    }

    private func finish() {
        OnboardingStore.save(hoursIndex: hoursIndex, categories: categories, goals: goals)
        onFinish(signed)
    }

    // MARK: Body

    var body: some View {
        ZStack {
            Group {
                switch step {
                case .hook: HookStep(next: next)
                case .guess: GuessStep(guessIndex: $guessIndex, next: next)
                case .check: CheckStep(restrictions: restrictions, next: next, skip: skipCheck)
                case .reveal: RevealStep(guessIndex: guessIndex, realIndex: $realIndex, next: next)
                case .brain: HeartBrainStep(hoursIndex: hoursIndex ?? 0, next: next)
                case .pulls: PullsStep(categories: $categories, next: next)
                case .lock: LockAppsStep(restrictions: restrictions, next: next)
                case .year: YearStep(hoursIndex: hoursIndex ?? 1, next: next)
                case .goals: GoalsStep(goals: $goals, next: next)
                case .plan: PlanStep(hoursIndex: hoursIndex, categories: categories, goals: goals, next: next)
                case .promise: PromiseStep(signed: $signed, next: next)
                case .plus: PlusOfferStep(plus: plus, next: next)
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
    }
}
