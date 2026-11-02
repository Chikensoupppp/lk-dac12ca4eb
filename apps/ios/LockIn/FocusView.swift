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
                        Text(isLocked ? "Focus session" : "How long do you want?")
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
                    Picker("Focus duration", selection: $duration) {
                        Text("15 minutes").tag(15)
                        Text("25 minutes").tag(25)
                        Text("45 minutes").tag(45)
                        Text("60 minutes").tag(60)
                        Text("90 minutes").tag(90)
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
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

                Text(isLocked ? "Your focus time is running" : "Choose a time, then lock in")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(24)
        }
    }
}

#Preview { FocusView() }
