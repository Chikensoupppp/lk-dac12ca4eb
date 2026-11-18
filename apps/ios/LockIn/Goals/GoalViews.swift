import SwiftUI

/// A week to show in the report, by its Monday.
struct ReportWeek: Identifiable, Equatable { let id: Date }

/// Weekly screens palette: the same riso print look as the locked screen and the focus screen
/// (grey newsprint, black ink, riso Medium Blue). The old orange "Citrus" look is gone (2026-11-18).
/// Names are kept from the old palette so every use changes together.
private enum GoalInk {
    static let bg = Color(hex: 0xE7E8E3)
    static let panel = Color(hex: 0xF3F4F0)
    /// Main text: riso black.
    static let cream = Color(hex: 0x1B1B1B)
    static let soft = Color(hex: 0x575A55)
    /// Progress: bars, punch card, the pace card, the chosen goal. Riso Medium Blue.
    static let tangerine = Color(hex: 0x3255A4)
    /// Same blue for small text on the paper (about 5.4:1).
    static let tangerineText = Color(hex: 0x3255A4)
    /// Days under pace: a washed-out blue.
    static let peach = Color(hex: 0xA9B7D8)
    /// Text on the blue card, under the headline.
    static let onTangerineSoft = Color(hex: 0xDCE3F2)
    /// Quiet accent: riso black (today's dot, buttons on the blue card, toggles).
    static let green = Color(hex: 0x1B1B1B)
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
    var fill: Color = GoalInk.tangerine
    var under: Color = GoalInk.peach
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
        return Double(minutes) >= target ? fill : under
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
            .foregroundStyle(isToday ? Color.white : ink.opacity(0.6))
            .frame(width: 26, height: 26)
            .background(Circle().fill(isToday ? GoalInk.green : Color.clear))
            .frame(maxWidth: .infinity)
    }
}

/// The goal page: this week's progress, the weekly goal, and the reminder switches.
struct GoalSheet: View {
    @ObservedObject var goals: GoalStore
    var plus: PlusStore? = nil
    let onDone: () -> Void
    /// Starts a session from the pace card. Nil while a session runs.
    var onStart: (() -> Void)? = nil

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
                if let goal, week.minutes < goal * 60 { paceCard(goal: goal) }
                WeekBars(week: week, goal: goal, today: todayIndex)
                    .padding(.top, 2)
                statsTable

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
            WeekReportView(goals: goals, weekStart: r.id, plus: plus) { report = nil }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("THIS WEEK")
                    .font(PrintFont.mono(13, .heavy)).tracking(2)
                    .foregroundStyle(GoalInk.tangerineText)
                Text(daysLeft > 1 ? "\(range) \u{00B7} \(daysLeft) DAYS LEFT" : "\(range) \u{00B7} LAST DAY")
                    .font(PrintFont.mono(11, .medium))
                    .foregroundStyle(GoalInk.soft)
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
                        .foregroundStyle(GoalInk.tangerine)
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
            Text(done >= goal * 60 ? "Goal hit. Everything now is bonus." : "focused \u{00B7} \(percent)% of your \(goal) h goal")
                .font(PrintFont.body(16, .bold))
                .foregroundStyle(done >= goal * 60 ? GoalInk.tangerineText : GoalInk.soft)
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
                        RoundedRectangle(cornerRadius: 7).fill(GoalInk.tangerine)
                            .frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: 24)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(min(week.minutes / 60, goal)) of \(goal) goal hours filled")
    }

    /// Days left in the week, today included.
    private var daysLeft: Int { 7 - todayIndex }

    /// What it takes to hit the goal from here: time left, and a daily amount until Sunday.
    private func paceCard(goal: Int) -> some View {
        let left = goal * 60 - week.minutes
        let perDay = (left + daysLeft - 1) / daysLeft
        return VStack(alignment: .leading, spacing: 10) {
            Text("TO HIT YOUR GOAL")
                .font(PrintFont.mono(11, .heavy)).tracking(1.5)
                .foregroundStyle(Color.white)
            Text("\(FocusLog.format(minutes: left)) to go")
                .font(PrintFont.head(40))
                .foregroundStyle(Color.white)
            Text(daysLeft > 1
                 ? "About \(FocusLog.format(minutes: perDay)) a day gets you there by Sunday."
                 : "Last day. \(FocusLog.format(minutes: left)) today gets you there.")
                .font(PrintFont.body(15, .medium))
                .foregroundStyle(GoalInk.onTangerineSoft)
                .fixedSize(horizontal: false, vertical: true)
            if let onStart {
                Button(action: onStart) { Text("START A SESSION").lineLimit(1) }
                    .buttonStyle(PrintButtonStyle(fill: GoalInk.green, text: .white))
                    .accessibilityIdentifier("goal-start-session")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(GoalInk.tangerine))
        .accessibilityElement(children: .contain)
    }

    /// Minutes focused this week up to today, and in last week up to the same weekday.
    private var versusLastWeek: Int? {
        guard let lastWeek else { return nil }
        let past = FocusLog.week(of: lastWeek)
        guard !past.isEmpty else { return nil }
        let now = week.days[0...todayIndex].reduce(0) { $0 + $1.minutes }
        let then = past.days[0...todayIndex].reduce(0) { $0 + $1.minutes }
        return now - then
    }

    @ViewBuilder private var statsTable: some View {
        let rows = statRows
        if !rows.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    HStack {
                        Text(row.0).foregroundStyle(GoalInk.soft)
                        Spacer()
                        Text(row.1).fontWeight(.bold)
                            .foregroundStyle(row.2 ? GoalInk.tangerineText : GoalInk.cream)
                    }
                    .font(PrintFont.body(15, .regular))
                    .padding(.vertical, 11)
                    .overlay(alignment: .bottom) {
                        if i < rows.count - 1 { Rectangle().fill(GoalInk.cream.opacity(0.12)).frame(height: 1) }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .overlay(alignment: .top) { Rectangle().fill(GoalInk.cream).frame(height: 2) }
        }
    }

    /// (label, value, highlight) rows. Only rows with something real in them.
    private var statRows: [(String, String, Bool)] {
        var rows: [(String, String, Bool)] = []
        if week.sessions > 0 {
            rows.append(("Sessions finished", "\(week.sessions)", false))
            rows.append(("Average session", FocusLog.format(minutes: week.minutes / week.sessions), false))
        }
        if let best = week.bestDay {
            rows.append(("Best day", "\(dayNames[best]) \u{00B7} \(FocusLog.format(minutes: week.days[best].minutes))", false))
        }
        let streak = StreakStore.current()
        if streak > 0 { rows.append(("Streak", "\(streak) day\(streak == 1 ? "" : "s")", false)) }
        if week.quits > 0 { rows.append(("Ended early", "\(week.quits) \u{00B7} time still counted", false)) }
        if let diff = versusLastWeek {
            let text = diff == 0 ? "Even" : (diff > 0 ? "+\(FocusLog.format(minutes: diff)) ahead" : "\(FocusLog.format(minutes: -diff)) behind")
            rows.append(("Vs. this time last week", text, diff > 0))
        }
        return rows
    }

    private var goalPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WEEKLY GOAL \u{00B7} HOURS")
                .font(PrintFont.mono(13, .heavy)).tracking(2)
                .foregroundStyle(GoalInk.soft)
            HStack(spacing: 6) {
                ForEach(Array(GoalStore.range), id: \.self) { hours in
                    goalChip(hours)
                }
            }
            Text("\(draft) h a week is about \(FocusLog.format(minutes: draft * 60 / 7)) a day.")
                .font(PrintFont.body(15))
                .foregroundStyle(GoalInk.soft)
            if goal == nil {
                Button("SET MY GOAL") { goals.setGoal(draft) }
                    .buttonStyle(PrintButtonStyle(fill: GoalInk.tangerine, text: .white))
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
                .foregroundStyle(on ? Color.white : GoalInk.cream)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(on ? GoalInk.tangerine : GoalInk.panel)
                        // The navy edge belongs to the chip, not to its number.
                        .shadow(color: on ? GoalInk.cream : .clear, radius: 0, x: 3, y: 3)
                )
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
                    Stamp(text: hit ? "Goal hit" : "Not yet", color: hit ? GoalInk.tangerineText : GoalInk.soft, size: 14, tilt: hit ? -8 : 6, fill: GoalInk.panel)
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

/// The weekly report and the saved-weeks history, on the same paper as the main screen.
/// Only Nogbox's own finished sessions are counted. The 3 most recent weeks are free; older
/// saved weeks need Plus.
struct WeekReportView: View {
    @ObservedObject var goals: GoalStore
    let weekStart: Date
    var plus: PlusStore? = nil
    let onDone: () -> Void

    @State private var chosen: Int?
    @State private var viewing: Date?
    @State private var showHistory = false
    @State private var showOffer = false
    @State private var saved: [FocusLog.Week] = []

    private static let freeWeeks = 3
    private var current: Date { viewing ?? weekStart }
    private var isReportedWeek: Bool { current == weekStart }
    private var week: FocusLog.Week { FocusLog.week(of: current) }
    private var previous: FocusLog.Week? {
        FocusLog.calendar.date(byAdding: .day, value: -7, to: current).map { FocusLog.week(of: $0) }
    }
    private var goal: Int? { goals.goal(forWeekOf: current) }
    private var nextWeek: Date { FocusLog.calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart }
    private var hit: Bool { goal.map { week.minutes >= $0 * 60 } ?? false }
    private var hasPlus: Bool { plus?.hasPlus ?? false }

    private func range(_ start: Date, year: Bool) -> String {
        let end = FocusLog.calendar.date(byAdding: .day, value: 6, to: start) ?? start
        let f = Date.FormatStyle().month(.abbreviated).day()
        let text = "\(start.formatted(f))\u{2013}\(end.formatted(.dateTime.day()))"
        return year ? text + ", " + end.formatted(.dateTime.year()) : text
    }

    var body: some View {
        ZStack {
            FocusPaper.page.ignoresSafeArea()
            if showHistory { history } else { report }
        }
        .preferredColorScheme(.light)
        .foregroundStyle(FocusPaper.ink)
        .onAppear {
            goals.markSeen(weekStart)
            saved = (0..<60).compactMap { n in
                FocusLog.calendar.date(byAdding: .day, value: -7 * n, to: FocusLog.weekStart(.now)).map { FocusLog.week(of: $0) }
            }
        }
        .sheet(isPresented: $showOffer) {
            if let plus { PlusOfferStep(plus: plus, intro: false) { showOffer = false } }
        }
    }

    // MARK: Report

    private func bar(_ left: AnyView, _ title: String) -> some View {
        HStack {
            left.frame(width: 60, height: 44, alignment: .leading)
            Spacer()
            Text(title).font(.system(size: 17, weight: .semibold))
            Spacer()
            Button("Done", action: onDone)
                .font(.system(size: 17, weight: .medium))
                .frame(minWidth: 60, minHeight: 44, alignment: .trailing)
                .accessibilityIdentifier("report-done")
        }
        .padding(.horizontal, 24)
        .padding(.top, 6)
    }

    private var hoursText: Text {
        let h = week.minutes / 60, m = week.minutes % 60
        let big = Font.system(size: 84, weight: .heavy)
        let small = Font.system(size: 34, weight: .semibold)
        var t = Text("")
        if h > 0 { t = t + Text("\(h)").font(big) + Text("h ").font(small).foregroundColor(FocusPaper.secondary) }
        if m > 0 || h == 0 { t = t + Text("\(m)").font(big) + Text("m").font(small).foregroundColor(FocusPaper.secondary) }
        return t
    }

    private var report: some View {
        VStack(spacing: 0) {
            bar(AnyView(Button { showHistory = true } label: {
                Image(systemName: "clock.arrow.circlepath").font(.system(size: 22, weight: .regular))
                    .frame(width: 44, height: 44, alignment: .leading)
            }.accessibilityLabel("History").accessibilityIdentifier("report-history")), "Weekly report")
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(isReportedWeek ? "Your week." : "That week.")
                        .font(.system(size: 46, weight: .heavy)).tracking(-1.4)
                        .padding(.top, 28)
                    Text(range(current, year: true))
                        .font(.system(size: 18)).foregroundStyle(FocusPaper.secondary).padding(.top, 10)
                    hoursText.padding(.top, 26).accessibilityLabel(FocusLog.format(minutes: week.minutes))
                    goalLine.padding(.top, 14)
                    dailyFocus.padding(.top, 30)
                    Rectangle().fill(FocusPaper.line).frame(height: 1).padding(.top, 22)
                    VStack(spacing: 0) {
                        row("Sessions finished", "\(week.sessions)")
                        if let previous, !previous.isEmpty {
                            let diff = week.minutes - previous.minutes
                            row("Vs. previous week", diff == 0 ? "same" : (diff > 0 ? "+" : "\u{2212}") + short(abs(diff)))
                        }
                        row("Ended early", "\(week.quits)")
                    }
                    Text("Time from early endings is included.")
                        .font(.system(size: 15)).foregroundStyle(FocusPaper.secondary).padding(.top, 4)
                    if isReportedWeek { nextGoal.padding(.top, 30) }
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func short(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    @ViewBuilder private var goalLine: some View {
        if let goal {
            let extra = week.minutes - goal * 60
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: hit ? "checkmark.circle" : "circle.dashed")
                    .font(.system(size: 22)).foregroundStyle(FocusPaper.amber)
                VStack(alignment: .leading, spacing: 4) {
                    Text(hit ? "\(goal)-hour goal met" : "\(goal)-hour goal not met")
                        .font(.system(size: 20, weight: .semibold))
                    Text(hit ? (extra > 0 ? "\(extra) min beyond your goal" : "Right on target")
                             : "Short by \(short(-extra)). Next week starts clean.")
                        .font(.system(size: 17)).foregroundStyle(FocusPaper.secondary)
                }
            }
        } else {
            Text("No goal set. Pick one for next week below.")
                .font(.system(size: 17)).foregroundStyle(FocusPaper.secondary)
        }
    }

    private var dailyFocus: some View {
        let best = week.bestDay
        let names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let tallest = Double(max(week.days.map(\.minutes).max() ?? 0, 1))
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Daily focus").font(.system(size: 18, weight: .semibold))
                Spacer()
                if let best { Text("\(names[best]) \u{00B7} \(short(week.days[best].minutes))").font(.system(size: 17)).foregroundStyle(FocusPaper.secondary) }
            }
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(i == best ? FocusPaper.amber : (week.days[i].minutes == 0 ? FocusPaper.line : Color(hex: 0x3F3A33)))
                            .frame(height: max(3, 150 * Double(week.days[i].minutes) / tallest))
                        Text(["M", "T", "W", "T", "F", "S", "S"][i])
                            .font(.system(size: 16, weight: i == best ? .bold : .regular))
                            .foregroundStyle(i == best ? FocusPaper.ink : FocusPaper.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 184, alignment: .bottom)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((0..<7).map { "\(names[$0]) \(FocusLog.format(minutes: week.days[$0].minutes))" }.joined(separator: ", "))
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(FocusPaper.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
        .font(.system(size: 18)).frame(minHeight: 52)
    }

    private var nextGoal: some View {
        let base = goal ?? GoalStore.suggested
        let up = min(base + 1, GoalStore.range.upperBound)
        let down = max(base - 1, GoalStore.range.lowerBound)
        return VStack(alignment: .leading, spacing: 14) {
            Text("Next week").font(.system(size: 30, weight: .heavy)).tracking(-0.6)
            if let chosen {
                Text("Set: \(chosen) hours. Go get it.").font(.system(size: 20, weight: .semibold))
            } else if goal == nil {
                pill("Start with \(base) hours", dark: true) { pick(base) }
            } else if hit && up != base {
                HStack(spacing: 12) {
                    pill("Try \(up) hours", dark: true) { pick(up) }
                    pill("Keep \(base) hours", dark: false) { pick(base) }
                }
            } else {
                HStack(spacing: 12) {
                    pill("Keep \(base) hours", dark: true) { pick(base) }
                    if down != base { pill("Try \(down) hours", dark: false) { pick(down) } }
                }
            }
            Button(chosen == nil ? "Decide later" : "Done", action: onDone)
                .font(.system(size: 17)).foregroundStyle(FocusPaper.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func pill(_ title: String, dark: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 20, weight: .semibold))
                .foregroundStyle(dark ? Color.white : FocusPaper.ink)
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(Capsule().fill(dark ? FocusPaper.ink : FocusPaper.inset))
        }
        .buttonStyle(.plain)
    }

    private func pick(_ hours: Int) {
        // The report can open on Sunday evening (for this week) or later (for last week). Next
        // week's goal goes on the week after the reported one, and on to today's week if that
        // is later, so the goal page shows it straight away.
        goals.setGoal(hours, forWeekOf: nextWeek)
        if FocusLog.weekStart(.now) > nextWeek { goals.setGoal(hours, forWeekOf: .now) }
        chosen = hours
    }

    // MARK: History

    private var shown: [FocusLog.Week] {
        saved.enumerated().filter { $0.offset == 0 || !$0.element.isEmpty }.map(\.element)
    }

    private func title(_ w: FocusLog.Week) -> String {
        let thisWeek = FocusLog.weekStart(.now)
        if w.start == thisWeek { return "This week" }
        if FocusLog.calendar.date(byAdding: .day, value: -7, to: thisWeek) == w.start { return "Last week" }
        return range(w.start, year: false)
    }

    private var history: some View {
        let weeks = shown
        let scale = Double(max(weeks.map { max($0.minutes, (goals.goal(forWeekOf: $0.start) ?? 0) * 60) }.max() ?? 1, 1))
        return VStack(spacing: 0) {
            bar(AnyView(Button { showHistory = false } label: {
                Image(systemName: "chevron.left").font(.system(size: 20, weight: .medium))
                    .frame(width: 44, height: 44, alignment: .leading)
            }.accessibilityLabel("Back")), "History")
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Your weeks.").font(.system(size: 46, weight: .heavy)).tracking(-1.4).padding(.top, 28)
                    Text(hasPlus ? "Every saved week is open." : "Your \(Self.freeWeeks) most recent saved weeks are free.")
                        .font(.system(size: 18)).foregroundStyle(FocusPaper.secondary).padding(.top, 10)
                    Rectangle().fill(FocusPaper.line).frame(height: 1).padding(.top, 36)
                    ForEach(Array(weeks.enumerated()), id: \.element.start) { index, w in
                        if hasPlus || index < Self.freeWeeks { openRow(w, scale: scale) } else { lockedRow(w) }
                    }
                }
                .padding(.horizontal, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            if !hasPlus && weeks.count > Self.freeWeeks {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Every week counts.").font(.system(size: 30, weight: .heavy)).tracking(-0.6)
                    Text("Open every report saved on this iPhone.").font(.system(size: 17)).foregroundStyle(FocusPaper.secondary)
                    Button { showOffer = true } label: {
                        Label("Unlock saved history", systemImage: "crown")
                            .font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(Capsule().fill(FocusPaper.ink))
                    }
                    .buttonStyle(.plain).padding(.top, 8)
                    .accessibilityIdentifier("history-unlock")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
        }
    }

    private func openRow(_ w: FocusLog.Week, scale: Double) -> some View {
        let g = goals.goal(forWeekOf: w.start)
        let met = g.map { w.minutes >= $0 * 60 } ?? false
        return Button {
            viewing = w.start; showHistory = false
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title(w)).font(.system(size: 21, weight: .semibold))
                    Spacer()
                    Text(short(w.minutes)).font(.system(size: 21, weight: .semibold))
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
                }
                Text("\(w.sessions) session\(w.sessions == 1 ? "" : "s")" + (met ? " \u{00B7} Goal met" : ""))
                    .font(.system(size: 17)).foregroundStyle(FocusPaper.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(FocusPaper.line)
                        Capsule().fill(FocusPaper.amber).frame(width: max(8, geo.size.width * min(Double(w.minutes) / scale, 1)))
                    }
                }
                .frame(height: 10).padding(.top, 4)
            }
            .padding(.vertical, 22)
            .overlay(alignment: .bottom) { Rectangle().fill(FocusPaper.line).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title(w)), \(FocusLog.format(minutes: w.minutes))")
    }

    private func lockedRow(_ w: FocusLog.Week) -> some View {
        HStack {
            Text(title(w)).font(.system(size: 21, weight: .semibold))
            Spacer()
            Image(systemName: "lock").font(.system(size: 16))
            Text("Plus").font(.system(size: 17, weight: .medium))
        }
        .foregroundStyle(FocusPaper.secondary)
        .padding(.vertical, 30)
        .overlay(alignment: .bottom) { Rectangle().fill(FocusPaper.line).frame(height: 1) }
        .accessibilityLabel("\(title(w)), locked. Needs Plus.")
    }
}
