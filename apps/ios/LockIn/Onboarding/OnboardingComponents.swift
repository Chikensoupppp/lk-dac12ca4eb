import SwiftUI

/// Accent colors for the first-run flow. They sit on the matte black base.
enum OB {
    static let ice = Color(hex: 0x9CC9F5)
    static let sage = Color(hex: 0x8FD3B0)
    static let warm = Color(hex: 0xF2B27A)
    static let ink = Color(hex: 0x0A0B0D)
    static let panel = Color(hex: 0x181A1E)
    static let soft = Color(hex: 0xD2D4D9)
}

/// Fades and lifts a view in, one after another. Skipped when motion is limited.
struct StaggerIn: ViewModifier {
    let index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    func body(content: Content) -> some View {
        let reduce = effectiveReduceMotion(systemReduceMotion)
        content
            .opacity(shown || reduce ? 1 : 0)
            .offset(y: shown || reduce ? 0 : 24)
            .onAppear {
                guard !reduce else { shown = true; return }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(Double(index) * 0.07)) { shown = true }
            }
    }
}

extension View {
    func staggerIn(_ index: Int) -> some View { modifier(StaggerIn(index: index)) }
}

/// One first-run screen: progress bars, headline, optional line under it, content, buttons.
struct OBScaffold<Content: View>: View {
    let step: Int
    let title: String
    let subtitle: String?
    let subtitleLarge: Bool
    let primaryTitle: String
    let primaryEnabled: Bool
    let primaryAction: () -> Void
    let secondaryTitle: String?
    let secondaryAction: (() -> Void)?
    let content: Content

    init(step: Int, title: String, subtitle: String? = nil, subtitleLarge: Bool = false,
         primaryTitle: String, primaryEnabled: Bool = true, primaryAction: @escaping () -> Void,
         secondaryTitle: String? = nil, secondaryAction: (() -> Void)? = nil,
         @ViewBuilder content: () -> Content) {
        self.step = step
        self.title = title
        self.subtitle = subtitle
        self.subtitleLarge = subtitleLarge
        self.primaryTitle = primaryTitle
        self.primaryEnabled = primaryEnabled
        self.primaryAction = primaryAction
        self.secondaryTitle = secondaryTitle
        self.secondaryAction = secondaryAction
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                ForEach(0..<OnboardingFlow.stepCount, id: \.self) { i in
                    Capsule().fill(i < step ? Matte.text : Matte.edge).frame(height: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .accessibilityHidden(true)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(title)
                        .font(Cream.rounded(40, .heavy))
                        .kerning(-1.2)
                        .lineSpacing(-3)
                        .foregroundStyle(Matte.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .staggerIn(0)
                    if let subtitle {
                        Text(subtitle)
                            .font(subtitleLarge ? Cream.rounded(32, .heavy) : Cream.rounded(20, .medium))
                            .kerning(subtitleLarge ? -0.8 : 0)
                            .foregroundStyle(subtitleLarge ? OB.ice : OB.soft)
                            .fixedSize(horizontal: false, vertical: true)
                            .staggerIn(1)
                    }
                    content
                        .padding(.top, 10)
                        .staggerIn(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 36)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 4) {
                Button(action: primaryAction) { Text(primaryTitle) }
                    .buttonStyle(MatteButtonStyle(prominent: true))
                    .disabled(!primaryEnabled)
                    .opacity(primaryEnabled ? 1 : 0.4)
                if let secondaryTitle, let secondaryAction {
                    Button(action: secondaryAction) {
                        Text(secondaryTitle)
                            .font(Cream.rounded(16, .medium))
                            .foregroundStyle(Matte.textQuiet)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .background {
            LinearGradient(colors: [Matte.bgTop, Matte.bgMid, Matte.bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
    }
}

/// A tilted note, like a sticker on the screen.
struct StickerNote: View {
    let text: String
    var color: Color = OB.warm
    var tilt: Double = -4

    var body: some View {
        Text(text)
            .font(Cream.rounded(15, .bold))
            .foregroundStyle(OB.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color))
            .rotationEffect(.degrees(tilt))
            .accessibilityHidden(true)
    }
}

/// A wide single-choice row. The chosen row lights up and tilts a little.
struct ChoiceRow: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(Cream.rounded(20, .bold))
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 24))
                }
            }
            .foregroundStyle(selected ? OB.ink : Matte.text)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 66)
            .background(RoundedRectangle(cornerRadius: 33, style: .continuous).fill(selected ? OB.ice : OB.panel))
            .overlay(RoundedRectangle(cornerRadius: 33, style: .continuous).strokeBorder(selected ? Color.clear : Matte.edge, lineWidth: 1.5))
            .rotationEffect(.degrees(selected ? -1.5 : 0))
            .scaleEffect(selected ? 1.03 : 1)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: selected)
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A square-ish multi-choice tile with an icon. Picked tiles take their own color and tilt.
struct ChoiceTile: View {
    let title: String
    let symbol: String
    let color: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                Image(systemName: symbol)
                    .font(.system(size: 28, weight: .semibold))
                    .padding(16)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(14)
                        .transition(.scale)
                }
                Text(title)
                    .font(Cream.rounded(19, .bold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(16)
            }
            .foregroundStyle(Matte.text)
            .frame(maxWidth: .infinity, minHeight: 104)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(selected ? color : OB.panel))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(selected ? color : Matte.edge, lineWidth: 1.5))
            .rotationEffect(.degrees(selected ? -1 : 0))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: selected)
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A rounded app-style tile that holds an SF Symbol. Used for drawings, not for real apps.
struct SymbolTile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 68
    var tilt: Double = 0

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(color)
            .frame(width: size, height: size)
            .overlay(Image(systemName: symbol).font(.system(size: size * 0.42, weight: .semibold)).foregroundStyle(.white))
            .rotationEffect(.degrees(tilt))
    }
}
