import SwiftUI

/// "When works for you?", right after the goals (and again from the plan's "Change time"). No time
/// is set for the user: they pick it, with quick picks and +/-. No calendar (removed 2026-11-20).

/// The time and what happens then, chosen on that screen.
struct TimeChoice: Equatable {
    var startMinute: Int
    var weekdays: Set<Int>
    var dayStarts: [Int: Int]?
    var schedule: LockInSchedule
}

private enum WhenInk {
    static let soft = Color(hex: 0x45473F)
    static let sheet = Color(hex: 0xF4F4F0)
    static let letters = [1: "S", 2: "M", 3: "T", 4: "W", 5: "T", 6: "F", 7: "S"]
    static let full = [1: "Sunday", 2: "Monday", 3: "Tuesday", 4: "Wednesday", 5: "Thursday", 6: "Friday", 7: "Saturday"]
    /// Monday first.
    static let order = [2, 3, 4, 5, 6, 7, 1]
}

/// "5:30" (no AM/PM), for tight places.
private func clock(_ minute: Int) -> String {
    let h = (minute / 60) % 12 == 0 ? 12 : (minute / 60) % 12
    return "\(h):\(String(format: "%02d", minute % 60))"
}

private func ampm(_ minute: Int) -> String { minute < 12 * 60 ? "AM" : "PM" }

struct PlusBadge: View {
    var body: some View {
        Text("PLUS")
            .font(PrintFont.mono(10, .bold)).tracking(1)
            .foregroundStyle(Ink.ink)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(Ink.sun))
            .overlay(Capsule().strokeBorder(Ink.ink, lineWidth: 2))
            .accessibilityLabel("Plus")
    }
}

/// "Remind me" (free) or "Lock by itself" (Plus), picked in the schedule sheet (`ScheduleSheet`).
struct ThenCards: View {
    @Binding var then: LockInSchedule.Then
    let minute: Int
    var perDay = false

    var body: some View {
        let at = perDay ? "your time" : clock(minute)
        HStack(spacing: 12) {
            card(.remind, icon: "bell.fill", title: "Remind me", line: "A nudge at \(at). You start it.", plus: false)
            card(.autoLock, icon: "lock.fill", title: "Lock by itself", line: "Your apps lock at \(at), every week.", plus: true)
        }
        .padding(.top, 2)
    }

    private func card(_ value: LockInSchedule.Then, icon: String, title: String, line: String, plus: Bool) -> some View {
        let on = then == value
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { then = value } } label: {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Ink.ink)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(on ? Color.white : Ink.sun))
                    .overlay(Circle().strokeBorder(Ink.ink, lineWidth: 2))
                Text(title).font(PrintFont.bold(17)).padding(.top, 8)
                Text(line).font(PrintFont.body(12.5, .medium)).opacity(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(on ? Color.white : Ink.ink)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .background(shape.fill(on ? Ink.blue : Color.white))
            .overlay(shape.strokeBorder(on ? Ink.ink : Ink.ink.opacity(0.18), lineWidth: 2))
            .background(shape.fill(Ink.ink).offset(y: on ? 5 : 0))
            .overlay(alignment: .topTrailing) { if plus { PlusBadge().offset(x: -10, y: -11) } }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}

/// The same two ways on the intro's time slide, shown, not picked (Brandon, 2026-11-20: "not
/// clickable, just to show"; the paywall comes at the end). Free users get the nudge; having Plus at
/// the end turns on the auto lock (`OnboardingFlow.finish`).
struct ThenInfoCards: View {
    let minute: Int
    var perDay = false

    var body: some View {
        let at = perDay ? "your time" : clock(minute)
        HStack(alignment: .top, spacing: 12) {
            card(icon: "bell.fill", title: "Remind me", line: "A nudge at \(at). You start it.", plus: false)
            card(icon: "lock.fill", title: "Lock by itself", line: "Your apps lock at \(at) on their own.", plus: true)
        }
        .padding(.top, 2)
    }

    private func card(icon: String, title: String, line: String, plus: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(plus ? Ink.ink : Color.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(plus ? Ink.sun : Ink.blue))
                Spacer(minLength: 4)
                if plus { PlusBadge() } else { FreeBadge() }
            }
            Text(title).font(PrintFont.bold(17)).padding(.top, 8)
            Text(line).font(PrintFont.body(12.5, .medium)).opacity(0.8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Ink.ink)
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .background(shape.fill(Color.white.opacity(0.75)))
        .overlay(shape.strokeBorder(Ink.ink.opacity(0.14), lineWidth: 1.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(plus ? "with Plus" : "free"). \(line)")
    }
}

/// The free counterpart of `PlusBadge`.
struct FreeBadge: View {
    var body: some View {
        Text("FREE")
            .font(PrintFont.mono(10, .bold)).tracking(1)
            .foregroundStyle(Ink.ink)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .overlay(Capsule().strokeBorder(Ink.ink, lineWidth: 2))
            .accessibilityLabel("Free")
    }
}

// MARK: When works for you?

struct WhenPickStep: View {
    let plan: LockInPlan
    let done: (TimeChoice) -> Void

    /// Nothing until the user picks: no time is chosen for them.
    @State private var picked: Int?
    @State private var weekdays: Set<Int>

    init(plan: LockInPlan, done: @escaping (TimeChoice) -> Void) {
        self.plan = plan
        self.done = done
        _weekdays = State(initialValue: plan.weekdays)
    }

    /// The picked time; before a pick it shows (faded) and +/- start from 9 AM (Brandon, 2026-11-20).
    private var minute: Int { picked ?? 9 * 60 }

    /// One tap to a starting point, then +/- for the exact time.
    private static let quick: [(minute: Int, label: String)] = [
        (9 * 60, "9 AM"), (12 * 60, "12 PM"), (16 * 60, "4 PM"), (19 * 60, "7 PM"), (21 * 60, "9 PM")
    ]

    var body: some View {
        PrintScaffold(step: 12, tag: "Your time", title: "When works\nfor you?", titleSize: 48,
                      primaryTitle: picked == nil ? "PICK A TIME" : "SET \(clock(minute)) \(ampm(minute))",
                      primaryEnabled: picked != nil && !weekdays.isEmpty,
                      primaryAction: confirm) {
            VStack(alignment: .leading, spacing: 18) {
                bigTime
                quickRow
                dayStamps
                if picked != nil {
                    Text("AND THEN?").font(PrintFont.mono(11, .bold)).tracking(1.4).foregroundStyle(WhenInk.soft)
                    ThenInfoCards(minute: minute)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: picked == nil)
        }
    }

    private var bigTime: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return HStack {
            step("minus", by: -15)
            Spacer(minLength: 4)
            // Before a pick: the 9 AM starting point, faded. (A "--:--" placeholder here drew as a row
            // of little blocks in this compressed face.)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(clock(minute)).font(PrintFont.head(64)).monospacedDigit()
                    .contentTransition(.numericText(value: Double(minute)))
                Text(ampm(minute)).font(PrintFont.head(26))
            }
            .foregroundStyle(Ink.ink)
            .opacity(picked == nil ? 0.3 : 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(picked == nil ? "No time picked yet. Starts from 9:00 AM" : DailyNudge.timeText(minute: minute))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: shift(15)
                case .decrement: shift(-15)
                @unknown default: break
                }
            }
            Spacer(minLength: 4)
            step("plus", by: 15)
        }
        .padding(.horizontal, 14)
        .frame(height: 108)
        .background(shape.fill(WhenInk.sheet))
        .overlay(shape.strokeBorder(Ink.ink, lineWidth: 2))
        .background(shape.fill(Ink.ink).offset(y: 5))
    }

    private func step(_ icon: String, by delta: Int) -> some View {
        RepeatStepButton(icon: icon, label: delta > 0 ? "Later" : "Earlier") { shift(delta) }
            .sensoryFeedback(.selection, trigger: minute)
    }

    private func shift(_ delta: Int) {
        // The first +/- picks the starting time itself; after that it moves it.
        let next = picked == nil ? minute : minute + delta
        withAnimation(.snappy(duration: 0.2)) { picked = min(max(next, 5 * 60), 23 * 60) }
    }

    private var quickRow: some View {
        HStack(spacing: 6) {
            ForEach(Self.quick, id: \.minute) { q in
                let on = picked == q.minute
                Button {
                    withAnimation(.snappy(duration: 0.2)) { picked = q.minute }
                } label: {
                    Text(q.label)
                        .font(PrintFont.bold(16))
                        .foregroundStyle(on ? Color.white : Ink.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule().fill(on ? Ink.blue : Color.white))
                        .overlay(Capsule().strokeBorder(Ink.ink, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: on)
                .accessibilityIdentifier("when-time-\(q.minute)")
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private var dayStamps: some View {
        HStack(spacing: 0) {
            ForEach(WhenInk.order, id: \.self) { d in
                let on = weekdays.contains(d)
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        if on { weekdays.remove(d) } else { weekdays.insert(d) }
                    }
                } label: {
                    Text(WhenInk.letters[d] ?? "")
                        .font(PrintFont.mono(13, .bold))
                        .foregroundStyle(on ? Color.white : Ink.ink)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(on ? Ink.blue : Color.white))
                        .overlay(Circle().strokeBorder(Ink.ink, lineWidth: 2))
                        .rotationEffect(.degrees(on ? -6 : 0))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(WhenInk.full[d] ?? "")
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func confirm() {
        // A reminder for now; `OnboardingFlow.finish` makes it the auto lock if Plus was bought at the end.
        done(TimeChoice(startMinute: minute, weekdays: weekdays, dayStarts: nil,
                        schedule: LockInSchedule(then: .remind)))
    }
}

/// A round +/- button that keeps going while held: one step on touch, then after 0.4 s it repeats,
/// faster and faster (170 ms down to 45 ms between steps), until the finger lifts. So 9 AM to
/// 9 PM is a short hold, not 48 taps (Brandon, 2026-11-20).
private struct RepeatStepButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var pressed = false
    @State private var repeater: Task<Void, Never>?

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 20, weight: .heavy))
            .foregroundStyle(Ink.ink)
            .frame(width: 48, height: 48)
            .background(Circle().fill(Color.white))
            .overlay(Circle().strokeBorder(Ink.ink, lineWidth: 2))
            .scaleEffect(pressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: pressed)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !pressed else { return }
                        pressed = true
                        action()
                        repeater = Task { @MainActor in
                            do {
                                try await Task.sleep(for: .milliseconds(400))
                                var gap = 170.0
                                while !Task.isCancelled {
                                    action()
                                    try await Task.sleep(for: .milliseconds(Int(gap)))
                                    gap = max(gap * 0.86, 45)
                                }
                            } catch {}
                        }
                    }
                    .onEnded { _ in stop() }
            )
            .onDisappear(perform: stop)
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
    }

    private func stop() {
        pressed = false
        repeater?.cancel()
        repeater = nil
    }
}
