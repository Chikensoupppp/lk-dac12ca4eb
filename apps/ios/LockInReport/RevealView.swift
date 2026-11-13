import FamilyControls
import ManagedSettings
import SwiftUI

/// "Here's your number." The guess (crossed out when it was off), the real daily average, and a printed receipt of the top apps.
/// Same inks as the app's printed onboarding (copied here; the extension cannot share app code).
struct RevealView: View {
    let data: RevealData

    /// Paper, to match the app slides (the calm palette keeps color off full backgrounds).
    private static let paper = Color(red: 0.906, green: 0.910, blue: 0.890)
    private static let ink = Color(red: 0.08, green: 0.07, blue: 0.06)
    private static let receipt = Color(red: 0.965, green: 0.945, blue: 0.906)
    private static let red = Color(red: 0.82, green: 0.35, blue: 0.27)
    private static let bands = ["1\u{2013}2 HRS", "3\u{2013}4 HRS", "5\u{2013}6 HRS", "7+ HRS"]
    /// Top of each guess band, in hours; 7+ has no top.
    private static let bandTop: [Double] = [2, 4, 6, .infinity]
    private static let bandBottom: [Double] = [0, 2, 4, 6]

    private var hours: Double { data.perDay / 3600 }

    /// How the real average compares with the band the user guessed.
    private var verdict: String? {
        guard let g = data.guess else { return nil }
        if hours > Self.bandTop[g] { return "That\u{2019}s more than you guessed." }
        if hours < Self.bandBottom[g] { return "That\u{2019}s less than you guessed." }
        return "You were close."
    }

    var body: some View {
        ZStack {
            Self.paper.ignoresSafeArea()
            if data.daysWithData == 0 {
                empty
            } else {
                filled
            }
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("NO HISTORY YET.")
                .font(.system(size: 52, weight: .black).width(.compressed))
            Text("This iPhone has no Screen Time history for this week. We\u{2019}ll use your guess for now.")
                .font(.system(size: 17, weight: .semibold))
            Spacer()
        }
        .foregroundStyle(Self.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filled: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HERE\u{2019}S YOUR NUMBER.")
                .font(.system(size: 56, weight: .black).width(.compressed))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let g = data.guess {
                HStack(spacing: 6) {
                    Text("YOU GUESSED:")
                    // Crossed out only when the guess was off.
                    Text(Self.bands[g]).strikethrough(verdict != "You were close.", color: Self.ink)
                }
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
            }
            Text(Self.duration(data.perDay))
                .font(.system(size: 110, weight: .black).width(.compressed))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("That\u{2019}s your average daily screen time.")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
            if let verdict {
                Text(verdict)
                    .font(.system(size: 20, weight: .heavy).width(.condensed))
            }
            receipt
                .padding(.top, 10)
            Text("THAT\u{2019}S \(Int((hours * 365 / 24).rounded())) DAYS A YEAR.")
                .font(.system(size: 26, weight: .black).width(.compressed))
                .padding(.top, 8)
        }
        .foregroundStyle(Self.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var receipt: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YOUR RECEIPT").font(.system(size: 15, weight: .heavy, design: .monospaced)).tracking(2)
                .frame(maxWidth: .infinity)
            Text("THIS WEEK \u{00B7} PER DAY").font(.system(size: 12, weight: .medium, design: .monospaced))
                .frame(maxWidth: .infinity)
            dashes
            ForEach(data.topApps) { app in
                HStack(spacing: 8) {
                    if let token = app.token {
                        Label(token).labelStyle(.iconOnly).frame(width: 18, height: 18)
                    }
                    row(app.name, Self.duration(app.seconds), bold: false)
                }
            }
            dashes
            row("TOTAL", Self.duration(data.perDay), bold: true)
            row("PICKUPS", "\u{00D7}\(data.pickupsPerDay)", bold: false).foregroundStyle(Self.red)
        }
        .padding(18)
        .padding(.bottom, 8)
        .background(Self.receipt)
        .rotationEffect(.degrees(1))
        .shadow(color: .black.opacity(0.3), radius: 14, y: 12)
        .overlay(alignment: .bottomTrailing) {
            Text(hours >= 3 ? "THAT\u{2019}S A LOT" : "NOT BAD")
                .font(.system(size: 22, weight: .black).width(.compressed))
                .foregroundStyle(Self.red)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 8).fill(Self.receipt.opacity(0.92)))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Self.red, lineWidth: 3.5))
                .rotationEffect(.degrees(-9))
                .offset(x: -6, y: 18)
        }
    }

    private var dashes: some View {
        Rectangle()
            .stroke(Self.ink.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            .frame(height: 1)
    }

    private func row(_ label: String, _ value: String, bold: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label).lineLimit(1)
            Text(String(repeating: ".", count: 60)).lineLimit(1).opacity(0.35).layoutPriority(-1)
            Text(value).lineLimit(1).layoutPriority(1)
        }
        .font(.system(size: bold ? 18 : 13, weight: bold ? .heavy : .medium, design: .monospaced))
    }

    private static func duration(_ seconds: TimeInterval) -> String {
        let m = Int((seconds / 60).rounded())
        return "\(m / 60)H \(String(format: "%02d", m % 60))M"
    }
}
