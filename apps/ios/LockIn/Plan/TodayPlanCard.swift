import SwiftUI

/// "Today's plan" on the Focus screen, when idle: today's lock-ins (done ones get a blue check,
/// the next one is outlined), this week's plan days, and the minutes won back today.
/// Mock: docs/design/personal-plan.html, screen 4.
struct TodayPlanCard: View {
    let plan: LockInPlan
    let progress: PlanProgress
    var compact = false

    private let cal = FocusLog.calendar

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("TODAY\u{2019}S PLAN")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(2)
                if let today = progress.today {
                    Spacer()
                    Text("\(today.done) OF \(today.planned) DONE")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
            }
            .foregroundStyle(FocusPaper.secondary)

            if let today = progress.today {
                HStack(spacing: 8) {
                    ForEach(Array(plan.slots(on: .now).enumerated()), id: \.offset) { i, slot in
                        chip(slot, done: i < today.done, next: i == today.done)
                    }
                    Spacer(minLength: 0)
                }
            } else {
                Text("Rest day. Lock in anytime.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(FocusPaper.secondary)
            }

            if !compact {
                HStack(alignment: .bottom) {
                    weekDots
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Won back today")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(FocusPaper.secondary)
                        Text(FocusLog.format(minutes: progress.minutesToday))
                            .font(AppFont.font(22, .heavy))
                            .foregroundStyle(FocusPaper.amber)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
        .shadow(color: FocusPaper.ink.opacity(0.08), radius: 12, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityIdentifier("today-plan")
    }

    private func chip(_ time: Date, done: Bool, next: Bool) -> some View {
        HStack(spacing: 6) {
            ZStack {
                if done {
                    Circle().fill(FocusPaper.amber)
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                } else {
                    Circle().strokeBorder(next ? FocusPaper.ink : FocusPaper.line, lineWidth: 2)
                }
            }
            .frame(width: 20, height: 20)
            Text(time.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 15, weight: next ? .bold : .semibold))
                .foregroundStyle(done ? FocusPaper.secondary : FocusPaper.ink)
                .strikethrough(done, color: FocusPaper.secondary.opacity(0.5))
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(FocusPaper.page))
        .overlay(Capsule().strokeBorder(next ? FocusPaper.ink : .clear, lineWidth: 1.5))
    }

    /// One circle per plan day this week: full when the day's plan was done, a ring with a dot when
    /// partly done, a blue ring for today, light rings for the rest.
    private var weekDots: some View {
        HStack(spacing: 10) {
            ForEach(progress.week, id: \.date) { day in
                let isToday = cal.isDateInToday(day.date)
                VStack(spacing: 4) {
                    ZStack {
                        if day.done >= day.planned {
                            Circle().fill(FocusPaper.ink)
                        } else if day.done > 0 {
                            Circle().strokeBorder(FocusPaper.ink, lineWidth: 2)
                            Circle().fill(FocusPaper.ink).frame(width: 8, height: 8)
                        } else {
                            Circle().strokeBorder(isToday ? FocusPaper.amber : FocusPaper.line, lineWidth: 2)
                        }
                    }
                    .frame(width: 20, height: 20)
                    Text(cal.veryShortWeekdaySymbols[cal.component(.weekday, from: day.date) - 1])
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isToday ? FocusPaper.ink : FocusPaper.secondary)
                }
            }
        }
    }

    private var spoken: String {
        guard let today = progress.today else { return "Today's plan: rest day." }
        var s = "Today's plan: \(today.done) of \(today.planned) lock-ins done."
        if let next = progress.nextSlot(plan: plan) {
            s += " Next at \(next.formatted(date: .omitted, time: .shortened))."
        }
        return s + " \(progress.minutesToday) minutes won back today."
    }
}
