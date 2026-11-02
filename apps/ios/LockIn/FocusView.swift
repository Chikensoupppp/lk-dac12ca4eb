import SwiftUI

/// Focus screen. `timing` is the single source of truth for the session:
/// nil means idle, non-nil means a session is running until `timing.endsAt`.
/// The clock, labels and completion all derive from it.
struct FocusView: View {
    private static let durationOptions = [15, 25, 45, 60, 90]

    @State private var selectedMinutes = 45
    @State private var timing: SessionTiming?
    @State private var justCompleted = false
    @State private var completionCount = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var isLocked: Bool { timing != nil }

    private var stateAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.7)
    }

    private var clockCaption: String {
        if let timing {
            return "Ends " + timing.endsAt.formatted(date: .omitted, time: .shortened)
        }
        return justCompleted ? "Session complete" : "Ready"
    }

    var body: some View {
        ZStack {
            FocusBackdrop()

            GeometryReader { geo in
                let side = max(min(geo.size.width - 48, geo.size.height * 0.5), 200)

                VStack(spacing: 0) {
                    Text("LOCK IN")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(5)
                        .foregroundStyle(Color.white.opacity(isLocked ? 0.3 : 0.55))
                        .padding(.top, 12)

                    Spacer(minLength: 16)

                    CountdownClockView(
                        duration: TimeInterval(selectedMinutes * 60),
                        timing: timing,
                        caption: clockCaption
                    )
                    .frame(width: side, height: side)

                    Spacer(minLength: 16)

                    VStack(spacing: 10) {
                        Text("MINUTES")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(3)
                            .foregroundStyle(Color.white.opacity(0.3))
                        DurationSelector(options: Self.durationOptions, selection: $selectedMinutes)
                    }
                    .opacity(isLocked ? 0 : 1)
                    .allowsHitTesting(!isLocked)
                    .accessibilityHidden(isLocked)
                    .padding(.bottom, 24)

                    Button(action: isLocked ? endSession : startSession) {
                        Text(isLocked ? "END SESSION" : "LOCK IN")
                    }
                    .buttonStyle(TitaniumButtonStyle(prominent: !isLocked))
                    .accessibilityHint(isLocked ? "Ends the focus session" : "Starts a focus session")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.impact(weight: .medium), trigger: isLocked)
        .sensoryFeedback(.success, trigger: completionCount)
        // Fires when the end timestamp passes. Cancelled automatically when the session
        // changes or the view goes away.
        .task(id: timing) {
            guard let timing else { return }
            while !Task.isCancelled && !timing.isFinished(at: .now) {
                try? await Task.sleep(for: .seconds(max(timing.endsAt.timeIntervalSinceNow, 0.05)))
            }
            guard !Task.isCancelled else { return }
            completeSession()
        }
        // The task above can be suspended in the background; re-check on return.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, let timing, timing.isFinished(at: .now) {
                completeSession()
            }
        }
    }

    // MARK: Session transitions

    private func startSession() {
        var duration = TimeInterval(selectedMinutes * 60)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-short-session") {
            duration = 5
        }
        #endif
        let session = SessionTiming(startedAt: .now, duration: duration)
        withAnimation(stateAnimation) {
            justCompleted = false
            timing = session
        }
    }

    private func endSession() {
        withAnimation(stateAnimation) {
            timing = nil
        }
    }

    private func completeSession() {
        guard let session = timing, session.isFinished(at: .now) else { return }
        completionCount += 1
        withAnimation(stateAnimation) {
            justCompleted = true
            timing = nil
        }
    }
}

private struct FocusBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.065), Color(white: 0.028)],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [Color.white.opacity(0.05), Color.clear],
                center: UnitPoint(x: 0.3, y: 0),
                startRadius: 0,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

private struct DurationSelector: View {
    let options: [Int]
    @Binding var selection: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { minutes in
                let selected = minutes == selection
                Button {
                    selection = minutes
                } label: {
                    Text("\(minutes)")
                        .font(.system(size: 15, weight: selected ? .semibold : .regular).monospacedDigit())
                        .foregroundStyle(selected ? Color.white : Color.white.opacity(0.42))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(Color.white.opacity(0.09))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                                    )
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(minutes) minutes")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.black.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

#Preview("Idle") { FocusView() }
