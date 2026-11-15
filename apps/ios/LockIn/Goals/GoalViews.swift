import SwiftUI

/// A week to show in the report, by its Monday.
struct ReportWeek: Identifiable, Equatable { let id: Date }

/// Goal page colors: the same monitor palette as the brain widget and the quit screens.
private enum GoalInk {
    // Riso newsprint, same as the slides and the main screen (2026-11-13).
    static let bg = Color(hex: 0xE7E8E3)
    static let panel = Color(hex: 0xF3F4F0)
    /// Main text (the name is from the old dark look, where text was cream).
    static let cream = Color(hex: 0x1B1B1B)
    /// The action color: riso Medium Blue.
    static let green = Color(hex: 0x3255A4)
    static let alarm = Color(hex: 0xD25A44)
    static let empty = Color(hex: 0xD8DAD2)
}

private let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]
private let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

/// Seven day bars, Monday to Sunday. A dashed line marks one day's share of the goal: days that
/// reach it are full color, shorter days are lighter, empty days are a pale stub. Today's letter
/// sits in a sunflower dot.
private struct WeekBars: View {
    let week: FocusLog.Week
    let goal: Int?
    var ink: Color = GoalInk.cream
    var fill: Color = GoalInk.green
    var empty: Color = GoalInk.empty
    var today: Int?
    private let height: CGFloat = 112

    /// Minutes a day needs to carry its share of the goal.
    private var target: Double? { goal.map { Double($0 * 60) / 7 } }

    /// The bar scale: the dashed line sits about two thirds up, and a long day is never clipped.
    private var full: Double {
        let tallest = Double(week.days.map(\.minutes).max() ?? 0)
        return max((target ?? 40) * 1.5, tallest, 1)
    }

    private func barColor(_ minutes: Int) -> Color {
        if minutes == 0 { return empty }
        guard let target else { return fill }
        return Double(minutes) >= target ? fill : fill.opacity(0.42)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 7)
                        .fill(barColor(week.days[i].minutes))
                        .frame(height: max(8, height * min(Double(week.days[i].minutes) / full, 1)))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: height, alignment: .bottom)
            .overlay { targetLine }

            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    dayLabel(i)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((0..<7).map { "\(dayNames[$0]) \(FocusLog.format(minutes: week.days[$0].minutes))" }.joined(separator: ", "))
    }

    @ViewBuilder private var targetLine: some View {
        if let target {
            GeometryReader { geo in
                Path { p in
                    let y = geo.size.height * (1 - min(target / full, 1))
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
                .stroke(ink.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
            .allowsHitTesting(false)
        }
    }

    private func dayLabel(_ i: Int) -> some View {
        let isToday = i == today
        return Text(dayLetters[i])
            .font(PrintFont.mono(12, isToday ? .heavy : .medium))
            .foregroundStyle(isToday ? Ink.ink : ink.opacity(0.55))
            .frame(width: 26, height: 26)
            .background(Circle().fill(isToday ? Ink.sun : Color.clear))
            .frame(maxWidth: .infinity)
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

    private var range: String {
        let start = FocusLog.weekStart(.now)
        let end = FocusLog.calendar.date(byAdding: .day, value: 6, to: start) ?? start
        let f = Date.FormatStyle().month(.abbreviated).day()
        return "\(start.formatted(f)) \u{2013} \(end.formatted(f))".uppercased()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                hero
                if let goal { punchCard(goal: goal) }
                WeekBars(week: week, goal: goal, today: todayIndex)
                    .padding(.top, 2)
                statsLine

                divider
                goalPicker
                reminders
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18).fill(GoalInk.panel))

                if let lastWeek, !FocusLog.week(of: lastWeek).isEmpty || goals.goal(forWeekOf: lastWeek) != nil {
                    lastWeekTicket(lastWeek)
                }
            }
            .padding(24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(GoalInk.bg.ignoresSafeArea())
        .preferredColorScheme(.light)
        .onAppear { draft = goal ?? GoalStore.suggested }
        .sheet(item: $report) { r in
            WeekReportView(goals: goals, weekStart: r.id) { report = nil }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("THIS WEEK")
                    .font(PrintFont.mono(13, .heavy)).tracking(2)
                    .foregroundStyle(GoalInk.green)
                Text(range)
                    .font(PrintFont.mono(11, .medium))
                    .foregroundStyle(GoalInk.cream.opacity(0.55))
            }
            Spacer()
            Button("Done", action: onDone)
                .font(PrintFont.body(16, .bold))
                .foregroundStyle(GoalInk.cream)
                .frame(minWidth: 44, minHeight: 44)
        }
    }

    private var divider: some View {
        Rectangle().fill(GoalInk.cream.opacity(0.12)).frame(height: 1)
    }

    /// How the brain looks at the week so far: calm, then keen, then cheering once the goal is hit.
    private var mood: CoachExpression {
        guard let goal else { return .normal }
        let percent = week.minutes * 100 / (goal * 60)
        return percent >= 100 ? .cheer : (percent >= 50 ? .keen : .normal)
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                // Two-ink "misprint": a sunflower copy sits just behind the black numerals.
                ZStack(alignment: .leading) {
                    Text(FocusLog.format(minutes: week.minutes))
                        .foregroundStyle(Ink.sun)
                        .offset(x: 3, y: 3)
                        .accessibilityHidden(true)
                    Text(FocusLog.format(minutes: week.minutes))
                        .foregroundStyle(GoalInk.cream)
                }
                .font(PrintFont.head(72))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(FocusLog.format(minutes: week.minutes)) focused this week")
                subtitle
            }
            Spacer(minLength: 0)
            BrainCanvas(stage: 0, expression: mood)
                .frame(width: 88, height: 74)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var subtitle: some View {
        if let goal {
            let done = week.minutes
            let percent = min(done * 100 / (goal * 60), 100)
            Text(done >= goal * 60 ? "Goal hit. \(goal) hours done." : "of your \(goal)-hour goal \u{00B7} \(percent)%")
                .font(PrintFont.body(16, .bold))
                .foregroundStyle(done >= goal * 60 ? GoalInk.green : GoalInk.cream.opacity(0.8))
        } else {
            Text("focused. Set a goal below.")
                .font(PrintFont.body(16))
                .foregroundStyle(GoalInk.cream.opacity(0.8))
        }
    }

    /// One slot for every hour of the goal. Each fills blue as the hours add up, like a punch card.
    private func punchCard(goal: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<goal, id: \.self) { hour in
                let fraction = min(max(Double(week.minutes - hour * 60) / 60, 0), 1)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 7).fill(GoalInk.empty)
                        RoundedRectangle(cornerRadius: 7).fill(GoalInk.green)
                            .frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: 24)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(min(week.minutes / 60, goal)) of \(goal) goal hours filled")
    }

    @ViewBuilder private var statsLine: some View {
        let parts = statParts
        if !parts.isEmpty {
            Text(parts.joined(separator: "  \u{00B7}  "))
                .font(PrintFont.mono(12, .heavy))
                .tracking(1)
                .foregroundStyle(GoalInk.cream.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statParts: [String] {
        var parts: [String] = []
        if week.sessions > 0 { parts.append("\(week.sessions) SESSION\(week.sessions == 1 ? "" : "S")") }
        if let best = week.bestDay { parts.append("BEST \(dayNames[best].prefix(3).uppercased())") }
        let streak = StreakStore.current()
        if streak > 0 { parts.append("STREAK \(streak)D") }
        return parts
    }

    private var goalPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WEEKLY GOAL \u{00B7} HOURS")
                .font(PrintFont.mono(13, .heavy)).tracking(2)
                .foregroundStyle(GoalInk.cream.opacity(0.7))
            HStack(spacing: 6) {
                ForEach(Array(GoalStore.range), id: \.self) { hours in
                    goalChip(hours)
                }
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

    private func goalChip(_ hours: Int) -> some View {
        let on = hours == draft
        return Button {
            draft = hours
            if goal != nil { goals.setGoal(hours) }
        } label: {
            Text("\(hours)")
                .font(PrintFont.head(26))
                .foregroundStyle(on ? GoalInk.bg : GoalInk.cream)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(RoundedRectangle(cornerRadius: 14).fill(on ? GoalInk.green : GoalInk.panel))
                .shadow(color: on ? Ink.sun : .clear, radius: 0, x: 3, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(hours) hours a week")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// A small ticket for last week: the time, the stamp, and a way into the full report.
    private func lastWeekTicket(_ start: Date) -> some View {
        let past = FocusLog.week(of: start)
        let pastGoal = goals.goal(forWeekOf: start)
        let hit = pastGoal.map { past.minutes >= $0 * 60 } ?? false
        return Button { report = ReportWeek(id: start) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LAST WEEK'S REPORT")
                        .font(PrintFont.mono(11, .heavy)).tracking(1.5)
                        .foregroundStyle(GoalInk.cream.opacity(0.6))
                    Text(FocusLog.format(minutes: past.minutes))
                        .font(PrintFont.head(32))
                        .foregroundStyle(GoalInk.cream)
                }
                Spacer()
                if pastGoal != nil {
                    Stamp(text: hit ? "Goal hit" : "Missed", color: hit ? Ink.blue : Ink.red, size: 14, tilt: hit ? -8 : 6)
                        .fixedSize()
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(GoalInk.cream)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 22)
            .frame(minHeight: 72)
            .background(ReceiptEdge().fill(GoalInk.panel))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Last week's report. \(FocusLog.format(minutes: past.minutes)) focused.")
        .accessibilityIdentifier("last-week-report")
    }

    @AppStorage(IfThenPlan.onKey) private var ifThenOn = false
    @AppStorage(IfThenPlan.cueKey) private var ifThenCue = ""
    @State private var dailyMinute: Int? = DailyNudge.minuteOfDay()

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
            if let minute = dailyMinute {
                Toggle(isOn: Binding(get: { true }, set: { _ in DailyNudge.turnOff(); dailyMinute = nil })) {
                    Text("Daily reminder · \(DailyNudge.timeText(minute: minute))").font(PrintFont.body(17, .bold))
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier("daily-nudge-toggle")
            }
            Toggle(isOn: $ifThenOn) {
                Text("If-then line").font(PrintFont.body(17, .bold))
            }
            .frame(minHeight: 44)
            .accessibilityIdentifier("if-then-toggle")
            if ifThenOn {
                TextField("When I sit at my desk", text: $ifThenCue)
                    .font(PrintFont.body(17, .regular))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(RoundedRectangle(cornerRadius: 12).fill(GoalInk.cream.opacity(0.08)))
                    .onChange(of: ifThenCue) { _, value in
                        if value.count > IfThenPlan.maxLength { ifThenCue = String(value.prefix(IfThenPlan.maxLength)) }
                    }
                    .accessibilityIdentifier("if-then-field")
            }
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
        .preferredColorScheme(.light)
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

            // Two-ink "misprint": a sunflower copy sits just behind the black headline.
            ZStack(alignment: .topLeading) {
                Text(headline.uppercased())
                    .foregroundStyle(Ink.sun)
                    .offset(x: 3, y: 3)
                    .accessibilityHidden(true)
                Text(headline.uppercased())
                    .foregroundStyle(Ink.ink)
            }
            .font(PrintFont.head(58))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(headline)
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

            // A dashed tear line between the picture and the numbers, like a printed receipt.
            Rectangle()
                .stroke(Ink.ink.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .frame(height: 1)
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
