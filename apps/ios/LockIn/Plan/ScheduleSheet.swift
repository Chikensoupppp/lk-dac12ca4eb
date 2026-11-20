import SwiftUI

/// "Your schedule" under today's plan on the Focus screen: what happens at the plan's time, and a
/// Change button. Shown once a schedule was set ("When works for you?" in the intro, or here).
struct ScheduleLine: View {
    let plan: LockInPlan
    let schedule: LockInSchedule?
    let change: () -> Void

    private var label: String {
        let starts = Set(plan.weekdays.map { plan.startMinute(weekday: $0) })
        let time = starts.count > 1 ? "fitted to each day" : DailyNudge.timeText(minute: plan.startMinute)
        switch schedule?.then {
        case .autoLock: return "Auto-lock \u{00B7} \(time)"
        case .remind: return "Reminder \u{00B7} \(time)"
        case nil: return "No reminder"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: schedule?.then == .autoLock ? "lock.fill" : (schedule == nil ? "bell.slash" : "bell.fill"))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(FocusPaper.ink)
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FocusPaper.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            Button(action: change) {
                Text(schedule == nil ? "Set" : "Change")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(FocusPaper.ink)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 34)
                    .background(Capsule().strokeBorder(FocusPaper.ink, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("schedule-change")
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

/// Change the plan's time, its days, and what happens then, after the intro. "Lock by itself" is
/// Plus; without Plus it opens the offer. "Turn off" removes the reminders and the auto-lock.
struct ScheduleSheet: View {
    @ObservedObject var plus: PlusStore
    @ObservedObject var restrictions: RestrictionController
    let saved: (LockInPlan) -> Void
    let close: () -> Void

    private let plan: LockInPlan
    @State private var minute: Int
    @State private var weekdays: Set<Int>
    @State private var then: LockInSchedule.Then
    @State private var showOffer = false

    private static let order = [2, 3, 4, 5, 6, 7, 1]
    private static let letters = [1: "S", 2: "M", 3: "T", 4: "W", 5: "T", 6: "F", 7: "S"]
    private static let names = [1: "Sunday", 2: "Monday", 3: "Tuesday", 4: "Wednesday", 5: "Thursday", 6: "Friday", 7: "Saturday"]

    init(plan: LockInPlan, plus: PlusStore, restrictions: RestrictionController,
         saved: @escaping (LockInPlan) -> Void, close: @escaping () -> Void) {
        self.plan = plan
        self.plus = plus
        self.restrictions = restrictions
        self.saved = saved
        self.close = close
        let schedule = LockInSchedule.load()
        _minute = State(initialValue: plan.startMinute)
        _weekdays = State(initialValue: plan.weekdays)
        _then = State(initialValue: schedule?.then ?? .remind)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("YOUR SCHEDULE")
                        .font(PrintFont.mono(11, .bold)).tracking(1.4)
                        .foregroundStyle(Ink.blue)
                    Spacer()
                    Button("Done", action: close)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Ink.ink)
                        .frame(minHeight: 44)
                }
                Text("WHEN DO YOU\nLOCK IN?")
                    .font(PrintFont.head(44))
                    .lineSpacing(-5)
                    .foregroundStyle(Ink.ink)
                    .accessibilityAddTraits(.isHeader)
                timeRow
                dayRow
                Text("AND THEN?").font(PrintFont.mono(11, .bold)).tracking(1.4).foregroundStyle(Ink.soft)
                ThenCards(then: Binding(get: { then }, set: { new in
                    if new == .autoLock && !plus.hasPlus { showOffer = true } else { then = new }
                }), minute: minute)
                Button(action: save) { Text("SAVE") }
                    .buttonStyle(PrintButtonStyle())
                    .disabled(weekdays.isEmpty)
                    .opacity(weekdays.isEmpty ? 0.35 : 1)
                    .padding(.top, 4)
                Button(role: .destructive, action: turnOff) {
                    Text("Turn off reminders and auto-lock")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .foregroundStyle(Ink.red)
            }
            .padding(24)
        }
        .background(Ink.paper.ignoresSafeArea())
        .preferredColorScheme(.light)
        .sheet(isPresented: $showOffer) { PlusOfferStep(plus: plus, intro: false) { showOffer = false } }
        .onChange(of: plus.hasPlus) { _, has in if has { then = .autoLock } }
    }

    private var timeRow: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return HStack {
            stepButton("minus", -15)
            Spacer(minLength: 4)
            Text(DailyNudge.timeText(minute: minute))
                .font(PrintFont.head(52))
                .monospacedDigit()
                .foregroundStyle(Ink.ink)
                .contentTransition(.numericText(value: Double(minute)))
                .accessibilityAdjustableAction { d in
                    switch d {
                    case .increment: shift(15)
                    case .decrement: shift(-15)
                    @unknown default: break
                    }
                }
            Spacer(minLength: 4)
            stepButton("plus", 15)
        }
        .padding(.horizontal, 14)
        .frame(height: 96)
        .background(shape.fill(Color(hex: 0xF4F4F0)))
        .overlay(shape.strokeBorder(Ink.ink, lineWidth: 2))
        .background(shape.fill(Ink.ink).offset(y: 5))
    }

    private func stepButton(_ icon: String, _ delta: Int) -> some View {
        Button { shift(delta) } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Ink.ink)
                .frame(width: 46, height: 46)
                .background(Circle().fill(Color.white))
                .overlay(Circle().strokeBorder(Ink.ink, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(delta > 0 ? "Later" : "Earlier")
    }

    private func shift(_ delta: Int) {
        withAnimation(.snappy(duration: 0.2)) { minute = min(max(minute + delta, 5 * 60), 23 * 60) }
    }

    private var dayRow: some View {
        HStack(spacing: 0) {
            ForEach(Self.order, id: \.self) { d in
                let on = weekdays.contains(d)
                Button {
                    if on { weekdays.remove(d) } else { weekdays.insert(d) }
                } label: {
                    Text(Self.letters[d] ?? "")
                        .font(PrintFont.mono(13, .bold))
                        .foregroundStyle(on ? Color.white : Ink.ink)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(on ? Ink.blue : Color.white))
                        .overlay(Circle().strokeBorder(Ink.ink, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(Self.names[d] ?? "")
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func save() {
        var p = plan
        p.startMinute = minute
        p.weekdays = weekdays
        p.dayStarts = nil
        PlanStore.save(p)
        let schedule = LockInSchedule(then: then == .autoLock && plus.hasPlus ? .autoLock : .remind)
        schedule.save()
        let hasPlus = plus.hasPlus
        Task { @MainActor in
            await ScheduleApplier.apply(plan: p, schedule: schedule, hasPlus: hasPlus, restrictions: restrictions)
        }
        saved(p)
        close()
    }

    private func turnOff() {
        PlanReminders.turnOff()
        AutoLockScheduler.turnOff()
        UserDefaults.standard.removeObject(forKey: LockInSchedule.key)
        saved(plan)
        close()
    }
}
