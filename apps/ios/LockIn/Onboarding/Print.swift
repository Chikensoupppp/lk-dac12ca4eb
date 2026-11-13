import SwiftUI

/// The "printed" look of the first-run flow (docs/ONBOARDING_V2.md). Flat inks, and every slide is
/// a different paper object: a poster, a receipt, stickers, a notebook, a contract, a member card.
///
/// Calm palette (2026-11-13): colors are softened, and only the first slide has a full colored
/// background. Every other slide sits on paper and keeps its color on the object.
enum Ink {
    static let paper = Color(hex: 0xF2ECE1)
    static let receipt = Color(hex: 0xF6F1E7)
    static let notebook = Color(hex: 0xFBF8F1)
    static let ink = Color(hex: 0x15120F)
    static let orange = Color(hex: 0xE8845F)   // soft coral
    static let blue = Color(hex: 0x4F63D8)
    static let navy = Color(hex: 0x0E1640)
    static let red = Color(hex: 0xD25A44)
    static let soft = Color(hex: 0x6E675E)
    static let night = Color(hex: 0x0A0B0D)
}

/// Apple's own faces, so no font files ship: compressed black for headlines, monospaced for
/// printed details, Marker Felt for handwriting. Fixed sizes, like the rest of the app (`AppFont`);
/// every screen scrolls, so large text never hides a button.
enum PrintFont {
    static func head(_ size: CGFloat) -> Font { .system(size: size, weight: .black).width(.compressed) }
    static func bold(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy).width(.condensed) }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font { .system(size: size, weight: weight) }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func hand(_ size: CGFloat) -> Font { .custom("MarkerFelt-Wide", fixedSize: size) }
}

/// One printed slide: progress bars, Back, a headline, the content, and the buttons.
struct PrintScaffold<Content: View>: View {
    let step: Int
    var background: Color = Ink.paper
    var foreground: Color = Ink.ink
    var title: String?
    var titleSize: CGFloat = 52
    var grain = false
    var primaryTitle: String?
    var primaryEnabled = true
    var primaryAction: () -> Void = {}
    /// Replaces the plain button (the hold-to-sign button).
    var primaryView: AnyView?
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?
    var footer: AnyView?
    @ViewBuilder var content: () -> Content
    @Environment(\.obBack) private var back

    /// Small phones (iPhone SE, mini) get a smaller headline so the slide content fits.
    private var shownTitleSize: CGFloat {
        UIScreen.main.bounds.height < 700 ? titleSize * 0.8 : titleSize
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                ForEach(0..<OnboardingFlow.stepCount, id: \.self) { i in
                    Capsule().fill(foreground.opacity(i < step ? 1 : 0.18)).frame(height: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .accessibilityHidden(true)

            HStack {
                if let back {
                    Button(action: back) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(foreground)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Back")
                }
                Spacer()
            }
            .frame(height: 44)
            .padding(.horizontal, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let title {
                        Text(title.uppercased())
                            .font(PrintFont.head(shownTitleSize))
                            .lineSpacing(-shownTitleSize * 0.12)
                            .foregroundStyle(foreground)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityLabel(title)
                            .staggerIn(0)
                    }
                    content()
                        .staggerIn(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .scrollBounceBehavior(.basedOnSize)
            // A soft fade where the slide meets the buttons, so cut-off content reads as
            // "scroll for more" instead of slipping under the button.
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [background.opacity(0), background], startPoint: .top, endPoint: .bottom)
                    .frame(height: 28)
                    .allowsHitTesting(false)
            }

            VStack(spacing: 2) {
                if let primaryView {
                    primaryView
                } else if let primaryTitle {
                    Button(action: primaryAction) { Text(primaryTitle) }
                        .buttonStyle(PrintButtonStyle(fill: foreground, text: background))
                        .disabled(!primaryEnabled)
                        .opacity(primaryEnabled ? 1 : 0.35)
                }
                if let secondaryTitle, let secondaryAction {
                    Button(action: secondaryAction) {
                        Text(secondaryTitle)
                            .font(PrintFont.body(15))
                            .foregroundStyle(foreground.opacity(0.65))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                if let footer { footer }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .background {
            ZStack {
                background
                if grain { Grain(color: Ink.ink.opacity(0.09)) }
            }
            .ignoresSafeArea()
        }
    }
}

/// A pill button in the slide's ink.
struct PrintButtonStyle: ButtonStyle {
    var fill: Color = Ink.ink
    var text: Color = Ink.paper

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PrintFont.bold(19))
            .tracking(2)
            .foregroundStyle(text)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(Capsule().fill(fill))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A rubber stamp: a bordered word, slightly turned.
struct Stamp: View {
    let text: String
    var color: Color = Ink.red
    var size: CGFloat = 22
    var tilt: Double = -8
    var fill: Color? = Ink.receipt.opacity(0.92)

    var body: some View {
        Text(text.uppercased())
            .font(PrintFont.head(size))
            .tracking(1)
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 8).fill(fill ?? .clear))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color, lineWidth: 3.5))
            .rotationEffect(.degrees(tilt))
            .accessibilityLabel(text)
    }
}

/// Paper with a torn, saw-tooth bottom edge, like a receipt.
struct ReceiptEdge: Shape {
    var tooth: CGFloat = 14
    var depth: CGFloat = 9

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - depth))
        var x = rect.maxX
        var down = true
        while x > rect.minX {
            x = max(rect.minX, x - tooth / 2)
            p.addLine(to: CGPoint(x: x, y: down ? rect.maxY : rect.maxY - depth))
            down.toggle()
        }
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - depth))
        p.closeSubpath()
        return p
    }
}

/// A dotted line of printed fill between a label and a value: "Video app ........ 2h 31m".
struct ReceiptRow: View {
    let label: String
    let value: String
    var bold = false
    var color: Color = Ink.ink

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label).lineLimit(1)
            Text(String(repeating: ".", count: 60))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(color.opacity(0.35))
                .layoutPriority(-1)
            Text(value).lineLimit(1).layoutPriority(1)
        }
        .font(PrintFont.mono(bold ? 18 : 13, bold ? .heavy : .medium))
        .foregroundStyle(color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }
}

/// A light dot grain over the paper, like a riso print.
struct Grain: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            var dots = Path()
            var y: CGFloat = 2
            while y < size.height {
                var x: CGFloat = (Int(y / 5) % 2 == 0) ? 2 : 4.5
                while x < size.width {
                    dots.addEllipse(in: CGRect(x: x, y: y, width: 1.4, height: 1.4))
                    x += 5
                }
                y += 5
            }
            context.fill(dots, with: .color(color))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A short pause that stops early when the view goes away. False means stop.
func printPause(_ seconds: Double) async -> Bool {
    do {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        return true
    } catch {
        return false
    }
}
