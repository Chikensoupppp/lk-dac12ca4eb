import SwiftUI

struct FocusView: View {
    @State private var duration: Int = 25
    @State private var isLocked = false
    @State private var startedAt: Date?

    private var endDate: Date? {
        guard let startedAt else { return nil }
        return startedAt.addingTimeInterval(TimeInterval(duration * 60))
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.09).ignoresSafeArea()
            VStack(spacing: 28) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("LOCK IN").font(.system(size: 14, weight: .bold, design: .rounded)).tracking(3)
                        Text(isLocked ? "Your focus is active." : "Make space for deep work.")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                    }
                    Spacer()
                }
                .foregroundStyle(.white)

                if let endDate, isLocked {
                    Text(endDate, style: .timer)
                        .font(.system(size: 70, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                } else {
                    Picker("Duration", selection: $duration) {
                        Text("25 min").tag(25)
                        Text("50 min").tag(50)
                        Text("90 min").tag(90)
                    }
                    .pickerStyle(.segmented)
                }

                Button {
                    if isLocked {
                        isLocked = false
                        startedAt = nil
                    } else {
                        startedAt = Date()
                        isLocked = true
                    }
                } label: {
                    Text(isLocked ? "END SESSION" : "LOCK IN")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
                .buttonStyle(.borderedProminent)
                .tint(isLocked ? .gray : Color(red: 0.35, green: 0.85, blue: 0.70))
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 18))

                Text(isLocked ? "Windows workspace: readying" : "Choose a duration to begin")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(24)
        }
    }
}

#Preview { FocusView() }
