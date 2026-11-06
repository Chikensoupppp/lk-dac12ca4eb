import SwiftUI

/// Shown after the first finished session of a day.
struct StreakView: View {
    let minutes: Int
    let done: () -> Void

    @State private var count = 0
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private let streak = StreakStore.current()
    private let week = StreakStore.week()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Session done.")
                .font(Cream.rounded(44, .heavy))
                .kerning(-1.4)
                .foregroundStyle(Matte.text)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 56)

            HStack(alignment: .bottom, spacing: 14) {
                Text("\(count)")
                    .font(Cream.rounded(150, .heavy))
                    .kerning(-8)
                    .foregroundStyle(OB.warm)
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                VStack(alignment: .leading, spacing: 6) {
                    Text("day streak")
                        .font(Cream.rounded(30, .heavy))
                        .kerning(-1)
                        .foregroundStyle(Matte.text)
                    Text("\(minutes) minutes focused")
                        .font(Cream.rounded(18, .medium))
                        .foregroundStyle(Matte.textSoft)
                }
                .padding(.bottom, 14)
            }
            .padding(.top, 36)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(streak) day streak. \(minutes) minutes focused.")

            HStack {
                ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 8) {
                        ZStack {
                            if day.done {
                                Circle().fill(OB.warm)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .heavy))
                                    .foregroundStyle(OB.ink)
                            } else {
                                Circle().strokeBorder(Matte.tickMajor, style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                            }
                        }
                        .frame(width: 44, height: 44)
                        Text(day.label)
                            .font(Cream.rounded(14, day.done ? .bold : .medium))
                            .foregroundStyle(day.done ? Matte.text : Matte.textSoft)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 48)
            .accessibilityHidden(true)

            StickerNote(text: "come back tomorrow", color: OB.sage, tilt: -3)
                .padding(.top, 40)
                .opacity(shown ? 1 : 0)

            Spacer(minLength: 16)

            Button(action: done) { Text("DONE") }
                .buttonStyle(MatteButtonStyle(prominent: true))
                .accessibilityIdentifier("streak-done")
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            LinearGradient(colors: [Matte.bgTop, Matte.bgMid, Matte.bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.success, trigger: shown)
        .task {
            if effectiveReduceMotion(systemReduceMotion) { count = streak; shown = true; return }
            // Count up to the streak, then pop the note in.
            for value in 0...max(streak, 0) {
                count = value
                try? await Task.sleep(for: .milliseconds(120))
            }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { shown = true }
        }
    }
}
