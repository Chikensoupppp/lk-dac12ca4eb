import SwiftUI

/// Primary button in matte titanium. `prominent == false` is the quiet in-session variant.
struct TitaniumButtonStyle: ButtonStyle {
    var prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        TitaniumButtonBody(configuration: configuration, prominent: prominent)
    }
}

private struct TitaniumButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let prominent: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var labelSize: CGFloat = 16

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        configuration.label
            .font(.system(size: labelSize, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .tracking(4)
            .foregroundStyle(prominent ? Color(white: 0.07) : Color(white: 0.70))
            .frame(maxWidth: .infinity, minHeight: 60)
            .background { plate(shape) }
            .contentShape(shape)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.35), value: prominent)
    }

    @ViewBuilder
    private func plate(_ shape: RoundedRectangle) -> some View {
        if prominent {
            shape
                .fill(LinearGradient(
                    colors: [ClockTone.metal(0.88), ClockTone.metal(0.68)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .overlay(
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.75), Color.black.opacity(0.35)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                )
                .shadow(color: Color.black.opacity(0.55), radius: 12, x: 0, y: 6)
        } else {
            shape
                .fill(Color.white.opacity(0.04))
                .overlay(shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        }
    }
}
