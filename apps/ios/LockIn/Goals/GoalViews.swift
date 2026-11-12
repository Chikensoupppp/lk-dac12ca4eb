import SwiftUI

/// A week to show in the report, by its Monday.
struct ReportWeek: Identifiable, Equatable { let id: Date }

/// Goal page colors: the same monitor palette as the brain widget and the quit screens.
private enum GoalInk {
    static let bg = BrainDrawing.bg
    static let panel = BrainDrawing.panel
    static let cream = BrainDrawing.cream
    static let green = BrainDrawing.green
    static let alarm = BrainDrawing.alarm
    static let empty = BrainDrawing.rgb(0x1E3A32)
}

private let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]
private let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

/// Seven bars, Monday to Sunday, scaled to a day's share of the goal.
private struct WeekBars: View {
    let week: FocusLog.Week
    let goal: Int?
    var ink: Color = GoalInk.cream
    var fill: Color = GoalInk.green
    var empty: Color = GoalInk.empty
    var today: Int?

    var body: some View {
        // A full bar is a day that did a fifth of the goal, so a normal week fills most bars.
        let full = max(Double((goal ?? GoalStore.suggested) * 60) / 5, Double(week.days.map(\.minutes).max() ?? 0), 1)
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(week.days[i].minutes > 0 ? fill : empty)
                                .frame(height: max(6, geo.size.height * min(Double(week.days[i].minutes) / full, 1)))
                        }
                    }
                    Text(dayLetters[i])
                        .font(PrintFont.mono(11, i == today ? .heavy : .medium))
                        .foregroundStyle(ink.opacity(i == today ? 1 : 0.55))
                }
            }
        }
        .frame(height: 96)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((0..<7).map { "\(dayNames[$0]) \(FocusLog.format(minutes: week.days[$0].minutes))" }.joined(separator: ", "))
    }
}

/// The goal page: this week's progress, the weekly goal, and the reminder switches.
struct GoalSheet: View {
    @ObservedObject var goals: GoalStore
    let onDone: () -> Void

    @State private var draft = GoalStore.suggested
    @State private var asking = false
    @State private var report: ReportWeek?

    private var week: FocusLog.Week { FocusLog.week(of: .now) }
    private var goal: Int? { goals.goal() }
    private var todayIndex: Int { (FocusLog.calendar.component(.weekday, from: .now) + 5) % 7 }
    private var lastWeek: Date? { FocusLog.calendar.date(byAdding: .day, value: -7, to: FocusLog.weekStart(.now)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("THIS WEEK")
                        .font(PrintFont.mono(13, .heavy)).tracking(2)
                        .foregroundStyle(GoalInk.green)
                    Spacer()
                    Button("Done", action: onDone)
                        .font(PrintFont.body(16, .bold))
                        .foregroundStyle(GoalInk.cream)
                        .frame(minWidth: 44, minHeight: 44)
                }
                progress
                WeekBars(week: week, goal: goal, today: todayIndex)
                    .padding(.top, 4)

                divider
                goalPicker
                divider
                reminders

                if let lastWeek, !FocusLog.week(of: lastWeek).isEmpty || goals.goal(forWeekOf: lastWeek) != nil {
                    Button { report = ReportWeek(id: lastWeek) } label: {
                        HStack {
                            Text("LAST WEEK'S REPORT")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(PrintFont.mono(14, .heavy))
                        .foregroundStyle(GoalInk.cream)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 52)
                        .background(RoundedRectangle(cornerRadius: 14).fill(GoalInk.panel))
                    }
                }
            }
            .padding(24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(GoalInk.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear { draft = goal ?? GoalStore.suggested }
        .sheet(item: $report) { r in
            WeekReportView(goals: goals, weekStart: r.id) { report = nil }
        }
    }

    private var divider: some View {
        Rectangle().fill(GoalInk.cream.opacity(0.12)).frame(height: 1)
    }

    @ViewBuilder private var progress: some View {
        let done = week.minutes
        Text(FocusLog.format(minutes: done))
            .font(PrintFont.head(72))
            .foregroundStyle(GoalInk.cream)
            .accessibilityLabel("\(FocusLog.format(minutes: done)) focused this week")
        if let goal {
            let percent = min(done * 100 / (goal * 60), 100)
            Text(done >= goal * 60 ? "Goal hit. \(goal) hours done." : "of your \(goal)-hour goal \u{00B7} \(percent)%")
                .font(PrintFont.body(17, .bold))
                .foregroundStyle(done >= goal * 60 ? GoalInk.green : GoalInk.cream.opacity(0.8))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(GoalInk.empty)
                    Capsule().fill(GoalInk.green)
                        .frame(width: max(12, geo.size.width * Double(percent) / 100))
                }
            }
            .frame(height: 12)
            .accessibilityHidden(true)
        } else {
            Text("focused this week. Set a goal to see how far along you are.")
                .font(PrintFont.body(16))
                .foregroundStyle(GoalInk.cream.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var goalPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WEEKLY GOAL")
                .font(PrintFont.mono(13, .heavy)).tracking(2)
                .foregroundStyle(GoalInk.cream.opacity(0.7))
            HStack(spacing: 14) {
                stepButton("minus", enabled: draft > GoalStore.range.lowerBound) { change(-1) }
                VStack(spacing: 0) {
                    Text("\(draft)")
                        .font(PrintFont.head(56))
                        .monospacedDigit()
                    Text("HOURS")
                        .font(PrintFont.mono(11, .heavy)).tracking(2)
                }
                .foregroundStyle(GoalInk.cream)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(draft) hours a week")
                stepButton("plus", enabled: draft < GoalStore.range.upperBound) { change(1) }
            }
            Text("About \(FocusLog.format(minutes: draft * 60 / 7)) a day.")
                .font(PrintFont.body(15))
                .foregroundStyle(GoalInk.cream.opacity(0.7))
            if goal == nil {
                Button("SET MY GOAL") { goals.setGoal(draft) }
                    .buttonStyle(PrintButtonStyle(fill: GoalInk.green, text: GoalInk.bg))
            }
        }
    }

    private func change(_ by: Int) {
        draft = min(max(draft + by, GoalStore.range.lowerBound), GoalStore.range.upperBound)
        if goal != nil { goals.setGoal(draft) }
    }

    private func stepButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(GoalInk.bg)
                .frame(width: 56, height: 56)
                .background(Circle().fill(GoalInk.cream))
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(icon == "plus" ? "One hour more" : "One hour less")
    }

    private var reminders: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(
                get: { goals.remindersOn },
                set: { on in
                    if on { asking = true; Task { await goals.turnRemindersOn(); asking = false } }
                    else { goals.remindersOn = false }
                })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remind me").font(PrintFont.body(17, .bold))
                    Text("A nudge at 5 PM with how far along you are, and your report on Sunday evening.")
                        .font(PrintFont.body(14, .regular))
                        .foregroundStyle(GoalInk.cream.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .disabled(asking)
            Toggle(isOn: $goals.weekdaysOnly) {
                Text("Weekdays only").font(PrintFont.body(17, .bold))
            }
            .disabled(!goals.remindersOn)
            .opacity(goals.remindersOn ? 1 : 0.4)
            .frame(minHeight: 44)
        }
        .tint(GoalInk.green)
        .foregroundStyle(GoalInk.cream)
    }
}

/// The Sunday report, printed like a receipt: goal hit or missed, the week's numbers, and next
/// week's goal. Only Lock In's own sessions are counted.
struct WeekReportView: View {
    @ObservedObject var goals: GoalStore
    let weekStart: Date
    let onDone: () -> Void

    @State private var chosen: Int?

    private var week: FocusLog.Week { FocusLog.week(of: weekStart) }
    private var previous: FocusLog.Week? {
        FocusLog.calendar.date(byAdding: .day, value: -7, to: weekStart).map { FocusLog.week(of: $0) }
    }
    private var goal: Int? { goals.goal(forWeekOf: weekStart) }
    private var nextWeek: Date { FocusLog.calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart }
    private var hit: Bool { goal.map { week.minutes >= $0 * 60 } ?? false }

    private var range: String {
        let end = FocusLog.calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let f = Date.FormatStyle().month(.abbreviated).day()
        return "\(weekStart.formatted(f)) \u{2013} \(end.formatted(f))".uppercased()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                receipt
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                nextGoal
                    .padding(24)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(GoalInk.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear { goals.markSeen(weekStart) }
    }

    private var headline: String {
        guard let goal else { return "Your week." }
        return hit ? "You did it." : (week.minutes >= goal * 30 ? "Close." : "Not this week.")
    }

    private var line: String {
        let done = FocusLog.format(minutes: week.minutes)
        guard let goal else { return "You focused \(done). Set a goal for next week below." }
        if hit { return "Goal: \(goal) hours. You focused \(done)." }
        return "You focused \(done) of \(goal) hours. No shame in it. Next week starts clean."
    }

    private var receipt: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("LOCK IN \u{00B7} YOUR WEEK")
                Spacer()
                Text(range)
            }
            .font(PrintFont.mono(11, .heavy))
            .foregroundStyle(Ink.soft)

            Text(headline.uppercased())
                .font(PrintFont.head(58))
                .foregroundStyle(Ink.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            // The stamp gets its own space beside the line, so it never covers the numbers.
            HStack(alignment: .center, spacing: 12) {
                Text(line)
                    .font(PrintFont.body(16))
                    .foregroundStyle(Ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if goal != nil {
                    Stamp(text: hit ? "Goal hit" : "Missed", color: hit ? Ink.blue : Ink.red, size: 18, tilt: hit ? -9 : 7)
                        .fixedSize()
                        .padding(.trailing, 4)
                }
            }

            WeekBars(week: week, goal: goal, ink: Ink.ink, fill: Ink.ink, empty: Ink.ink.opacity(0.1))
                .padding(.vertical, 6)

            VStack(spacing: 8) {
                ReceiptRow(label: "Focused", value: FocusLog.format(minutes: week.minutes), bold: true)
                ReceiptRow(label: "Sessions finished", value: "\(week.sessions)")
                if let best = week.bestDay {
                    ReceiptRow(label: "Best day", value: dayNames[best])
                }
                ReceiptRow(label: "Quit early", value: "\(week.quits)", color: week.quits > 0 ? Ink.red : Ink.ink)
                if let previous, !previous.isEmpty {
                    let diff = week.minutes - previous.minutes
                    ReceiptRow(label: "Vs last week",
                               value: diff == 0 ? "same" : (diff > 0 ? "+" : "\u{2212}") + FocusLog.format(minutes: abs(diff)))
                }
            }
            Text("Counts finished Lock In sessions only.")
                .font(PrintFont.mono(10))
                .foregroundStyle(Ink.soft)
                .padding(.bottom, 14)
        }
        .padding(20)
        .padding(.bottom, 8)
        .background(ReceiptEdge().fill(Ink.receipt))
    }

    private var nextGoal: some View {
        let base = goal ?? GoalStore.suggested
        let other = hit ? min(base + 1, GoalStore.range.upperBound) : max(base - 1, GoalStore.range.lowerBound)
        return VStack(alignment: .leading, spacing: 12) {
            Text("NEXT WEEK'S GOAL")
                .font(PrintFont.mono(13, .heavy)).tracking(2)
                .foregroundStyle(GoalInk.green)
            if let chosen {
                Text("Set: \(chosen) hours. Go get it.")
                    .font(PrintFont.bold(24))
                    .foregroundStyle(GoalInk.cream)
            } else {
                Button(goal == nil ? "START WITH \(base) HOURS" : "KEEP \(base) HOURS") { pick(base) }
                    .buttonStyle(PrintButtonStyle(fill: GoalInk.cream, text: GoalInk.bg))
                if goal != nil && other != base {
                    Button(hit ? "TRY \(other) HOURS" : "TRY \(other) HOURS INSTEAD") { pick(other) }
                        .buttonStyle(PrintButtonStyle(fill: hit ? GoalInk.green : GoalInk.panel, text: hit ? GoalInk.bg : GoalInk.cream))
                }
            }
            Button(chosen == nil ? "Not now" : "Done", action: onDone)
                .font(PrintFont.body(15))
                .foregroundStyle(GoalInk.cream.opacity(0.65))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func pick(_ hours: Int) {
        // The report can open on Sunday evening (for this week) or later (for last week). Next
        // week's goal goes on the week after the reported one, and on to today's week if that
        // is later, so the goal page shows it straight away.
        goals.setGoal(hours, forWeekOf: nextWeek)
        if FocusLog.weekStart(.now) > nextWeek { goals.setGoal(hours, forWeekOf: .now) }
        chosen = hours
    }
}
