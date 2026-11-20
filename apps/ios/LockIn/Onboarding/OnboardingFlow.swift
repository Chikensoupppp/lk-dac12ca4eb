import SwiftUI

/// First-run flow, "printed" version (docs/ONBOARDING_V2.md, mock docs/design/ob-v2.html).
///
/// The long way is the default: the first slide opens it, and "Skip intro" ends it so the Focus screen's
/// coach takes over (task, minutes, distracting apps, one hold to start). The introduction goes:
/// guess, real hours, what they mean, two how-it-works slides, what pulls you in, lock apps, goals,
/// when works for you (no time is set for the user),
/// the plan, the Plus offer ("Not now" is one tap), and last a real "slide to lock in" that starts
/// the first session. Seeing Plus here counts as the one Plus offer, so it is not shown again after
/// the first session. The real hours can only be drawn by Apple's report extension (Lock In can
/// never read them), so slides 3 and 4 are drawn by it. Without Screen Time access, or without the
/// extension, slide 4 uses the guess.
struct OnboardingFlow: View {
    static let stepCount = 13

    enum Step: Int {
        case hook = 1, guess, reveal, brain, appsWait, comeBack, pulls, lock, goals, plan, plus, slide
        /// "When works for you?" (`WhenSteps.swift`): after the goals, and from the plan's "Change time".
        case whenPick

        /// Every slide is light now (calm palette), so the status bar text stays dark.
        var isDark: Bool { false }

        /// For analytics: "hook", "guess", ... "whenPick".
        var name: String { String(describing: self) }
    }

    @ObservedObject var restrictions: RestrictionController
    @ObservedObject var plus: PlusStore
    /// True when the user slid to lock in on the last slide: start the first session now.
    let onFinish: (_ startNow: Bool) -> Void

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
    /// The plan's "Make it easier" steps and the time picked on the schedule screens.
    @State private var easier = 0
    @State private var timeChoice: TimeChoice?
    /// The plan as it was when "When works for you?" opened (its length and days).
    @State private var draftPlan: LockInPlan?
    /// Apple's Screen Time box is up; a second tap waits for it.
    @State private var askingScreenTime = false
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
        Analytics.track("onboarding_step_viewed", ["step": target.name, "back": back])
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
        case .guess:
            Analytics.track("guess_chosen", ["hours": guessIndex.map { ["1-2h", "3-4h", "5-6h", "7h+"][min(max($0, 0), 3)] } ?? "skipped"])
            askScreenTime()
        case .reveal: advance(to: .brain)
        case .brain: advance(to: .appsWait)
        case .appsWait: advance(to: .comeBack)
        case .comeBack: advance(to: .pulls)
        case .pulls:
            Analytics.track("pulls_chosen", ["pulls": categories.sorted(), "count": categories.count])
            advance(to: .lock)
        case .lock:
            // Counts only: which apps were picked stays with Apple.
            Analytics.track("apps_chosen", ["apps": restrictions.selection.applicationTokens.count,
                                            "categories": restrictions.selection.categoryTokens.count])
            advance(to: .goals)
        // The user picks their own time; the plan then shows it (nothing is set for them).
        case .goals:
            Analytics.track("goals_chosen", ["goals": goals.sorted(), "count": goals.count])
            openWhen(draftFromAnswers)
        case .plan:
            let p = draftFromAnswers
            Analytics.track("plan_accepted", ["sessions_per_day": p.sessionsPerDay, "minutes": p.minutes,
                                              "made_easier": easier])
            advance(to: .plus)
        case .plus: advance(to: .slide)
        case .slide: finish(startNow: true)
        case .whenPick: break
        }
    }

    // MARK: When works for you

    /// The plan the answers make, before a time is picked (its length and days, not its time).
    private var draftFromAnswers: LockInPlan {
        var p = PlanRules.make(hoursIndex: hoursIndex, pulls: categories, goals: goals)
        for _ in 0..<easier { p = PlanRules.apply(.easier, to: p) }
        return p
    }

    /// "When works for you?": after the goals, and from the plan's "Change time".
    private func openWhen(_ plan: LockInPlan) {
        draftPlan = plan
        advance(to: .whenPick)
    }

    /// A time was chosen: on to the plan (first time), or back to it (from "Change time").
    private func chooseTime(_ choice: TimeChoice) {
        timeChoice = choice
        Analytics.track("time_picked", ["start_time": DailyNudge.timeText(minute: choice.startMinute),
                                        "start_minute": choice.startMinute, "days": choice.weekdays.count,
                                        "then": String(describing: choice.schedule.then)])
        guard history.contains(.plan) else { advance(to: .plan); return }
        while let last = history.last, last != .plan { history.removeLast() }
        if history.last == .plan { history.removeLast() }
        move(to: .plan, back: true)
    }

    /// "See my actual time" on the guess slide: Apple's Screen Time box comes up straight away (it
    /// shows only once; after that the answer sticks). With access, the real hours are next;
    /// without it, the flow goes on with the guess.
    private func askScreenTime() {
        guard !askingScreenTime else { return }
        let afterAnswer = {
            Analytics.track("screen_time_answered", ["allowed": screenTimeOn])
            if screenTimeOn && ScreenTimeReport.isAvailable { usedReport = true; advance(to: .reveal) }
            else { usedReport = false; advance(to: hoursIndex == nil ? .appsWait : .brain) }
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-onboarding") { afterAnswer(); return }
        #endif
        switch restrictions.status {
        case .needsAuthorization, .failed:
            askingScreenTime = true
            Task { @MainActor in
                await restrictions.requestAuthorization()
                askingScreenTime = false
                afterAnswer()
            }
        default:
            afterAnswer()
        }
    }

    private func finish(startNow: Bool = false) {
        Analytics.track("onboarding_completed", ["start_now": startNow, "skipped_intro": step == .hook,
                                                 "last_step": step.name])
        OnboardingStore.save(hoursIndex: hoursIndex, categories: categories, goals: goals)
        if let choice = timeChoice, var plan = PlanStore.load() {
            let hasPlus = plus.hasPlus
            // Fitted-to-each-day is Plus; without it, one time for every day.
            if !hasPlus, plan.dayStarts != nil { plan.dayStarts = nil; PlanStore.save(plan) }
            choice.schedule.save()
            let saved = plan
            Task { @MainActor in
                await ScheduleApplier.apply(plan: saved, schedule: choice.schedule, hasPlus: hasPlus, restrictions: restrictions)
            }
        }
        onFinish(startNow)
    }

    // MARK: Body

    var body: some View {
        ZStack {
            // The flow sits over the Focus screen (so it is there from the first frame). Paper under
            // the slides keeps that screen from showing through while two slides cross-fade.
            Ink.paper.ignoresSafeArea()
            Group {
                switch step {
                case .hook: HookStep(next: next, startNow: { finish() })
                case .guess: GuessStep(guessIndex: $guessIndex, next: next)
                case .reveal: RevealStep(guessIndex: guessIndex, next: next)
                case .brain: HeartBrainStep(hoursIndex: hoursIndex, useReport: usedReport, next: next)
                case .pulls: PullsStep(categories: $categories, next: next)
                case .lock: LockAppsStep(restrictions: restrictions, next: next)
                case .goals: GoalsStep(goals: $goals, next: next)
                case .slide: SlideToLockStep(next: next)
                case .appsWait: LaterStep(next: next)
                case .comeBack: StackDaysStep(next: next)
                case .plan:
                    PlanStep(hoursIndex: hoursIndex, realShown: usedReport, categories: categories, goals: goals,
                             easier: $easier, timeChoice: timeChoice, cantDo: openWhen, next: next)
                case .plus: PlusOfferStep(plus: plus, next: next)
                case .whenPick:
                    if let plan = draftPlan { WhenPickStep(plan: plan, done: chooseTime) }
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
        .onAppear { Analytics.track("onboarding_step_viewed", ["step": step.name, "back": false]) }
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
