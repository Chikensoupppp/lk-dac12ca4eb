import SwiftUI
import WidgetKit

/// Focus screen. `timing` is the single source of truth for the session:
/// nil means idle, non-nil means a session is running until `timing.endsAt`.
/// The clock, labels and completion all derive from it.
struct FocusView: View {
    private static let durationOptions = [15, 25, 45, 60, 90]

    private let store: SessionStoring

    @State private var selectedMinutes = 45
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
    @StateObject private var tasks = WorkTaskStore()
    @State private var showTasks = false
    /// Right after the intro (promise signed): 25 minutes are picked and a note suggests starting
    /// now. Nothing starts until the user taps LOCK IN.
    @State private var firstSessionHint = false
    /// Proof Check: Screen Time access was turned off during this session.
    @State private var showProofBroken = false
    @StateObject private var goals = GoalStore()
    @State private var showGoals = false
    /// The Sunday report, opened by itself once a week.
    @State private var report: ReportWeek?
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
    private var motion: Bool { !motionLimited(systemReduceMotion) }
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(store: SessionStoring = UserDefaultsSessionStore()) {
        self.store = store
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset-state") { store.clear() }
        #endif
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
            case "restrictions": showRestrictions = true
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
            FocusBackdrop(timing: timing, flash: flash)

            GeometryReader { geo in
                let side = max(min(geo.size.width - 48, geo.size.height * (dynamicTypeSize.isAccessibilitySize ? 0.3 : (geo.size.height < 700 ? 0.36 : 0.45))), 140)

                VStack(spacing: 0) {
                    // Its own row, so the buttons can never sit on the title. Hidden (but still
                    // taking its space) during a session, so nothing jumps.
                    topBar
                        .opacity(isLocked ? 0 : 1)
                        .allowsHitTesting(!isLocked)
                        .accessibilityHidden(isLocked)
                        .padding(.top, 4)

                    Text("LOCK IN")
                        .font(Cream.rounded(13, .bold))
                        .tracking(4)
                        .foregroundStyle(Matte.textSoft)
                        .padding(.top, 6)

                    PCStatusLine(pc: pc, isLocked: isLocked) { showPC = true }

                    // In a session: the task, and what the PC sees (front app, buddy nudges).
                    if isLocked, let line = sessionWorkLine {
                        Text(line)
                            .font(Cream.rounded(12, .medium))
                            .foregroundStyle(pc.activity?.onTask == false ? Color(hex: 0xC2410C) : Matte.textSoft)
                            .lineLimit(1)
                            .padding(.top, 4)
                            .accessibilityIdentifier("pc-activity")
                    }

                    if isLocked, let line = restrictions.statusLine {
                        Text(line)
                            .font(Cream.rounded(12, .medium))
                            .foregroundStyle(Matte.textSoft)
                            .padding(.top, 4)
                            .accessibilityIdentifier("restrictions-line")
                    }

                    Spacer(minLength: 16)

                    CountdownClockView(
                        duration: TimeInterval(selectedMinutes * 60),
                        timing: timing,
                        caption: clockCaption,
                        idleFraction: flash == .finished ? 1 : Double(selectedMinutes) / 90,
                        flash: flash,
                        sweepTrigger: completionCount
                    )
                    .frame(width: side, height: side)

                    Spacer(minLength: 16)

                    VStack(spacing: 10) {
                        WorkTaskPill(tasks: tasks) { showTasks = true }
                        Text("MINUTES")
                            .font(Cream.rounded(11, .semibold))
                            .tracking(3)
                            .foregroundStyle(Matte.textSoft)
                        DurationSelector(options: Self.durationOptions, selection: $selectedMinutes)
                        lockedToggle
                    }
                    .opacity(isLocked ? 0 : 1)
                    .allowsHitTesting(!isLocked)
                    .accessibilityHidden(isLocked)
                    .padding(.bottom, 24)

                    Button(action: isLocked ? askToEnd : startSession) {
                        Text(isLocked ? (QuitRules.isLocked(sessionID) ? "GET OUT EARLY" : "END SESSION") : "LOCK IN")
                    }
                    .buttonStyle(MatteButtonStyle(prominent: !isLocked))
                    .overlay { LatchEffect(trigger: startCount, enabled: motion) }
                    .accessibilityHint(isLocked ? "Ends the focus session" : "Starts a focus session")
                    .overlay(alignment: .top) {
                        if firstSessionHint && !isLocked {
                            Text("YOUR FIRST 25 MINUTES \u{00B7} START NOW?")
                                .font(Cream.rounded(11, .bold))
                                .tracking(1.5)
                                .foregroundStyle(Color(hex: 0xF3F4F0))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Matte.text))
                                .offset(y: -26)
                                .transition(.opacity)
                                .accessibilityLabel("Suggested: start your first 25 minute session now")
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showRestrictions) { RestrictionsSheet(restrictions: restrictions) }
        .sheet(isPresented: $showPC) { PCSheet(pc: pc) }
        .sheet(isPresented: $showTasks) { WorkTaskSheet(tasks: tasks) { showTasks = false } }
        .sheet(isPresented: $showGoals) { GoalSheet(goals: goals) { showGoals = false } }
        .sheet(item: $report) { r in WeekReportView(goals: goals, weekStart: r.id) { report = nil } }
        .sheet(isPresented: $showKeys) { KeysSheet(keys: keys) { showKeys = false } }
        .sheet(isPresented: $showPlusOffer) { PlusOfferStep(plus: plus, intro: false) { showPlusOffer = false } }
        .fullScreenCover(isPresented: $showQuit) {
            QuitSheet(onQuit: { showQuit = false; endSession() }, onStay: { showQuit = false })
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
        .fullScreenCover(isPresented: Binding(get: { !onboardingDone }, set: { if !$0 { onboardingDone = true } })) {
            OnboardingFlow(restrictions: restrictions, plus: plus) { startNow in
                onboardingDone = true
                if startNow {
                    selectedMinutes = 25
                    firstSessionHint = true
                }
            }
        }
        .fullScreenCover(isPresented: $showStreak) {
            StreakView(minutes: streakMinutes) { showStreak = false }
        }
        .overlay(alignment: .topLeading) {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-ui-testing-completion-count") {
                Text("Completion count: \(completionCount)")
                    .accessibilityIdentifier("completion-count")
            }
            #endif
        }
        .preferredColorScheme(.light)
        // The brain widget watches the apps picked to lock; keep that watch in step.
        .onChange(of: restrictions.selection) { _, _ in updateBrainWatch() }
        .onChange(of: restrictions.status) { _, _ in updateBrainWatch(); runProofCheck() }
        .onAppear {
            updateBrainWatch()
            runProofCheck()
            checkKeyRequests()
            if expiredOnLaunch {
                expiredOnLaunch = false
                store.clear()
                // The session ended while the app was closed. It counts for the streak,
                // The streak screen is not shown for it.
                StreakStore.record()
                FocusLog.recordFinished(minutes: expiredMinutes)
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
            guard phase == .active else { return }
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

    /// Top row: the test menu on the left, goal / keys / restrictions on the right.
    private var topBar: some View {
        HStack(spacing: 8) {
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
                    .foregroundStyle(Matte.textQuiet)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Capsule().fill(Matte.tray).overlay(Capsule().strokeBorder(Matte.edge, lineWidth: 1)))
            }
            .accessibilityIdentifier("test-menu")
            #endif
            Spacer(minLength: 8)
            roundButton("target", size: 17, label: "Weekly goal") { showGoals = true }
            roundButton("key.fill", size: 16, label: "Keys") { showKeys = true }
            roundButton("shield.lefthalf.filled", size: 17, label: "Restrictions") { showRestrictions = true }
        }
    }

    private func roundButton(_ icon: String, size: CGFloat, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size))
                .foregroundStyle(Matte.textQuiet)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Matte.tray).overlay(Circle().strokeBorder(Matte.edge, lineWidth: 1)))
        }
        .accessibilityLabel(label)
    }

    // MARK: Session transitions

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
            lockedNext.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: lockedNext ? "lock.fill" : "lock.open")
                Text(lockedNext ? "LOCKED: NO QUITTING" : "LOCKED MODE")
                    .font(Cream.rounded(12, .bold)).tracking(1.5)
                if !plus.hasPlus {
                    Text("PLUS").font(Cream.rounded(10, .heavy)).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Matte.edge))
                }
            }
            .foregroundStyle(lockedNext ? Matte.riso : Matte.textSoft)
            .frame(minHeight: 44)
        }
        .disabled(plus.hasPlus && !restrictions.hasSelection)
        .opacity(plus.hasPlus && !restrictions.hasSelection ? 0.4 : 1)
        .accessibilityHint(restrictions.hasSelection ? "No quit button for the next session" : "Pick apps to lock first")
    }

    /// END SESSION. Free sessions go through the quit screen; Locked ones only have the ways out.
    private func askToEnd() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-ui-testing") }) { endSession(); return }
        #endif
        if QuitRules.isLocked(sessionID) { showLockedExit = true } else { showQuit = true }
    }

    /// Opens the Sunday report once a week, when nothing else is on screen.
    private func checkReport() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-ui-testing") }) { return }
        if DebugShot.name != nil { return }
        #endif
        guard timing == nil, onboardingDone, report == nil, let week = goals.pendingReport() else { return }
        report = ReportWeek(id: week)
    }

    /// What the PC gets with a session start: the task (its workspace opens) and the buddy switch.
    private var pcExtras: PCSessionExtras {
        PCSessionExtras(task: tasks.selected, buddy: PCSheet.buddyOn)
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
    /// as a quit (weekly count + brain scar) and the user is told right away.
    private func runProofCheck() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-ui-testing") }) { return }
        #endif
        let change = ProofCheck.update(approved: restrictions.isAuthorized)
        guard change != .none else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: BrainLevel.widgetKind)
        if change == .turnedOff, timing != nil {
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

    private func endSession() {
        QuitRules.recordEarlyEnd()
        FocusLog.recordQuit()
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
        FocusLog.recordFinished(minutes: Int((session.duration / 60).rounded()))
        goals.reschedule()
        let firstToday = StreakStore.record()
        if firstToday && streakScreenAllowed {
            streakMinutes = Int((session.duration / 60).rounded())
            // Let the finished glow play first.
            Task {
                try? await Task.sleep(for: .milliseconds(1800))
                showStreak = true
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
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { effectiveReduceMotion(systemReduceMotion) }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var optionFontSize: CGFloat = 15

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: dynamicTypeSize.isAccessibilitySize ? 3 : options.count), spacing: 4) {
            ForEach(options, id: \.self) { minutes in
                let selected = minutes == selection
                Button {
                    selection = minutes
                } label: {
                    Text("\(minutes)")
                        .font(Cream.rounded(optionFontSize, selected ? .bold : .medium).monospacedDigit())
                        .foregroundStyle(selected ? Color.white : Matte.textDim)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .fill(LinearGradient(colors: [Matte.chipHigh, Matte.chipLow], startPoint: .top, endPoint: .bottom))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                                            .strokeBorder(Color.black.opacity(0.1), lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
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
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Matte.tray)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Matte.edge, lineWidth: 1)
                )
        )
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

#Preview("Idle") { FocusView() }
