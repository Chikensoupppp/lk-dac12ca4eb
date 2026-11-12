import SwiftUI

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
        case .expired:
            hadSession = true
            _justCompleted = State(initialValue: true)
            _completionCount = State(initialValue: 1)
            _expiredOnLaunch = State(initialValue: true)
        }
        _onboardingDone = State(initialValue: OnboardingStore.isDone() || hadSession)
    }

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
                let side = max(min(geo.size.width - 48, geo.size.height * (dynamicTypeSize.isAccessibilitySize ? 0.32 : 0.5)), 140)

                VStack(spacing: 0) {
                    Text("LOCK IN")
                        .font(Cream.rounded(13, .bold))
                        .tracking(4)
                        .foregroundStyle(Matte.textSoft)
                        .padding(.top, 12)

                    PCStatusLine(pc: pc, isLocked: isLocked) { showPC = true }

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
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay(alignment: .topTrailing) {
            if !isLocked {
                HStack(spacing: 8) {
                    Button { showKeys = true } label: {
                        Image(systemName: "key.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Matte.textQuiet)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Matte.tray).overlay(Circle().strokeBorder(Matte.edge, lineWidth: 1)))
                    }
                    .accessibilityLabel("Keys")
                    Button { showRestrictions = true } label: {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 17))
                            .foregroundStyle(Matte.textQuiet)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Matte.tray).overlay(Circle().strokeBorder(Matte.edge, lineWidth: 1)))
                    }
                    .accessibilityLabel("Restrictions")
                }
                .padding(.trailing, 8)
            }
        }
        // TEST BUTTON: replays the first-run slides. Remove before a public release.
        .overlay(alignment: .topLeading) {
            if !isLocked {
                HStack(spacing: 8) {
                    testButton("Replay intro", id: "replay-intro") { onboardingDone = false }
                    testButton("Show streak", id: "show-streak") {
                        // Counts today as a finished day so the screen has something to show.
                        StreakStore.record()
                        streakMinutes = 25
                        showStreak = true
                    }
                }
                .padding(.leading, 8)
            }
        }
        .sheet(isPresented: $showRestrictions) { RestrictionsSheet(restrictions: restrictions) }
        .sheet(isPresented: $showPC) { PCSheet(pc: pc) }
        .sheet(isPresented: $showKeys) { KeysSheet(keys: keys) { showKeys = false } }
        .sheet(isPresented: $showPlusOffer) { PlusOfferStep(plus: plus) { showPlusOffer = false } }
        .fullScreenCover(isPresented: $showQuit) {
            QuitSheet(onQuit: { showQuit = false; endSession() }, onStay: { showQuit = false })
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
                    startSession()
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
        .preferredColorScheme(.dark)
        // The brain widget watches the apps picked to lock; keep that watch in step.
        .onChange(of: restrictions.selection) { _, _ in updateBrainWatch() }
        .onChange(of: restrictions.status) { _, _ in updateBrainWatch() }
        .onAppear {
            updateBrainWatch()
            checkKeyRequests()
            if expiredOnLaunch {
                expiredOnLaunch = false
                store.clear()
                // The session ended while the app was closed. It counts for the streak,
                // but the length is unknown here, so the streak screen is not shown.
                StreakStore.record()
            }
            // Repairs shields left by a terminated run (expired, cancelled, or revoked).
            restrictions.reconcile(activeSessionID: timing == nil ? nil : sessionID)
            // A session restored after a relaunch tells the PC again. The PC ignores repeats.
            if let timing, let sessionID { pc.sessionStarted(SessionRecord(id: sessionID, timing: timing)) }
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
            if let timing, timing.isFinished(at: .now) {
                completeSession()
            } else {
                restrictions.reconcile(activeSessionID: timing == nil ? nil : sessionID)
            }
        }
    }

    /// TEST BUTTON style. Remove with the buttons before a public release.
    private func testButton(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Cream.rounded(13, .semibold))
                .foregroundStyle(Matte.textQuiet)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Capsule().fill(Matte.tray).overlay(Capsule().strokeBorder(Matte.edge, lineWidth: 1)))
        }
        .accessibilityIdentifier(id)
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
            .foregroundStyle(lockedNext ? Color(hex: 0xFF4A1C) : Matte.textSoft)
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
        pc.sessionStarted(record)
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
        QuitRules.markLocked(nil)
        store.clear()
        restrictions.end()
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
        if let sessionID { pc.sessionEnded(sessionID) }
        completionCount += 1
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
                                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.6), radius: 5, x: 0, y: 3)
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
                        .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

#Preview("Idle") { FocusView() }
