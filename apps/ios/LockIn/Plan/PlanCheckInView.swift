import SwiftUI

extension PlanWeekResult: Identifiable {
    var id: Date { weekStart }
}

/// The Monday check-in: last week on a receipt (planned, done, best day, won back), then next
/// week's plan. The suggestion is chosen already; one tap keeps it. Mock: personal-plan.html, screen 5.
struct PlanCheckInView: View {
    let result: PlanWeekResult
    let plan: LockInPlan
    let onDone: (LockInPlan) -> Void
    @State private var choice: PlanRules.Change

    init(result: PlanWeekResult, plan: LockInPlan, onDone: @escaping (LockInPlan) -> Void) {
        self.result = result
        self.plan = plan
        self.onDone = onDone
        _choice = State(initialValue: PlanRules.suggestion(done: result.done, planned: result.planned, plan: plan))
    }

    private var suggested: PlanRules.Change {
        PlanRules.suggestion(done: result.done, planned: result.planned, plan: plan)
    }

    private var title: String {
        let rate = result.planned == 0 ? 0 : Double(result.done) / Double(result.planned)
        let line = rate >= 0.9 ? "Nice work." : rate >= 0.5 ? "Good start." : "Let\u{2019}s adjust."
        return "Week \(result.number).\n\(line)"
    }

    /// Options that would change something (no "step it up" at the top of the ladder).
    private var options: [PlanRules.Change] {
        PlanRules.Change.allCases.filter { $0 == .keep || PlanRules.apply($0, to: plan) != plan }
    }

    private func name(_ c: PlanRules.Change) -> String {
        switch c {
        case .stepUp: return "Step it up"
        case .keep: return "Keep it"
        case .easier: return "Make it easier"
        }
    }

    private func detail(_ c: PlanRules.Change) -> String {
        let p = PlanRules.apply(c, to: plan)
        return "\(p.sessionsPerDay) \u{00D7} \(p.minutes) MIN"
    }

    private var bestDay: String {
        guard let i = result.bestDay else { return "\u{2014}" }
        let cal = FocusLog.calendar
        return cal.weekdaySymbols[(i + 1) % 7].uppercased()
    }

    var body: some View {
        ZStack {
            Ink.paper.ignoresSafeArea()
            Grain(color: Ink.ink.opacity(0.09)).ignoresSafeArea().allowsHitTesting(false)
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(title.uppercased())
                            .font(PrintFont.head(UIScreen.main.bounds.height < 700 ? 42 : 52))
                            .foregroundStyle(Ink.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 28)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityLabel(title)
                        receipt
                        Text("Next week:")
                            .font(PrintFont.mono(14, .bold))
                            .foregroundStyle(Ink.ink)
                            .padding(.top, 4)
                        VStack(spacing: 10) {
                            ForEach(options, id: \.self) { option in row(option) }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
                .scrollBounceBehavior(.basedOnSize)
                Button {
                    onDone(PlanRules.apply(choice, to: plan))
                } label: {
                    Text("START WEEK \(result.number + 1)")
                }
                .buttonStyle(PrintButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .accessibilityIdentifier("check-in-start")
            }
        }
    }

    private var receipt: some View {
        VStack(alignment: .leading, spacing: 10) {
            line("PLANNED", "\(result.planned) LOCK-INS")
            line("DONE", "\(result.done) LOCK-INS")
            line("BEST DAY", bestDay)
            Text(String(repeating: "- ", count: 30))
                .font(PrintFont.mono(13))
                .foregroundStyle(Ink.ink.opacity(0.3))
                .lineLimit(1)
                .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline) {
                Text("WON BACK").font(PrintFont.mono(15))
                Spacer()
                Text(FocusLog.format(minutes: result.minutes).uppercased())
                    .font(PrintFont.head(34))
                    .foregroundStyle(Ink.blue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .foregroundStyle(Ink.ink)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 28)
        .background(ReceiptEdge().fill(Color.white).shadow(color: .black.opacity(0.14), radius: 10, y: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Last week: \(result.done) of \(result.planned) lock-ins done, \(result.minutes) minutes won back.")
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
            Spacer()
            Text(value).fontWeight(.heavy)
        }
        .font(PrintFont.mono(15))
    }

    private func row(_ option: PlanRules.Change) -> some View {
        let on = choice == option
        return Button {
            withAnimation(.easeOut(duration: 0.16)) { choice = option }
        } label: {
            HStack {
                Text(name(option)).font(.system(size: 17, weight: .bold))
                if option == suggested {
                    Text("SUGGESTED")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(on ? Ink.ink : Ink.paper)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(on ? Ink.sun : Ink.blue))
                }
                Spacer()
                Text(detail(option)).font(PrintFont.mono(13))
                    .opacity(0.75)
            }
            .foregroundStyle(on ? Ink.paper : Ink.ink)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(on ? Ink.ink : Ink.receipt))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Ink.ink.opacity(on ? 0 : 0.12), lineWidth: 2))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: on)
        .accessibilityLabel("\(name(option)), \(detail(option))\(option == suggested ? ", suggested" : "")")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
