import SwiftUI

/// "Can't do 4:00?" from the plan slide. Three screens, all optional, all on the plan's step:
/// 1. `WhenAskStep`: asks for the calendar, showing what it does (mock docs/design/calendar-ask-v2.html).
/// 2. `WhenFreeStep`: the user's real free time, the best fit first, or a time fitted to each
///    day (Plus) (mock docs/design/schedule-v5.html).
/// 3. `WhenPickStep`: pick a time by hand; with a calendar, each day is checked for clashes
///    (mock docs/design/schedule-pick-cal.html).
/// Research: docs/design/schedule-research.md.

/// The time and what happens then, chosen on these screens.
struct TimeChoice: Equatable {
    var startMinute: Int
    var weekdays: Set<Int>
    var dayStarts: [Int: Int]?
    var schedule: LockInSchedule
}

private enum WhenInk {
    static let free = Color(hex: 0xDCE4F5)
    static let soft = Color(hex: 0x45473F)
    static let sheet = Color(hex: 0xF4F4F0)
    static let short = [1: "SUN", 2: "MON", 3: "TUE", 4: "WED", 5: "THU", 6: "FRI", 7: "SAT"]
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

// MARK: 1. Ask for the calendar

struct WhenAskStep: View {
    let useCalendar: () -> Void
    let pickOwn: () -> Void
    @State private var asking = false

    var body: some View {
        PrintScaffold(step: 12, tag: "When it fits", title: "Let\u{2019}s find your\nfree time.", titleSize: 48,
                      primaryTitle: asking ? "ASKING..." : "USE MY CALENDAR", primaryEnabled: !asking,
                      primaryAction: { asking = true; useCalendar() },
                      secondaryTitle: "I\u{2019}ll pick a time", secondaryAction: pickOwn) {
            VStack(alignment: .leading, spacing: 14) {
                PlannerPage()
                    .rotationEffect(.degrees(-1))
                    .padding(.horizontal, -4)
                HStack(spacing: 12) {
                    Image("BrainExact").resizable().scaledToFit().frame(width: 60)
                    Text("Away game Wednesday? That day\u{2019}s off.")
                        .font(PrintFont.hand(19))
                        .foregroundStyle(Ink.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill").font(.system(size: 12, weight: .bold))
                    Text("Read on this iPhone. Nothing leaves it.")
                        .font(PrintFont.mono(13))
                }
                .foregroundStyle(Ink.ink)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// A printed week planner with example events. A highlighter finds the free time, LOCK-IN
/// stickers stamp into it, and the away-game day stays empty. Example data only: this is shown
/// before the app may read anything.
private struct PlannerPage: View {
    @State private var phase = 0
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private struct Event { let from: Double; let to: Double; let name: String; var off = false }
    private static let days: [(name: String, events: [Event], lock: Double?)] = [
        ("MON", [Event(from: 15, to: 16.5, name: "Class"), Event(from: 19, to: 20.5, name: "Practice")], 17.5),
        ("TUE", [Event(from: 15, to: 17, name: "Work")], 17.5),
        ("WED", [Event(from: 15, to: 23, name: "Away game", off: true)], nil),
        ("THU", [Event(from: 15, to: 16.5, name: "Class"), Event(from: 19.5, to: 21, name: "Dinner")], 17.5),
        ("FRI", [Event(from: 15, to: 15.5, name: "Class"), Event(from: 20, to: 23, name: "Party")], 17),
    ]
    private static let hour: CGFloat = 26

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("THIS WEEK").font(PrintFont.head(22))
                Spacer()
                Text("EVENINGS").font(PrintFont.mono(10, .bold)).tracking(1.4).foregroundStyle(WhenInk.soft)
            }
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) { Rectangle().fill(Ink.ink).frame(height: 2) }
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 18)
                    ZStack(alignment: .topLeading) {
                        ForEach([16, 18, 20, 22], id: \.self) { h in
                            Text("\(h - 12)PM").font(PrintFont.mono(9)).foregroundStyle(Ink.ink.opacity(0.5))
                                .offset(y: CGFloat(h - 15) * Self.hour - 5)
                        }
                    }
                    .frame(width: 30, height: 8 * Self.hour, alignment: .topLeading)
                }
                ForEach(Array(Self.days.enumerated()), id: \.offset) { i, day in
                    column(day.name, events: day.events, lock: day.lock, index: i)
                }
            }
            .padding(.top, 10)
        }
        .padding(14)
        .background(shape.fill(Color(hex: 0xFBFBF8)))
        .overlay(shape.strokeBorder(Ink.ink, lineWidth: 2))
        .background(shape.fill(Ink.ink).offset(y: 6))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Example week: the free time between classes and practice gets a lock-in, and the away-game day stays free.")
        .task {
            if effectiveReduceMotion(systemReduceMotion) { phase = 3; return }
            for p in 1...3 {
                guard await printPause(p == 1 ? 0.3 : 0.6) else { return }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { phase = p }
            }
        }
    }

    private func column(_ name: String, events: [Event], lock: Double?, index: Int) -> some View {
        let y = { (h: Double) in CGFloat(h - 15) * Self.hour }
        let free = gaps(events)
        return VStack(spacing: 0) {
            Text(name).font(PrintFont.mono(10.5, .bold)).foregroundStyle(WhenInk.soft).frame(height: 18)
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 6).fill(Ink.ink.opacity(0.03))
                ForEach(Array(free.enumerated()), id: \.offset) { _, g in
                    RoundedRectangle(cornerRadius: 3).fill(Ink.sun.opacity(0.42))
                        .frame(height: y(g.1) - y(g.0))
                        .scaleEffect(x: 1, y: phase >= 2 ? 1 : 0.001, anchor: .top)
                        .offset(y: y(g.0))
                }
                ForEach(Array(events.enumerated()), id: \.offset) { _, e in
                    Text(e.name)
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(e.off ? Ink.red : Ink.ink)
                        .lineLimit(2)
                        .padding(3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(RoundedRectangle(cornerRadius: 5).fill(e.off ? Color(hex: 0xF7E3DE) : Color(hex: 0xECECE6)))
                        .overlay(alignment: .leading) { Rectangle().fill(e.off ? Ink.red : Ink.ink.opacity(0.55)).frame(width: 3) }
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .frame(height: y(e.to) - y(e.from) - 2)
                        .offset(y: y(e.from))
                        .opacity(phase >= 1 ? 1 : 0)
                }
                if let lock {
                    Text("LOCK-IN")
                        .font(.system(size: 7.5, weight: .heavy)).tracking(0.6)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 24)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Ink.blue))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Ink.ink, lineWidth: 2))
                        .offset(y: y(lock))
                        .scaleEffect(phase >= 3 ? 1 : 1.5)
                        .opacity(phase >= 3 ? 1 : 0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.55).delay(Double(index) * 0.08), value: phase)
                }
            }
            .frame(height: 8 * Self.hour, alignment: .top)
        }
        .frame(maxWidth: .infinity)
    }

    private func gaps(_ events: [Event]) -> [(Double, Double)] {
        var out: [(Double, Double)] = []
        var t = 15.0
        for e in events.sorted(by: { $0.from < $1.from }) {
            if e.from > t { out.append((t, e.from)) }
            t = max(t, e.to)
        }
        if t < 23 { out.append((t, 23)) }
        return out
    }
}

// MARK: 2. Your free time

struct WhenFreeStep: View {
    let plan: LockInPlan
    let days: [CalendarFit.Day]
    let done: (TimeChoice) -> Void
    let pickOwn: () -> Void

    @State private var eachDay = false
    @State private var picked = 0
    @State private var then: LockInSchedule.Then = .remind
    @State private var addToCalendar = true

    private var minutes: Int { plan.minutesPerDay }
    private var window: ClosedRange<Int> { CalendarFit.window(near: plan.startMinute) }
    private var suggestions: [CalendarFit.Suggestion] {
        CalendarFit.suggestions(days: days, minutes: minutes, near: plan.startMinute)
    }
    private var perDay: [Int: Int] { CalendarFit.bestEachDay(days: days, minutes: minutes, near: chosen) }
    private var chosen: Int {
        suggestions.indices.contains(picked) ? suggestions[picked].minute : plan.startMinute
    }

    var body: some View {
        PrintScaffold(step: 12, tag: "When it fits", title: "When will you\nbe free?", titleSize: 48,
                      primaryTitle: eachDay ? "LOCK IN EACH DAY" : "LOCK IN AT \(clock(chosen))", primaryAction: confirm,
                      secondaryTitle: "Pick another time", secondaryAction: pickOwn) {
            VStack(alignment: .leading, spacing: 16) {
                Text(eachDay ? "Fitted around what\u{2019}s on each day." : "Blue is your free time. Best fit first.")
                    .font(PrintFont.mono(14))
                    .foregroundStyle(Ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
                ModeSwitch(eachDay: $eachDay)
                if !eachDay {
                    if suggestions.isEmpty {
                        Text("Nothing is free all week at these hours. Pick a time and drop the busy days.")
                            .font(PrintFont.body(14, .semibold))
                            .foregroundStyle(Ink.red)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        chips
                    }
                }
                week
                Text("AND THEN?").font(PrintFont.mono(11, .bold)).tracking(1.4).foregroundStyle(WhenInk.soft)
                ThenCards(then: $then, minute: chosen, perDay: eachDay)
                AddToCalendarRow(on: $addToCalendar)
            }
        }
    }

    private var chips: some View {
        HStack(spacing: 9) {
            ForEach(Array(suggestions.enumerated()), id: \.offset) { i, s in
                let on = i == picked
                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { picked = i } } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(clock(s.minute)) \(ampm(s.minute))").font(PrintFont.head(22))
                        Text(s.freeDays == s.workingDays ? "Free all \(s.workingDays)" : "Free \(s.freeDays) of \(s.workingDays)")
                            .font(PrintFont.mono(11))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(on ? Color.white : Ink.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(on ? Ink.blue : Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(on ? Ink.ink : Ink.ink.opacity(0.16), lineWidth: 2))
                    .background(RoundedRectangle(cornerRadius: 14).fill(Ink.ink).offset(y: on ? 4 : 0))
                    .overlay(alignment: .topLeading) {
                        if i == 0 {
                            Text("BEST FIT").font(PrintFont.mono(9, .bold)).tracking(1)
                                .foregroundStyle(Ink.ink)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Capsule().fill(Ink.sun))
                                .overlay(Capsule().strokeBorder(Ink.ink, lineWidth: 2))
                                .offset(x: 8, y: -11)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(DailyNudge.timeText(minute: s.minute)), free \(s.freeDays) of \(s.workingDays) days\(i == 0 ? ", best fit" : "")")
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.top, 6)
    }

    private var week: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return VStack(spacing: 4) {
            ForEach(days, id: \.date) { day in
                let start = eachDay ? perDay[day.weekday] : chosen
                let clash = !eachDay && day.dayOff == nil && day.clash(start: chosen, minutes: minutes) != nil
                let label: String = {
                    if day.dayOff != nil { return "day off" }
                    guard let start else { return "full" }
                    return clash ? "clash" : clock(start)
                }()
                DayStrip(day: day, window: window, lockStart: day.dayOff == nil ? start : nil, minutes: minutes,
                         clash: clash, label: label,
                         labelColor: day.dayOff != nil || clash || start == nil ? Ink.red : (eachDay && start != chosen ? Ink.blue : Ink.ink))
            }
            HStack {
                ForEach(Array(stride(from: window.lowerBound, through: window.upperBound, by: 180)), id: \.self) { m in
                    Text("\(clock(m))\(ampm(m))").font(PrintFont.mono(9)).foregroundStyle(Ink.ink.opacity(0.5))
                    if m + 180 <= window.upperBound { Spacer() }
                }
            }
            .padding(.leading, 40).padding(.trailing, 64)
            HStack(spacing: 14) {
                key(WhenInk.free, "FREE")
                key(Color.white, "BUSY", hatch: true)
                key(Ink.blue, "LOCK-IN")
            }
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 40)
        }
        .padding(12)
        .background(shape.fill(WhenInk.sheet))
        .overlay(shape.strokeBorder(Ink.ink, lineWidth: 2))
        .background(shape.fill(Ink.ink).offset(y: 5))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: chosen)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: eachDay)
    }

    private func key(_ color: Color, _ text: String, hatch: Bool = false) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color)
                .overlay { if hatch { Hatch().stroke(Ink.ink.opacity(0.3), lineWidth: 1).clipShape(RoundedRectangle(cornerRadius: 3)) } }
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Ink.ink.opacity(0.25), lineWidth: 1))
                .frame(width: 14, height: 10)
            Text(text).font(PrintFont.mono(10)).foregroundStyle(WhenInk.soft)
        }
        .accessibilityHidden(true)
    }

    private func confirm() {
        let schedule = LockInSchedule(then: then, addToCalendar: addToCalendar)
        if eachDay {
            var starts = perDay
            for d in plan.weekdays where starts[d] == nil { starts[d] = chosen }
            done(TimeChoice(startMinute: chosen, weekdays: plan.weekdays, dayStarts: starts, schedule: schedule))
        } else {
            done(TimeChoice(startMinute: chosen, weekdays: plan.weekdays, dayStarts: nil, schedule: schedule))
        }
    }
}

/// "Same time daily" / "Best time each day" (Plus).
private struct ModeSwitch: View {
    @Binding var eachDay: Bool

    var body: some View {
        HStack(spacing: 0) {
            segment("Same time daily", on: !eachDay) { eachDay = false }
            segment("Best time each day", on: eachDay) { eachDay = true }
                .overlay(alignment: .topTrailing) { PlusBadge().offset(x: -4, y: -16) }
        }
        .padding(4)
        .background(Capsule().fill(Color.white))
        .overlay(Capsule().strokeBorder(Ink.ink, lineWidth: 2))
        .padding(.top, 6)
    }

    private func segment(_ text: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { action() } } label: {
            Text(text)
                .font(PrintFont.body(14, .heavy))
                .foregroundStyle(on ? Color.white : Ink.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Capsule().fill(on ? Ink.blue : Color.clear))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}

/// One evening as a strip: free time light blue, busy time hatched, the lock-in a pill.
private struct DayStrip: View {
    let day: CalendarFit.Day
    let window: ClosedRange<Int>
    let lockStart: Int?
    let minutes: Int
    let clash: Bool
    let label: String
    let labelColor: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(WhenInk.short[day.weekday] ?? "")
                .font(PrintFont.mono(11, .bold))
                .foregroundStyle(WhenInk.soft)
                .frame(width: 30, alignment: .leading)
            GeometryReader { g in
                let w = g.size.width
                let span = CGFloat(window.upperBound - window.lowerBound)
                let x = { (m: Int) -> CGFloat in
                    CGFloat(min(max(m, window.lowerBound), window.upperBound) - window.lowerBound) / span * w
                }
                ZStack(alignment: .leading) {
                    Capsule().fill(WhenInk.free)
                    ForEach(Array(day.busy.enumerated()), id: \.offset) { _, r in
                        Rectangle().fill(Color.white)
                            .overlay(Hatch().stroke(Ink.ink.opacity(0.22), lineWidth: 1.5))
                            .clipped()
                            .frame(width: max(x(r.upperBound) - x(r.lowerBound), 0))
                            .offset(x: x(r.lowerBound))
                    }
                    if let off = day.dayOff {
                        Text(off.uppercased())
                            .font(PrintFont.mono(9, .bold)).tracking(0.8)
                            .foregroundStyle(Ink.red)
                            .lineLimit(1)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Ink.red, lineWidth: 1.5))
                            .frame(maxWidth: .infinity)
                    }
                    if let lockStart {
                        Capsule().fill(clash ? Ink.red : Ink.blue)
                            .overlay(Capsule().strokeBorder(Ink.ink, lineWidth: 2))
                            .frame(width: max(x(lockStart + minutes) - x(lockStart), 18), height: 16)
                            .offset(x: x(lockStart))
                    }
                }
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Ink.ink.opacity(0.14), lineWidth: 1.5))
            }
            .frame(height: 20)
            Text(label)
                .font(PrintFont.mono(12, .bold))
                .foregroundStyle(labelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 54, alignment: .trailing)
        }
        .frame(height: 30)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(WhenInk.full[day.weekday] ?? ""): \(label)")
    }
}

/// Diagonal lines, like riso hatching, for busy time.
private struct Hatch: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        var x = r.minX - r.height
        while x < r.maxX {
            p.move(to: CGPoint(x: x, y: r.maxY))
            p.addLine(to: CGPoint(x: x + r.height, y: r.minY))
            x += 5
        }
        return p
    }
}

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

/// "Remind me" (free) or "Lock by itself" (Plus).
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

/// "Add to my calendar": SwipeLater's own repeating events, so nothing gets booked over them.
struct AddToCalendarRow: View {
    @Binding var on: Bool

    var body: some View {
        Toggle(isOn: $on) {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Ink.ink)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add to my calendar").font(PrintFont.body(15, .heavy)).foregroundStyle(Ink.ink)
                    Text("So nothing gets booked over it.").font(PrintFont.body(12, .medium)).foregroundStyle(WhenInk.soft)
                }
            }
        }
        .tint(Ink.blue)
        .padding(.horizontal, 14)
        .frame(minHeight: 56)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Ink.ink, lineWidth: 2))
    }
}

// MARK: 3. Pick your own

struct WhenPickStep: View {
    let plan: LockInPlan
    /// The calendar's days, or empty without a calendar.
    let days: [CalendarFit.Day]
    let calendarAllowed: Bool
    var backToSuggestions: (() -> Void)? = nil
    let done: (TimeChoice) -> Void

    @State private var minute: Int
    @State private var weekdays: Set<Int>
    @State private var then: LockInSchedule.Then = .remind
    @State private var addToCalendar = true

    init(plan: LockInPlan, days: [CalendarFit.Day], calendarAllowed: Bool,
         backToSuggestions: (() -> Void)? = nil, done: @escaping (TimeChoice) -> Void) {
        self.plan = plan
        self.days = days
        self.calendarAllowed = calendarAllowed
        self.backToSuggestions = backToSuggestions
        self.done = done
        _minute = State(initialValue: plan.startMinute)
        _weekdays = State(initialValue: plan.weekdays)
    }

    private var clashes: [CalendarFit.Day] {
        days.filter { weekdays.contains($0.weekday) && $0.clash(start: minute, minutes: plan.minutesPerDay) != nil }
    }

    var body: some View {
        PrintScaffold(step: 12, tag: "When it fits", title: "When works\nfor you?", titleSize: 48,
                      primaryTitle: "SET \(clock(minute)) \(ampm(minute))", primaryEnabled: !weekdays.isEmpty,
                      primaryAction: confirm,
                      secondaryTitle: backToSuggestions == nil ? nil : "Back to suggestions",
                      secondaryAction: backToSuggestions) {
            VStack(alignment: .leading, spacing: 18) {
                bigTime
                dayStamps
                if !days.isEmpty { calendarCheck }
                Text("AND THEN?").font(PrintFont.mono(11, .bold)).tracking(1.4).foregroundStyle(WhenInk.soft)
                ThenCards(then: $then, minute: minute)
                if calendarAllowed { AddToCalendarRow(on: $addToCalendar) }
            }
        }
    }

    private var bigTime: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return HStack {
            step("minus", by: -15)
            Spacer(minLength: 4)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(clock(minute)).font(PrintFont.head(64)).monospacedDigit()
                    .contentTransition(.numericText(value: Double(minute)))
                Text(ampm(minute)).font(PrintFont.head(26))
            }
            .foregroundStyle(Ink.ink)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(DailyNudge.timeText(minute: minute))
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
        Button { shift(delta) } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Ink.ink)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Color.white))
                .overlay(Circle().strokeBorder(Ink.ink, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: minute)
        .accessibilityLabel(delta > 0 ? "Later" : "Earlier")
    }

    private func shift(_ delta: Int) {
        withAnimation(.snappy(duration: 0.2)) { minute = min(max(minute + delta, 5 * 60), 23 * 60) }
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

    private var calendarCheck: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR CALENDAR AT \(clock(minute))")
                .font(PrintFont.mono(11, .bold)).tracking(1.4).foregroundStyle(WhenInk.soft)
            HStack(spacing: 7) {
                ForEach(days, id: \.date) { day in
                    let kept = weekdays.contains(day.weekday)
                    let what = day.clash(start: minute, minutes: plan.minutesPerDay)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if kept { weekdays.remove(day.weekday) } else { weekdays.insert(day.weekday) }
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Text(WhenInk.short[day.weekday] ?? "").font(PrintFont.mono(10, .bold)).foregroundStyle(WhenInk.soft)
                            Image(systemName: !kept ? "minus" : (what == nil ? "checkmark" : "exclamationmark"))
                                .font(.system(size: 16, weight: .heavy))
                            Text(!kept ? "Dropped" : (what ?? "Free"))
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(!kept ? WhenInk.soft : (what == nil ? Ink.blue : Ink.red))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 2)
                        .frame(maxWidth: .infinity, minHeight: 74)
                        .background(RoundedRectangle(cornerRadius: 12).fill(!kept ? Color.clear : (what == nil ? Color.white : Color(hex: 0xFBEDEA))))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(!kept ? Ink.ink.opacity(0.25) : (what == nil ? Ink.ink : Ink.red), lineWidth: 2))
                        .opacity(kept ? 1 : 0.6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(WhenInk.full[day.weekday] ?? ""): \(!kept ? "dropped" : (what ?? "free"))")
                    .accessibilityHint(kept ? "Drops this day" : "Keeps this day")
                }
            }
            if !clashes.isEmpty {
                Text(clashLine)
                    .font(PrintFont.hand(19))
                    .foregroundStyle(Ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var clashLine: String {
        let names = clashes.compactMap { WhenInk.full[$0.weekday] }
        let list = names.count == 1 ? names[0] : names.dropLast().joined(separator: ", ") + " and " + (names.last ?? "")
        return "\(list) \(names.count == 1 ? "clashes" : "clash"). Keep \(names.count == 1 ? "it" : "them") anyway, or tap to drop."
    }

    private func confirm() {
        done(TimeChoice(startMinute: minute, weekdays: weekdays, dayStarts: nil,
                        schedule: LockInSchedule(then: then, addToCalendar: calendarAllowed && addToCalendar)))
    }
}
