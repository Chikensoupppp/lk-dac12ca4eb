import SwiftUI

/// Soft pill button. `prominent` is butter-caramel; otherwise a quiet cream outline.
struct CreamButtonStyle: ButtonStyle {
    var prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        CreamButtonBody(configuration: configuration, prominent: prominent)
    }
}

private struct CreamButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let prominent: Bool

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { effectiveReduceMotion(systemReduceMotion) }
    @ScaledMetric(relativeTo: .body) private var labelSize: CGFloat = 16

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        configuration.label
            .font(Cream.rounded(labelSize, .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .tracking(2)
            .foregroundStyle(prominent ? Cream.butterText : Cream.quietText)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background { plate(shape) }
            .contentShape(shape)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: prominent)
    }

    @ViewBuilder
    private func plate(_ shape: RoundedRectangle) -> some View {
        if prominent {
            shape
                .fill(Cream.butter)
                .overlay(alignment: .bottom) {
                    shape.strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                }
                .shadow(color: Cream.shadow.opacity(0.35), radius: 10, x: 0, y: 6)
        } else {
            shape
                .fill(Cream.quietFill)
                .overlay(shape.strokeBorder(Cream.edge, lineWidth: 2))
        }
    }
}
