import SwiftUI

/// Main buttons. `prominent` is a riso-blue plate with newsprint text; otherwise a quiet paper plate with an edge.
struct MatteButtonStyle: ButtonStyle {
    var prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        MatteButtonBody(configuration: configuration, prominent: prominent)
    }
}

private struct MatteButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let prominent: Bool

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { effectiveReduceMotion(systemReduceMotion) }
    @ScaledMetric(relativeTo: .body) private var labelSize: CGFloat = 16

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        configuration.label
            .font(Cream.rounded(labelSize, .heavy))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .tracking(2)
            .foregroundStyle(prominent ? Color(hex: 0xF3F4F0) : Matte.textQuiet)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background { plate(shape) }
            .contentShape(shape)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: prominent)
    }

    @ViewBuilder
    private func plate(_ shape: RoundedRectangle) -> some View {
        if prominent {
            shape
                .fill(Matte.riso)
                // Two-ink riso look: a thin sunflower edge printed slightly off-register.
                .shadow(color: Matte.tip.opacity(0.9), radius: 0, x: 3, y: 3)
        } else {
            shape
                .fill(Matte.tray)
                .overlay(shape.strokeBorder(Matte.edge, lineWidth: 1.5))
        }
    }
}

/// Plays once each time `trigger` changes: a bright edge runs around the button
/// and one ring spreads out from it. Skipped when motion is limited.
struct LatchEffect: View {
    let trigger: Int
    let enabled: Bool

    @State private var edge: CGFloat = 0
    @State private var edgeOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.4
    @State private var ringOpacity: Double = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .trim(from: 0, to: edge)
                .stroke(Matte.latch, lineWidth: 3)
                .shadow(color: Matte.latch.opacity(0.8), radius: 6)
                .opacity(edgeOpacity)
            Circle()
                .strokeBorder(Matte.latch.opacity(0.8), lineWidth: 2)
                .frame(width: 60, height: 60)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) { _, _ in
            guard enabled else { return }
            Task { @MainActor in
                var reset = Transaction()
                reset.disablesAnimations = true
                withTransaction(reset) { edge = 0; edgeOpacity = 1; ringScale = 0.4; ringOpacity = 0.9 }
                await Task.yield()
                withAnimation(.linear(duration: 0.5)) { edge = 1 }
                withAnimation(.easeOut(duration: 0.4).delay(0.5)) { edgeOpacity = 0 }
                withAnimation(.easeOut(duration: 1.0)) { ringScale = 14; ringOpacity = 0 }
            }
        }
    }
}
