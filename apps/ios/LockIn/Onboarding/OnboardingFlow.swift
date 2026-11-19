import SwiftUI

/// First-run flow, "printed" version (docs/ONBOARDING_V2.md, mock docs/design/ob-v2.html).
///
/// The long way is the default: the first slide opens it, and "Skip intro" ends it so the Focus screen's
/// coach takes over (task, minutes, distracting apps, one hold to start). The introduction goes:
/// guess, why we ask, real hours, brain, what pulls you in, lock apps,
/// goals, three how-it-works slides, making your plan, and the Plus offer last ("Not now" is one tap).
/// Seeing it here counts as the one Plus offer, so it is not shown again after the first session.
/// The real hours can only be drawn by Apple's report extension (Lock In can never read them), so
/// slides 4 and 5 are drawn by it. Without Screen Time access, or without the extension, slide 5
/// uses the guess. Order: the problem (1-5), how SwipeLater fixes it (6-8), make it yours (9-11),
/// the plan (12), Plus (13).
struct OnboardingFlow: View {
    static let stepCount = 12

    enum Step: Int {
        case hook = 1, guess, reveal, brain, slide, appsWait, comeBack, pulls, lock, goals, plan, plus
        /// "Can't do 4:00?" from the plan: optional, on the plan's step (`WhenSteps.swift`).
        case whenAsk, whenFree, whenPick

        /// Every slide is light now (calm palette), so the status bar text stays dark.
        var isDark: Bool { false }
    }

    @ObservedObject var restrictions: RestrictionController
    @ObservedObject var plus: PlusStore
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
    /// The plan's "Make it easier" steps and the time picked on the schedule screens.
    @State private var easier = 0
    @State private var timeChoice: TimeChoice?
    /// The plan as it was when "Can't do 4:00?" was tapped, and the calendar's days for it.
    @State private var draftPlan: LockInPlan?
    @State private var calendarDays: [CalendarFit.Day] = []
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
        case .guess: askScreenTime()
        case .reveal: advance(to: .brain)
        case .brain: advance(to: .slide)
        case .slide: advance(to: .appsWait)
        case .appsWait: advance(to: .comeBack)
        case .comeBack: advance(to: .pulls)
        case .pulls: advance(to: .lock)
        case .lock: advance(to: .goals)
        case .goals: advance(to: .plan)
        case .plan: advance(to: .plus)
        case .plus: finish()
        case .whenAsk, .whenFree, .whenPick: break
        }
    }

    // MARK: "Can't do 4:00?"

    /// Calendar on: the free-time screen (or picking, if the calendar is empty). Not asked yet:
    /// the ask screen. Said no before: straight to picking, no nagging.
    private func openWhen(_ plan: LockInPlan) {
        draftPlan = plan
        switch CalendarAccess.state {
        case .allowed:
            loadDays(plan)
            advance(to: calendarHasEvents ? .whenFree : .whenPick)
        case .notAsked: advance(to: .whenAsk)
        case .refused: advance(to: .whenPick)
        }
    }

    private func useCalendar() {
        Task { @MainActor in
            let allowed = await CalendarAccess.ask()
            if allowed, let plan = draftPlan { loadDays(plan) }
            advance(to: allowed && calendarHasEvents ? .whenFree : .whenPick)
        }
    }

    private func loadDays(_ plan: LockInPlan) {
        calendarDays = CalendarFit.days(weekdays: plan.weekdays, events: CalendarAccess.busy(), from: .now)
    }

    private var calendarHasEvents: Bool {
        calendarDays.contains { !$0.busy.isEmpty || $0.dayOff != nil }
    }

    /// A time was chosen: back to the plan, which now shows it.
    private func chooseTime(_ choice: TimeChoice) {
        timeChoice = choice
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
            if screenTimeOn && ScreenTimeReport.isAvailable { usedReport = true; advance(to: .reveal) }
            else { usedReport = false; advance(to: hoursIndex == nil ? .slide : .brain) }
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

    private func finish() {
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
        onFinish()
    }

    // MARK: Body

    var body: some View {
        ZStack {
            Group {
                switch step {
                case .hook: HookStep(next: next, startNow: finish)
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
                case .whenAsk: WhenAskStep(useCalendar: useCalendar, pickOwn: { advance(to: .whenPick) })
                case .whenFree:
                    if let plan = draftPlan {
                        WhenFreeStep(plan: plan, days: calendarDays, done: chooseTime, pickOwn: { advance(to: .whenPick) })
                    }
                case .whenPick:
                    if let plan = draftPlan {
                        let allowed = CalendarAccess.state == .allowed
                        WhenPickStep(plan: plan, days: allowed ? calendarDays : [], calendarAllowed: allowed,
                                     backToSuggestions: history.last == .whenFree ? back : nil, done: chooseTime)
                    }
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
