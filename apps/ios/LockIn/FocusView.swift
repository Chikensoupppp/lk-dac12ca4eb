import SwiftUI
import WidgetKit
import UIKit

/// Focus screen. `timing` is the single source of truth for the session:
/// nil means idle, non-nil means a session is running until `timing.endsAt`.
/// The clock, labels and completion all derive from it.
struct FocusView: View {
    private static let durationOptions = [15, 25, 45, 60, 90]

    private let store: SessionStoring

    @AppStorage("lockin.minutes.v1") private var selectedMinutes = 45
    @State private var timing: SessionTiming?
    @State private var sessionID: UUID?
    @State private var justCompleted = false
    @State private var completionCount = 0
    /// Set when launch found a session that expired while the app was not running.
    /// Cleared from storage once, in `.onAppear`, so completion cannot repeat.
    @State private var expiredOnLaunch = false
    @StateObject private var restrictions = RestrictionController()
    @State private var showRestrictions = false
    @StateObject private var pc = PCLink()
    @StateObject private var plus = PlusStore()
    @StateObject private var keys = KeyStore()
    /// Plus: the next session is Locked (no quit button; only a Key Holder or the weekly
    /// emergency exit ends it early).
    @State private var lockedNext = false
    @State private var showQuit = false
    @State private var showLockedExit = false
    @State private var showKeys = false
    @State private var showPlusOffer = false
    @State private var showPC = false
    /// Looks for a Nogbox PC on the Wi-Fi while the phone is not paired ("Connect to ...").
    @StateObject private var finder = PCFinder()
    @StateObject private var tasks = WorkTaskStore()
    @State private var showTasks = false
    /// Right after the intro (promise signed): 25 minutes are picked and a note suggests starting
    /// now. Nothing starts until the user taps LOCK IN.
    @State private var firstSessionHint = false
    /// One-time pointer to the tools (goals, keys, restrictions) after the first finished session.
    @State private var showToolsHint = false
    @AppStorage(IfThenPlan.onKey) private var ifThenOn = false
    @AppStorage(IfThenPlan.cueKey) private var ifThenCue = ""
    @AppStorage("lockin.coach.pending.v1") private var coachPending = false
    @State private var coachStep: FocusCoachStep?
    @State private var coachPressing = false
    @State private var coachReward: String?
    /// The user left the app while the brain dared them to open a locked app.
    @State private var leftToTry = false
    /// After a finished session: the "time focused" card, then the streak screen, then (once) the Plus offer.
    @State private var completion: CompletionInfo?
    @State private var pendingStreak = false
    @State private var pendingPlus = false
    @State private var pendingTaskPicker = false
    /// Proof Check: Screen Time access was turned off during this session.
    @State private var showProofBroken = false
    @StateObject private var goals = GoalStore()
    @State private var showGoals = false
    /// The Sunday report, opened by itself once a week.
    @State private var report: ReportWeek?
    /// The lock-in plan made in the first run (nil when the intro was skipped), shown as
    /// "Today's plan" and adjusted by the Monday check-in.
    @State private var plan: LockInPlan?
    @State private var showSchedule = false
    @State private var checkIn: PlanWeekResult?
    /// Minutes of a session that finished while the app was closed; logged once in `.onAppear`.
    @State private var expiredMinutes = 0
    /// Short mood after a session ends (finished glow, gray glow for an early end).
    @State private var flash: FocusMood?
    @State private var flashTask: Task<Void, Never>?
    @State private var startCount = 0
    @State private var endEarlyCount = 0
    /// First-run flow. Skipped for anyone with a session already running.
    @State private var onboardingDone: Bool
    /// Streak screen, shown after the first finished session of a day.
    @State private var showStreak = false
    @State private var streakMinutes = 0

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { effectiveReduceMotion(systemReduceMotion) }
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(store: SessionStoring = UserDefaultsSessionStore()) {
        self.store = store
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset-state") {
            store.clear()
            UserDefaults.standard.removeObject(forKey: "lockin.coach.pending.v1")
            UserDefaults.standard.removeObject(forKey: "lockin.minutes.v1")
            UserDefaults.standard.removeObject(forKey: "lockin.firstWin.v1")
            UserDefaults.standard.removeObject(forKey: "lockin.plusOffered.v1")
            UserDefaults.standard.removeObject(forKey: PlanStore.key)
            UserDefaults.standard.removeObject(forKey: PlanStore.checkedKey)
        }
        #endif
        _plan = State(initialValue: PlanStore.load())
        var hadSession = false
        switch SessionRecovery.resolve(store.load(), now: .now) {
        case .idle:
            break
        case .active(let record):
            hadSession = true
            _timing = State(initialValue: record.timing)
            _sessionID = State(initialValue: record.id)
        case .expired(let record):
            hadSession = true
            _expiredMinutes = State(initialValue: Int((record.duration / 60).rounded()))
            _justCompleted = State(initialValue: true)
            _completionCount = State(initialValue: 1)
            _expiredOnLaunch = State(initialValue: true)
        }
        _onboardingDone = State(initialValue: OnboardingStore.isDone() || hadSession)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-coach"), !hadSession {
            UserDefaults.standard.set(true, forKey: "lockin.coach.pending.v1")
            _coachStep = State(initialValue: .task)
        }
        if DebugShot.name != nil {
            _onboardingDone = State(initialValue: DebugShot.onboardingStep == nil)
            DebugShot.seed()
        }
        #endif
    }

    #if DEBUG
    /// Opens the screen named by `-shot` (see `DebugShot`), after the main screen has settled.
    private func runShot() {
        guard let name = DebugShot.name, DebugShot.onboardingStep == nil else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            switch name {
            case "active":
                tasks.add("Studying")
                startSession()
                pc.debugShow(PCActivity(app: "YouTube", onTask: false, nudges: 2))
            case "tasks": showTasks = true
            case "first": selectedMinutes = 25; firstSessionHint = true
            case "quit", "quit-type": startSession(); showQuit = true
            case "locked": startSession(); QuitRules.markLocked(sessionID); showLockedExit = true
            case "proof": startSession(); showProofBroken = true
            case "keys": showKeys = true
            case "goals": showGoals = true
            case "report":
                report = ReportWeek(id: FocusLog.calendar.date(byAdding: .day, value: -7, to: FocusLog.weekStart(.now))!)
            case "streak": StreakStore.record(); streakMinutes = 45; showStreak = true
            case "plus": showPlusOffer = true
            case "rest-streak":
                for d in [-3, -2, 0] { StreakStore.record(Calendar.current.date(byAdding: .day, value: d, to: .now)!) }
                streakMinutes = 25
                showStreak = true
            case "completion":
                tasks.add("Studying")
                completion = CompletionInfo(minutes: 25, task: "Studying", nextMinutes: 25, firstEver: false, nudgeMinute: 15 * 60 + 20)
            case "tools-hint": showToolsHint = true
            case "if-then": ifThenOn = true; ifThenCue = "I sit at my desk"
            case "goals-habits":
                ifThenOn = true; ifThenCue = "I sit at my desk"
                UserDefaults.standard.set(15 * 60 + 20, forKey: "lockin.dailyNudge.minute.v1")
                showGoals = true
            case "allowed":
                tasks.add("Studying")
                for name in ["Spotify", "notion.so", "Docs"] { AllowedApps.add(name, for: "Studying") }
                showTasks = true
            case "restrictions": showRestrictions = true
            // The coach's hands-on steps and the dare after the first start.
            case "coach-goal": tasks.add("Studying"); selectedMinutes = 25; coachStep = .goal
            case "coach-partner": tasks.add("Studying"); selectedMinutes = 25; coachStep = .partner
            case "coach-try": tasks.add("Studying"); selectedMinutes = 25; startSession(); coachStep = .tryIt
            case "coach-caught": tasks.add("Studying"); selectedMinutes = 25; startSession(); coachStep = .caught
            default: break
            }
        }
    }
    #endif

    private var isLocked: Bool { timing != nil }

    /// UI tests that finish sessions must not be covered by the streak screen, unless asked.
    private var streakScreenAllowed: Bool {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains(where: { $0.hasPrefix("-ui-testing") }) { return args.contains("-ui-testing-streak") }
        #endif
        return true
    }

    /// UI tests that finish sessions must not be covered by the completion card, unless asked.
    private var completionCardAllowed: Bool {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains(where: { $0.hasPrefix("-ui-testing") }) { return args.contains("-ui-testing-completion-card") }
        #endif
        return true
    }

    /// The Plus offer comes once, after the first finished free session (never before it).
    private var plusOfferAllowed: Bool {
        guard !plus.hasPlus, !UserDefaults.standard.bool(forKey: "lockin.plusOffered.v1") else { return false }
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains(where: { $0.hasPrefix("-ui-testing") }) { return args.contains("-ui-testing-plus-after") }
        #endif
        return true
    }

    /// Whole minutes focused in the running session (a partial session still counts).
    private var focusedMinutesSoFar: Int {
        guard let timing else { return 0 }
        let seconds = min(max(Date.now.timeIntervalSince(timing.startedAt), 0), timing.duration)
        return Int(seconds / 60)
    }

    /// One thing at a time after a session: the streak screen, then the Plus offer, then the task picker.
    private func advanceAfterSession() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            guard timing == nil, completion == nil, !showStreak, !showPlusOffer else { return }
            if pendingStreak {
                pendingStreak = false
                showStreak = true
            } else if pendingPlus {
                pendingPlus = false
                UserDefaults.standard.set(true, forKey: "lockin.plusOffered.v1")
                showPlusOffer = true
            } else if pendingTaskPicker {
                pendingTaskPicker = false
                showTasks = true
            } else if toolsHintAllowed {
                UserDefaults.standard.set(true, forKey: "lockin.toolsHint.v1")
                showToolsHint = true
            }
        }
    }

    /// The tools pointer shows once, after the first finished session, when nothing else is waiting.
    private var toolsHintAllowed: Bool {
        guard onboardingDone, coachStep == nil, !UserDefaults.standard.bool(forKey: "lockin.toolsHint.v1") else { return false }
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains(where: { $0.hasPrefix("-ui-testing") }) { return args.contains("-ui-testing-tools-hint") }
        #endif
        return true
    }

    @ViewBuilder private var toolsHintBubble: some View {
        if showToolsHint {
            Text("Goals, keys and app limits are up here.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(FocusPaper.page)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: 240)
                .background(RoundedRectangle(cornerRadius: 14).fill(FocusPaper.ink))
                .onTapGesture { showToolsHint = false }
                .task {
                    try? await Task.sleep(for: .seconds(8))
                    showToolsHint = false
                }
                .accessibilityLabel("Tip: goals, keys and app limits are in the buttons at the top right.")
                .accessibilityIdentifier("tools-hint")
        }
    }

    private var ifThenLine: String? { IfThenPlan.line(on: ifThenOn, cue: ifThenCue) }

    private var stateAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 1)
    }

    private var clockCaption: String {
        if let timing {
            return "Ends " + timing.endsAt.formatted(date: .omitted, time: .shortened)
        }
        if flash == .endedEarly { return "Session ended" }
        return justCompleted ? "Session complete" : "Ready"
    }

    private var screen: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 700
            let gutter: CGFloat = compact ? 18 : 24
            // The clock gives a little room when "Today's plan" sits above it.
            let planShown = plan != nil && coachStep == nil && !isLocked
            let side = min(geo.size.width - 2 * gutter, compact ? 260 : 348,
                           geo.size.height * (compact ? (planShown ? 0.32 : 0.38) : (planShown ? 0.34 : 0.40)))
            VStack(alignment: .leading, spacing: compact ? 4 : 12) {
                // Keep minutes and the session action reachable while long tasks, coach
                // prompts and accessibility text can scroll independently above them.
                GeometryReader { upper in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if coachStep == nil {
                                topBar
                                toolsHintBubble.frame(maxWidth: .infinity, alignment: .trailing)
                                PCStatusLine(pc: pc, finder: finder, isLocked: isLocked, open: { showPC = true }, connect: { near in
                                    showPC = true
                                    Task { await pc.pairNearby(near) }
                                })
                            } else {
                                coachOverlay
                            }
                            statusLines
                            if let plan, coachStep == nil, !isLocked {
                                TodayPlanCard(plan: plan, progress: PlanProgress.make(plan: plan), compact: compact)
                                    .padding(.top, compact ? 6 : 10)
                                ScheduleLine(plan: plan, schedule: LockInSchedule.load()) { showSchedule = true }
                            }
                            Spacer(minLength: 8)
                            VStack(spacing: 4) {
                                CountdownClockView(duration: TimeInterval(selectedMinutes * 60),
                                                   timing: timing, caption: clockCaption,
                                                   idleFraction: flash == .finished ? 1 : min(Double(selectedMinutes) / 60, 1),
                                                   flash: flash, showsMascot: coachStep == nil)
                                    .frame(width: side, height: side)
                                if dynamicTypeSize.isAccessibilitySize {
                                    Text(clockCaption)
                                        .font(.body)
                                        .foregroundStyle(FocusPaper.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            Spacer(minLength: 8)
                            if !isLocked {
                                WorkTaskPill(tasks: tasks) { showTasks = true }
                                    .overlay(Capsule().strokeBorder(coachStep == .task ? FocusPaper.ink : .clear, lineWidth: 2))
                                    .compositingGroup()
                                    .opacity(coachStep == nil || coachStep == .task ? 1 : 0.3)
                                    .disabled(coachStep != nil && coachStep != .task)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: upper.size.height, alignment: .leading)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                if !isLocked {
                    durationControls
                }
                focusButton
            }
            .padding(.horizontal, gutter)
            .padding(.top, compact ? 4 : 12)
            .padding(.bottom, compact ? 8 : 14)
        }
        .background(FocusPaper.page.ignoresSafeArea())
        .sheet(isPresented: $showRestrictions, onDismiss: {
            guard coachStep == .apps else { return }
            if restrictions.hasSelection { coachReward = "GOT 'EM!" }
            coachStep = .goal
        }) {
            RestrictionsSheet(restrictions: restrictions)
        }
        .sheet(isPresented: $showPC, onDismiss: { if coachStep == .pc { coachStep = .hold } }) { PCSheet(pc: pc) }
        .task { if !pc.isPaired { finder.start() } }
        .onChange(of: pc.status) { _, status in
            if status == .notPaired { finder.start() } else { finder.stop() }
        }
        .onOpenURL { url in
            // The PC's QR code, scanned with the Camera app, lands here.
            guard let offer = PCPairingOffer.decode(url.absoluteString) else { return }
            showPC = true
            Task { await pc.pair(offer: offer) }
        }
        .sheet(isPresented: $showTasks) {
            WorkTaskSheet(tasks: tasks, done: { showTasks = false }, onSelection: {
                if coachStep == .task { showTasks = false; coachStep = .minutes; coachReward = "Nice." }
            }, skipCoach: coachStep == .task ? { skipCoach() } : nil)
        }
        .sheet(isPresented: $showGoals) {
            GoalSheet(goals: goals, plus: plus, onDone: { showGoals = false }, onStart: timing == nil ? {
                showGoals = false
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    if timing == nil { startFromButton() }
                }
            } : nil)
        }
        .sheet(item: $report) { r in WeekReportView(goals: goals, weekStart: r.id, plus: plus) { report = nil } }
        // Closing the check-in without choosing keeps the plan as it is.
        .sheet(item: $checkIn, onDismiss: { if let week = PlanStore.pendingCheckIn() { PlanStore.markCheckedIn(week: week) } }) { result in
            if let plan {
                PlanCheckInView(result: result, plan: plan) { next in
                    PlanStore.save(next)
                    PlanStore.markCheckedIn(week: result.weekStart)
                    self.plan = next
                    if timing == nil { selectedMinutes = next.minutes }
                    checkIn = nil
                }
            }
        }
        .sheet(isPresented: $showKeys, onDismiss: {
            guard coachStep == .partner else { return }
            if !keys.holders.isEmpty { coachReward = "NICE!" }
            coachStep = stepAfterPartner
        }) { KeysSheet(keys: keys) { showKeys = false } }
        .sheet(isPresented: $showPlusOffer, onDismiss: advanceAfterSession) { PlusOfferStep(plus: plus, intro: false) { showPlusOffer = false } }
        .sheet(isPresented: $showSchedule) {
            if let plan {
                ScheduleSheet(plan: plan, plus: plus, restrictions: restrictions,
                              saved: { self.plan = $0 }, close: { showSchedule = false })
            }
        }
        .fullScreenCover(item: $completion, onDismiss: advanceAfterSession) { info in
            SessionDoneView(info: info, keep: { completion = nil }, change: { pendingTaskPicker = true; completion = nil })
        }
        .fullScreenCover(isPresented: $showQuit) {
            QuitSheet(focusedMinutes: focusedMinutesSoFar, onQuit: { showQuit = false; endSession() }, onStay: { showQuit = false })
        }
        .fullScreenCover(isPresented: $showProofBroken) {
            ProofBrokenSheet(turnBackOn: turnShieldsBackOn) { showProofBroken = false }
        }
        .fullScreenCover(isPresented: $showLockedExit) {
            if let sessionID {
                LockedExitSheet(keys: keys, sessionID: sessionID,
                                onExit: { showLockedExit = false; endSession() },
                                onStay: { showLockedExit = false })
            }
        }
        .fullScreenCover(isPresented: $showStreak, onDismiss: advanceAfterSession) {
            StreakView(minutes: streakMinutes) { showStreak = false }
        }
    }

    @ViewBuilder private var statusLines: some View {
        if isLocked, let line = sessionWorkLine {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if pc.activity?.onTask == false {
                    Image(systemName: "exclamationmark.circle")
                        .accessibilityLabel("Off task")
                }
                Text(line)
            }
            .font(.footnote).foregroundStyle(FocusPaper.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("pc-activity")
        }
        if isLocked, let line = restrictions.statusLine {
            Text(line).accessibilityIdentifier("restrictions-line")
                .font(.footnote).foregroundStyle(FocusPaper.secondary)
        }
        if !isLocked, coachStep == nil, let line = ifThenLine {
            Text(line).accessibilityIdentifier("if-then-line")
                .font(.footnote).foregroundStyle(FocusPaper.secondary)
        }
    }

    private var durationControls: some View {
        VStack(alignment: .leading, spacing: 4) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    minutesLabel
                    Spacer(minLength: 8)
                    modeControl
                }
                VStack(alignment: .leading, spacing: 0) {
                    modeControl
                    minutesLabel
                }
            }
            DurationSelector(options: Self.durationOptions, selection: $selectedMinutes) {
                if coachStep == .minutes { coachStep = restrictions.hasSelection ? .goal : .apps; coachReward = "NICE!" }
            }
            .disabled(coachStep != nil && coachStep != .minutes)
            // Flatten first: faded layer by layer, the picked length's white number vanished into its chip.
            .compositingGroup()
            .opacity(coachStep == nil || coachStep == .minutes ? 1 : 0.3)
            .overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(coachStep == .minutes ? FocusPaper.ink : .clear, lineWidth: 2))
            coachActions
        }
    }

    private var minutesLabel: some View {
        Text("Minutes").font(.headline).foregroundStyle(FocusPaper.ink)
            .accessibilityLabel("MINUTES")
    }

    @ViewBuilder private var modeControl: some View {
        if coachStep == nil {
            lockedToggle
        }
    }

    private var framed: some View {
        screen
        .overlay(alignment: .topLeading) {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-ui-testing-completion-count") {
                Text("Completion count: \(completionCount)")
                    .accessibilityIdentifier("completion-count")
            }
            #endif
        }
        .preferredColorScheme(.light)
    }

    var body: some View {
        framed
        .accessibilityHidden(!onboardingDone)
        .overlay {
            // The intro is drawn on top from the very first frame. As a full-screen cover it only
            // slid up after this screen had drawn, so the Focus screen flashed for half a second.
            if !onboardingDone {
                OnboardingFlow(restrictions: restrictions, plus: plus) { startNow in
                    withAnimation(.easeOut(duration: 0.3)) { onboardingDone = true }
                    selectedMinutes = PlanStore.load()?.minutes ?? 25
                    plan = PlanStore.load()
                    // The intro's last slide is a real "slide to lock in": the first session starts
                    // straight away. "Skip intro" still hands over to the coach.
                    if startNow { startFirstSessionFromIntro() }
                    else {
                        coachPending = true
                        coachStep = .task
                    }
                }
                .transition(.opacity)
            }
        }
        .sensoryFeedback(.success, trigger: coachReward) { _, reward in reward != nil }
        .task(id: coachReward) {
            guard coachReward != nil else { return }
            do { try await Task.sleep(for: .milliseconds(900)) } catch { return }
            coachReward = nil
        }
        // The brain widget watches the apps picked to lock; keep that watch in step.
        .onChange(of: restrictions.selection) { _, _ in updateBrainWatch() }
        .onChange(of: restrictions.status) { _, _ in updateBrainWatch(); runProofCheck() }
        // A buddy break on the PC pauses the session here too: the end moves later, once per session.
        // Tell my partners how the lock-in is going (sealed, through iCloud), and carry out a pause they ask for.
        .onChange(of: pc.activity) { _, _ in publishPartnerStatus() }
        .onChange(of: timing) { _, newTiming in
            publishPartnerStatus()
            if newTiming == nil, coachStep?.duringSession == true { coachStep = nil }
        }
        // The dare waits a minute and a half, then steps aside; "caught" cheers for a few seconds.
        .task(id: coachStep) {
            let wait: Duration
            switch coachStep {
            case .tryIt: wait = .seconds(90)
            case .caught: wait = .seconds(6)
            default: return
            }
            let step = coachStep
            do { try await Task.sleep(for: wait) } catch { return }
            if coachStep == step { coachStep = nil }
        }
        .task(id: timing?.startedAt) {
            var round = 0
            while timing != nil, !Task.isCancelled {
                for pause in await PartnerCloud.pendingPauses(keys: keys) {
                    pc.partnerPause(appKey: pause.appKey, seconds: pause.seconds)
                }
                // Heartbeat: the partner's screen calls an update older than 90 s stale, so resend
                // every 30 s even when nothing changed.
                if round % 3 == 0 { publishPartnerStatus() }
                round += 1
                try? await Task.sleep(for: .seconds(10))
            }
        }
        .onChange(of: pc.activity) { _, activity in
            guard let seconds = activity?.breakSeconds, seconds > 0, let sessionID, timing != nil,
                  UserDefaults.standard.string(forKey: Self.breakKey) != sessionID.uuidString else { return }
            UserDefaults.standard.set(sessionID.uuidString, forKey: Self.breakKey)
            addBreak(seconds: TimeInterval(min(seconds, 600)))
        }
        .onAppear {
            if onboardingDone && coachPending && timing == nil { coachStep = .task }
            updateBrainWatch()
            runProofCheck()
            checkKeyRequests()
            if expiredOnLaunch {
                expiredOnLaunch = false
                store.clear()
                // The session ended while the app was closed. It counts for the streak,
                // The streak screen is not shown for it.
                StreakStore.record()
                Analytics.track("session_completed", ["minutes": expiredMinutes, "while_closed": true])
                FocusLog.recordFinished(minutes: expiredMinutes)
                sendWeekToPC()
            }
            goals.reschedule()
            checkReport()
            #if DEBUG
            runShot()
            #endif
            // Repairs shields left by a terminated run (expired, cancelled, or revoked).
            restrictions.reconcile(activeSessionID: timing == nil ? nil : sessionID)
            // A session restored after a relaunch tells the PC again. The PC ignores repeats.
            if let timing, let sessionID { pc.sessionStarted(SessionRecord(id: sessionID, timing: timing), extras: pcExtras) }
            LiveCountdown.reconcile(currentRecord, locked: QuitRules.isLocked(sessionID))
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: startCount)
        .sensoryFeedback(.warning, trigger: endEarlyCount)
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
            if phase == .background, coachStep == .tryIt { leftToTry = true }
            guard phase == .active else { return }
            // Back from trying a locked app: the shield said no, so the brain gloats.
            if coachStep == .tryIt, leftToTry, timing != nil {
                leftToTry = false
                coachReward = "LOCKED!"
                coachStep = .caught
            }
            checkKeyRequests()
            runProofCheck()
            checkReport()
            if let timing, timing.isFinished(at: .now) {
                completeSession()
            } else {
                restrictions.reconcile(activeSessionID: timing == nil ? nil : sessionID)
                LiveCountdown.reconcile(currentRecord, locked: QuitRules.isLocked(sessionID))
            }
        }
    }

    /// Session setup tools are available from the idle header.
    private var topBar: some View {
        HStack(spacing: 0) {
            Text("SwipeLater.")
                .font(AppFont.font(32, .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .tracking(-1.8)
                .foregroundStyle(FocusPaper.ink)
                .accessibilityLabel("SWIPELATER")
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            if !isLocked {
                #if DEBUG
                // TEST MENU, debug builds only (never in TestFlight or the App Store): replays the
                // first-run slides or shows the streak screen.
                Menu {
                    Button("Replay intro") { onboardingDone = false }
                        .accessibilityIdentifier("replay-intro")
                    Button("Show streak") {
                        // Counts today as a finished day so the screen has something to show.
                        StreakStore.record()
                        streakMinutes = 25
                        showStreak = true
                    }
                    .accessibilityIdentifier("show-streak")
                } label: {
                    Text("TEST")
                        .font(Cream.rounded(12, .bold))
                        .tracking(1.5)
                        .foregroundStyle(FocusPaper.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(Capsule().fill(FocusPaper.inset).overlay(Capsule().strokeBorder(FocusPaper.line, lineWidth: 1)))
                }
                .accessibilityIdentifier("test-menu")
                #endif
                roundButton("target", size: 17, label: "Weekly goal") { showGoals = true }
                roundButton("person.2", size: 15, label: "Accountability partner") { showKeys = true }
                roundButton("shield", size: 17, label: "Restrictions") { showRestrictions = true }
            }
        }
    }

    private func roundButton(_ icon: String, size: CGFloat, label: String, action: @escaping () -> Void) -> some View {
        Button { showToolsHint = false; action() } label: {
            Image(systemName: icon)
                .font(.system(size: size))
                .foregroundStyle(FocusPaper.ink)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }

    // MARK: Session transitions

    @ViewBuilder private var focusButton: some View {
        if coachStep == .hold {
            SlideToLockIn(glow: true, identifier: "coach-hold-to-start", action: startCoachedSession)
                .frame(maxWidth: .infinity)
        } else if !isLocked {
            if firstSessionHint && coachStep == nil {
                Text("Start your first 25 minutes?")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(FocusPaper.secondary)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Suggested: start your first 25 minute session now")
            }
            SlideToLockIn(action: startFromButton)
                .frame(maxWidth: .infinity)
        } else {
            Button(action: askToEnd) {
                Text(QuitRules.isLocked(sessionID) ? "GET OUT EARLY" : "END SESSION")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(FocusActionStyle(prominent: false))
            .accessibilityHint("Ends the focus session")
        }
    }

    @ViewBuilder private var coachOverlay: some View {
        if let coachStep {
            VStack(alignment: .leading, spacing: 2) {
                Button { skipCoach() } label: {
                    Text("Skip").font(.headline).frame(minWidth: 44, minHeight: 44)
                }
                .foregroundStyle(FocusPaper.ink)
                .accessibilityIdentifier("skip-focus-coach")
                FocusCoach(step: coachStep, reduceMotion: reduceMotion, pressing: coachPressing, reward: coachReward)
                    .allowsHitTesting(false)
            }
            .transition(.opacity)
        }
    }

    /// The answers for the coach step on screen, under the minutes. Each one does the real thing:
    /// opens the real picker or sheet, or saves the real setting. No step only talks.
    @ViewBuilder private var coachActions: some View {
        switch coachStep {
        case .apps?:
            coachButtons(main: "Choose apps", mainID: "coach-choose-apps", { showRestrictions = true },
                         other: "Skip apps", otherID: "coach-skip-apps") { coachStep = .goal }
        case .goal?:
            CoachGoalChips(choices: [2, 4, 6, 8], current: goals.goal(), pick: pickGoal)
        case .partner?:
            coachButtons(main: "Add a friend", mainID: "coach-add-friend", { showKeys = true },
                         other: "Not now", otherID: "coach-skip-friend") { coachStep = stepAfterPartner }
        case .pc?:
            coachButtons(main: "Connect", mainID: "coach-connect-pc", {
                guard let near = finder.found.first else { coachStep = .hold; return }
                showPC = true
                Task { await pc.pairNearby(near) }
            }, other: "Not now", otherID: "coach-skip-pc") { coachStep = .hold }
        default:
            EmptyView()
        }
    }

    private func coachButtons(main: String, mainID: String, _ mainAction: @escaping () -> Void,
                              other: String, otherID: String, _ otherAction: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Button(main, action: mainAction)
                .buttonStyle(FocusActionStyle(prominent: true))
                .accessibilityIdentifier(mainID)
            Button(other, action: otherAction)
                .buttonStyle(FocusActionStyle(prominent: false))
                .accessibilityIdentifier(otherID)
        }
    }

    private func pickGoal(_ hours: Int) {
        goals.setGoal(hours)
        coachReward = "DEAL!"
        coachStep = .partner
    }

    /// The PC step only shows when a PC is on the same Wi-Fi and not paired yet; otherwise there is
    /// nothing to do there, so the coach goes straight to the start.
    private var stepAfterPartner: FocusCoachStep {
        !pc.isPaired && !finder.found.isEmpty ? .pc : .hold
    }

    /// LOCK IN while the coach is still showing (for example on the apps step) ends the coach
    /// and starts, so a tap is never ignored.
    private func startFromButton() {
        if coachStep != nil { skipCoach() }
        startSession()
    }

    private func skipCoach() {
        coachPending = false
        coachStep = nil
        coachPressing = false
        coachReward = nil
    }

    private func startCoachedSession() {
        guard coachStep == .hold, !isLocked else { return }
        coachPending = false
        coachPressing = false
        coachReward = nil
        coachStep = .celebrate
        startSession()
        celebrateFirstStart()
    }

    /// Slid on the intro's last slide: no coach, the session starts now and the brain cheers.
    private func startFirstSessionFromIntro() {
        guard !isLocked else { return }
        coachPending = false
        coachPressing = false
        coachReward = nil
        coachStep = .celebrate
        startSession()
        celebrateFirstStart()
    }

    /// When the shields are really on, the first start ends with the proof: the brain dares the user
    /// to open a locked app. Without shields (no apps picked, no Screen Time) it just cheers.
    private func celebrateFirstStart() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard coachStep == .celebrate else { return }
            if restrictions.status == .active { coachStep = .tryIt; return }
            try? await Task.sleep(for: .seconds(3))
            if coachStep == .celebrate { coachStep = nil }
        }
    }

    private func updateBrainWatch() {
        let approved: Bool
        switch restrictions.status {
        case .needsAuthorization, .denied: approved = false
        default: approved = true
        }
        BrainWatch.update(selection: restrictions.selection, authorized: approved)
    }

    /// Plus switch under the minutes. Locked needs apps picked, so the delete lock has something
    /// to ride on (it is applied with the shield).
    private var lockedToggle: some View {
        Button {
            if !plus.hasPlus { showPlusOffer = true; return }
            // Locked rides on the shield, so with no apps picked the tap opens the picker instead of doing nothing.
            if !restrictions.hasSelection { showRestrictions = true; return }
            lockedNext.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: lockedNext ? "lock.fill" : "lock.open")
                Text(lockedNext ? "Locked: no quitting" : "Locked mode")
                    .font(.footnote.weight(.medium))
                    // At the largest text sizes on an SE it wraps instead of cutting to "Locke…".
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                if !plus.hasPlus {
                    Text("Plus").font(.caption.weight(.semibold)).padding(.horizontal, 5).padding(.vertical, 2)
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(FocusPaper.line))
                }
            }
            .foregroundStyle(lockedNext ? FocusPaper.ink : FocusPaper.secondary)
            .frame(minHeight: 44)
        }
        .opacity(plus.hasPlus && !restrictions.hasSelection ? 0.55 : 1)
        .accessibilityHint(restrictions.hasSelection ? "No quit button for the next session" : "Opens the app picker first. Locked mode needs apps to lock.")
    }

    /// END SESSION. Free sessions go through the quit screen; Locked ones only have the ways out.
    private func askToEnd() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains(where: { $0.hasPrefix("-ui-testing") }) && !args.contains("-ui-testing-quit-sheet") { endSession(); return }
        #endif
        if QuitRules.isLocked(sessionID) { showLockedExit = true } else { showQuit = true }
    }

    /// Opens the Sunday report once a week, when nothing else is on screen.
    private func checkReport() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-ui-testing") }) { return }
        if DebugShot.name != nil { return }
        #endif
        guard timing == nil, onboardingDone, report == nil, checkIn == nil else { return }
        if let week = goals.pendingReport() {
            report = ReportWeek(id: week)
            return
        }
        // Monday: last week's plan check-in. A week with no plan days in it is skipped quietly.
        guard let plan, let week = PlanStore.pendingCheckIn() else { return }
        let result = PlanWeekResult.make(plan: plan, weekOf: week)
        if result.planned == 0 { PlanStore.markCheckedIn(week: week) } else { checkIn = result }
    }

    /// What the PC gets with a session start: the task (its workspace opens) and the buddy switch.
    private var pcExtras: PCSessionExtras {
        PCSessionExtras(task: tasks.selected, buddy: PCSheet.buddyOn,
                        allow: AllowedApps.list(for: tasks.selected), remindAfterMinutes: PCSheet.remindAfter,
                        locked: lockedNext && plus.hasPlus && restrictions.hasSelection,
                        rcUserId: PlusStore.revenueCatUserID)
    }

    /// "STUDYING · PC: DOCS" or "STUDYING · PC: YOUTUBE · NUDGED 2×".
    private var sessionWorkLine: String? {
        var parts: [String] = []
        if let task = tasks.selected { parts.append(task.uppercased()) }
        if let a = pc.activity {
            if let app = a.app { parts.append("PC: " + app.uppercased()) }
            if a.nudges > 0 { parts.append("NUDGED \(a.nudges)\u{00D7}") }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }

    private var currentRecord: SessionRecord? {
        guard let timing, let sessionID else { return nil }
        return SessionRecord(id: sessionID, timing: timing)
    }

    /// Proof Check. Turning Screen Time access off mid-session drops the shields, so it counts
    /// as an early end (weekly count only) and the user is told right away.
    private func runProofCheck() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-ui-testing") }) { return }
        #endif
        let change = ProofCheck.update(approved: restrictions.isAuthorized)
        guard change != .none else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: BrainLevel.widgetKind)
        if change == .turnedOff, timing != nil {
            Analytics.track("screen_time_turned_off_in_session")
            QuitRules.recordEarlyEnd()
            FocusLog.recordQuit()
            showProofBroken = true
        }
    }

    /// Asks for Screen Time access again and, if given, puts the shields back for the rest of
    /// the session.
    private func turnShieldsBackOn() async -> Bool {
        await restrictions.requestAuthorization()
        guard restrictions.isAuthorized else { return false }
        if let record = currentRecord {
            restrictions.begin(record, locked: QuitRules.isLocked(record.id))
        }
        runProofCheck()
        return true
    }

    /// One sealed update per partner. The PC adds the window title and pause state whenever a PC is
    /// paired and a session runs there. Without a PC, `sharing` is false.
    private func publishPartnerStatus() {
        guard !keys.holders.isEmpty else { return }
        let a = pc.activity
        let shared = a?.sharing == true
        let onBreak = (a?.breakSecondsLeft ?? 0) > 0
        let status = PartnerStatus(
            state: timing == nil ? "free" : (onBreak ? "break" : "locked"),
            endsAt: timing?.endsAt, duration: timing?.duration,
            app: shared ? a?.app : nil, appKey: shared ? a?.appKey : nil, title: shared ? a?.title : nil,
            pausedApp: shared ? a?.pausedApp : nil, pausedSecondsLeft: shared ? a?.pausedSecondsLeft : nil,
            sharing: shared, sentAt: .now)
        Task { await PartnerCloud.publish(status, keys: keys) }
    }

    /// The "This week" row on the PC: this week's minutes per day (Monday first), the goal, the streak
    /// and last week's total. Sent after every session; does nothing without a paired PC.
    private func sendWeekToPC() {
        let now = Date.now
        let cal = FocusLog.calendar
        let week = FocusLog.week(of: now)
        let last = FocusLog.week(of: cal.date(byAdding: .day, value: -7, to: now) ?? now)
        let today = min(max(cal.dateComponents([.day], from: week.start, to: cal.startOfDay(for: now)).day ?? 0, 0), 6)
        pc.sendWeek(PCWeek(
            daySeconds: week.days.map { $0.minutes * 60 },
            goalSeconds: (goals.goal(forWeekOf: now) ?? 0) * 3600,
            streak: StreakStore.current(now: now),
            todaySeconds: week.days[today].minutes * 60,
            todayIndex: today,
            lastWeekSeconds: last.minutes * 60))
    }

    private func checkKeyRequests() {
        guard !keys.friends.isEmpty else { return }
        Task {
            await RemoteKeys.subscribe(for: keys)
            if let pending = try? await RemoteKeys.pending(for: keys), !pending.isEmpty, timing == nil {
                showKeys = true
            }
        }
    }

    private func startSession() {
        firstSessionHint = false
        var duration = TimeInterval(selectedMinutes * 60)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-short-session") {
            duration = 5
        }
        #endif
        let session = SessionTiming(startedAt: .now, duration: duration)
        let record = SessionRecord(timing: session)
        store.save(record)
        let locked = lockedNext && plus.hasPlus && restrictions.hasSelection
        QuitRules.markLocked(locked ? record.id : nil)
        restrictions.begin(record, locked: locked)
        Analytics.track("session_started", ["minutes": selectedMinutes, "locked_mode": locked,
                                            "apps_blocked": restrictions.status == .active,
                                            "first_session": coachStep == .celebrate])
        LiveCountdown.start(record, locked: locked)
        pc.sessionStarted(record, extras: pcExtras)
        flashTask?.cancel()
        flash = nil
        startCount += 1
        withAnimation(stateAnimation) {
            justCompleted = false
            sessionID = record.id
            timing = session
        }
    }

    private static let breakKey = "lockin.pc.breakApplied.v1"

    /// Moves the running session later by a break: same length, later end. Shields, the Lock Screen
    /// countdown and the saved session all follow the new end.
    private func addBreak(seconds: TimeInterval) {
        guard let old = timing, let sessionID, !old.isFinished(at: .now) else { return }
        let moved = SessionTiming(startedAt: old.startedAt.addingTimeInterval(seconds), duration: old.duration)
        let record = SessionRecord(id: sessionID, timing: moved)
        store.save(record)
        let locked = QuitRules.isLocked(sessionID)
        restrictions.begin(record, locked: locked)
        LiveCountdown.start(record, locked: locked)
        withAnimation(stateAnimation) { timing = moved }
    }

    private func endSession() {
        // Time already focused still counts (goals and the weekly report), but not as a finished
        // session, so it does not move the streak.
        let focused = focusedMinutesSoFar
        Analytics.track("session_ended_early", ["minutes_focused": focused,
                                                "minutes_planned": Int(((timing?.duration ?? 0) / 60).rounded())])
        QuitRules.recordEarlyEnd()
        FocusLog.recordQuit(minutes: focused)
        sendWeekToPC()
        QuitRules.markLocked(nil)
        store.clear()
        restrictions.end()
        LiveCountdown.end()
        if let sessionID { pc.sessionEnded(sessionID) }
        endEarlyCount += 1
        showFlash(.endedEarly, seconds: 2.2)
        withAnimation(stateAnimation) {
            sessionID = nil
            timing = nil
        }
    }

    /// Holds a short mood (glow color) after a session ends, then returns to idle.
    private func showFlash(_ mood: FocusMood, seconds: Double) {
        flashTask?.cancel()
        flash = mood
        flashTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            flash = nil
        }
    }

    private func completeSession() {
        guard let session = timing, session.isFinished(at: .now) else { return }
        QuitRules.markLocked(nil)
        store.clear()
        restrictions.end()
        LiveCountdown.end()
        if let sessionID { pc.sessionEnded(sessionID) }
        completionCount += 1
        Analytics.track("session_completed", ["minutes": Int((session.duration / 60).rounded()), "while_closed": false])
        FocusLog.recordFinished(minutes: Int((session.duration / 60).rounded()))
        goals.reschedule()
        let streakBefore = StreakStore.current()
        let firstToday = StreakStore.record()
        let streakAfter = StreakStore.current()
        sendWeekToPC()
        let minutes = Int((session.duration / 60).rounded())
        streakMinutes = minutes
        // The session-done screen rolls the streak itself, so the separate streak screen only
        // comes when that screen is not shown (UI tests that ask for it).
        pendingStreak = firstToday && streakScreenAllowed && !completionCardAllowed
        pendingPlus = plusOfferAllowed
        let info = CompletionInfo(minutes: minutes, task: tasks.selected, nextMinutes: selectedMinutes,
                                  firstEver: !UserDefaults.standard.bool(forKey: "lockin.firstWin.v1"),
                                  nudgeMinute: DailyNudge.isOn ? nil : DailyNudge.suggestedMinute(focusedMinutes: minutes),
                                  streakBefore: streakBefore, streakAfter: streakAfter)
        // Let the finished glow play first.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1800))
            if completionCardAllowed {
                UserDefaults.standard.set(true, forKey: "lockin.firstWin.v1")
                completion = info
            } else {
                advanceAfterSession()
            }
        }
        showFlash(.finished, seconds: 3.2)
        withAnimation(stateAnimation) {
            justCompleted = true
            sessionID = nil
            timing = nil
        }
    }
}

private struct DurationSelector: View {
    let options: [Int]
    @Binding var selection: Int
    var onSelection: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { effectiveReduceMotion(systemReduceMotion) }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var optionFontSize: CGFloat = 15
    @State private var showCustom = false

    /// A length that is not one of the presets (typed here, or from the plan) shows in the last cell.
    private var isCustom: Bool { !options.contains(selection) }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: dynamicTypeSize.isAccessibilitySize ? 3 : options.count + 1), spacing: 4) {
            ForEach(options, id: \.self) { minutes in
                let selected = minutes == selection
                Button {
                    selection = minutes
                    onSelection()
                } label: {
                    Text("\(minutes)")
                        .font(Cream.rounded(optionFontSize, selected ? .bold : .medium).monospacedDigit())
                        .foregroundStyle(selected ? FocusPaper.page : FocusPaper.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 13, style: .continuous).fill(FocusPaper.ink)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(minutes) minutes")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            Button { showCustom = true } label: {
                Group {
                    if isCustom {
                        Text("\(selection)")
                            .font(Cream.rounded(optionFontSize, .bold).monospacedDigit())
                    } else {
                        Image(systemName: "pencil")
                            .font(.system(size: optionFontSize, weight: .semibold))
                    }
                }
                .foregroundStyle(isCustom ? FocusPaper.page : FocusPaper.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background {
                    if isCustom {
                        RoundedRectangle(cornerRadius: 13, style: .continuous).fill(FocusPaper.ink)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCustom ? "\(selection) minutes, custom. Change" : "Custom minutes")
            .accessibilityAddTraits(isCustom ? .isSelected : [])
            .accessibilityIdentifier("custom-minutes")
        }
        .sheet(isPresented: $showCustom) {
            CustomMinutesSheet(current: selection) { minutes in
                selection = minutes
                showCustom = false
                onSelection()
            } close: {
                showCustom = false
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 17, style: .continuous).fill(FocusPaper.inset))
        .animation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 1), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

private struct FocusActionStyle: ButtonStyle {
    let prominent: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let plate = RoundedRectangle(cornerRadius: 17, style: .continuous)
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(prominent ? FocusPaper.page : FocusPaper.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(plate.fill(prominent ? FocusPaper.ink : FocusPaper.page))
            .overlay(plate.strokeBorder(prominent ? .clear : FocusPaper.line))
            .contentShape(plate)
            .opacity(configuration.isPressed ? 0.83 : 1)
            .scaleEffect(configuration.isPressed && !motionLimited(reduceMotion) ? 0.985 : 1)
            .animation(motionLimited(reduceMotion) ? nil : .spring(response: 0.30, dampingFraction: 1),
                       value: configuration.isPressed)
    }
}

#Preview("Idle") { FocusView() }
