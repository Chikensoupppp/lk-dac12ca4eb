import FamilyControls
import ManagedSettings
import SwiftUI

/// "Here's your number." Apple Screen Time style (Brandon, 2026-11-20: make the hours pop, keep the
/// rest minimal): a small "Daily average" label, the hours as the one big thing, one line against the
/// guess, a quiet days-a-year line, and a plain "Most used" card. SF Pro only, no print effects.
/// The app gives this report a fixed 574 pt of height (`RevealStep.height`).
struct RevealView: View {
    let data: RevealData

    /// Paper, to match the app slides (the calm palette keeps color off full backgrounds).
    private static let paper = Color(red: 0.906, green: 0.910, blue: 0.890)
    private static let ink = Color(red: 0.08, green: 0.07, blue: 0.06)
    private static let secondary = Color(red: 0.08, green: 0.07, blue: 0.06).opacity(0.55)
    private static let card = Color.white.opacity(0.72)
    private static let more = OutlinedText.orangeDeep
    private static let less = Color(red: 0.16, green: 0.55, blue: 0.31)
    private static let bandText = ["1\u{2013}2 hours", "3\u{2013}4 hours", "5\u{2013}6 hours", "7+ hours"]
    /// Top of each guess band, in hours; 7+ has no top.
    private static let bandTop: [Double] = [2, 4, 6, .infinity]
    private static let bandBottom: [Double] = [0, 2, 4, 6]

    private var hours: Double { data.perDay / 3600 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Self.paper.ignoresSafeArea()
            if data.daysWithData == 0 { empty } else { filled }
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily average")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Self.secondary)
            Text("No history yet")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Self.ink)
            Text("This iPhone has no Screen Time for this week. We\u{2019}ll use your guess for now.")
                .font(.system(size: 17))
                .foregroundStyle(Self.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filled: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Daily average")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Self.secondary)
                .padding(.top, 8)
            hero
                .padding(.top, 2)
            if let line = guessLine {
                Label {
                    Text(line.text)
                } icon: {
                    Image(systemName: line.symbol)
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(line.color)
                .padding(.top, 2)
            }
            yearLine
                .padding(.top, 28)
            if !data.topApps.isEmpty {
                mostUsed
                    .padding(.top, 36)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The number: big bold digits, small grey units, like Screen Time and Fitness.
    private var hero: some View {
        let m = Int((data.perDay / 60).rounded())
        let digits = Font.system(size: 132, weight: .bold).monospacedDigit()
        let units = Font.system(size: 50, weight: .semibold)
        return (Text("\(m / 60)").font(digits).foregroundColor(Self.ink)
                + Text("h ").font(units).foregroundColor(Self.secondary)
                + Text("\(m % 60)").font(digits).foregroundColor(Self.ink)
                + Text("m").font(units).foregroundColor(Self.secondary))
            .tracking(-2)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityLabel("\(m / 60) hours \(m % 60) minutes a day")
    }

    /// One line against the guess: how far over, close, or under.
    private var guessLine: (text: String, symbol: String, color: Color)? {
        guard let g = data.guess else { return nil }
        let top = Self.bandTop[g], bottom = Self.bandBottom[g]
        if hours > top {
            let over = Int((hours - top).rounded())
            let amount = over >= 1 ? "\(over) hour\(over == 1 ? "" : "s") more" : "A bit more"
            return ("\(amount) than you guessed", "arrow.up.circle.fill", Self.more)
        }
        if hours < bottom { return ("Less than you guessed (\(Self.bandText[g]))", "arrow.down.circle.fill", Self.less) }
        return ("Right where you guessed", "checkmark.circle.fill", Self.ink)
    }

    private var yearLine: some View {
        let days = Int((hours * 365 / 24).rounded())
        return (Text("That\u{2019}s ") + Text("\(days) days").fontWeight(.bold).foregroundColor(Self.ink) + Text(" a year."))
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(Self.secondary)
    }

    /// Top three apps, Screen Time style: icon, name, a thin bar against the top app, time.
    private var mostUsed: some View {
        let apps = Array(data.topApps.prefix(3))
        let longest = max(apps.first?.seconds ?? 1, 1)
        return VStack(alignment: .leading, spacing: 14) {
            Text("MOST USED")
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Self.secondary)
            ForEach(apps) { app in
                HStack(spacing: 12) {
                    icon(app)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(app.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Self.ink)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(Self.short(app.seconds))
                                .font(.system(size: 15, weight: .medium).monospacedDigit())
                                .foregroundStyle(Self.secondary)
                        }
                        GeometryReader { g in
                            Capsule()
                                .fill(Self.ink.opacity(0.6))
                                .frame(width: max(6, g.size.width * app.seconds / longest), height: 4)
                        }
                        .frame(height: 4)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(app.name), \(Self.short(app.seconds)) a day")
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Self.card))
    }

    /// The app's own icon when Apple gives a token (only drawn here, inside the report), else its initial.
    @ViewBuilder
    private func icon(_ app: RevealData.AppTime) -> some View {
        if let token = app.token {
            Label(token)
                .labelStyle(.iconOnly)
                .frame(width: 32, height: 32)
        } else {
            Text(String(app.name.prefix(1)).uppercased())
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Self.ink.opacity(0.8)))
        }
    }

    /// "3h 52m", "45m".
    private static func short(_ seconds: TimeInterval) -> String {
        let m = Int((seconds / 60).rounded())
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }
}
