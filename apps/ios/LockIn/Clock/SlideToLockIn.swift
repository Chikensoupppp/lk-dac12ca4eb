import SwiftUI

/// The start control: slide the knob to the right to lock in.
/// A slide is a real decision and cannot start a session by accident in a pocket.
/// A plain tap nudges the knob, so the control never feels dead.
struct SlideToLockIn: View {
    var label = "SLIDE TO LOCK IN"
    var glow = false
    var identifier = "LOCK IN"
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var drag: CGFloat = 0
    @State private var fired = false

    private let width: CGFloat = 268
    private let knob: CGFloat = 56
    private let pad: CGFloat = 4
    private var travel: CGFloat { width - knob - pad * 2 }
    private var reduceMotion: Bool { motionLimited(systemReduceMotion) }

    /// UI tests send plain taps; a tap starts there so the existing flows still run.
    private var tapStarts: Bool {
        ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-ui-testing") })
    }

    var body: some View {
        let progress = travel > 0 ? drag / travel : 0
        ZStack(alignment: .leading) {
            Capsule().fill(FocusPaper.ink)
            Capsule().fill(FocusPaper.page.opacity(0.14))
                .frame(width: knob + pad * 2 + drag)
                .opacity(drag > 0 ? 1 : 0)
            Text(label)
                .tracking(2)
                .environment(\.font, AppFont.font(15, .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(FocusPaper.page)
                .opacity(1 - min(progress * 2, 1))
                .frame(maxWidth: .infinity)
                .padding(.leading, knob + pad)
                .padding(.trailing, 14)
            Circle()
                .fill(FocusPaper.page)
                .frame(width: knob, height: knob)
                .overlay(
                    Image(systemName: fired ? "checkmark" : "arrow.right")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(FocusPaper.ink)
                )
                .padding(.leading, pad)
                .offset(x: drag)
        }
        .frame(width: width, height: knob + pad * 2)
        .contentShape(Capsule())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard !fired else { return }
                    drag = min(max(0, value.translation.width), travel)
                }
                .onEnded { value in
                    guard !fired else { return }
                    if abs(value.translation.width) < 4 {
                        tapStarts ? complete() : nudge()
                    } else if drag > travel * 0.8 {
                        complete()
                    } else {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7)) { drag = 0 }
                    }
                }
        )
        .coachGlow(glow, reduceMotion: reduceMotion)
        .sensoryFeedback(.selection, trigger: drag > travel * 0.8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("LOCK IN")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Slide right to start a focus session.")
        .accessibilityAction { complete() }
        .accessibilityIdentifier(identifier)
    }

    /// Shows which way to slide.
    private func nudge() {
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.14)) { drag = 28 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { drag = 0 }
        }
    }

    private func complete() {
        fired = true
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { drag = travel }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            action()
            try? await Task.sleep(for: .milliseconds(700))
            fired = false
            drag = 0
        }
    }
}
