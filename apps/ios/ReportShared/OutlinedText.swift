import SwiftUI

/// Big numbers printed as sticker type (docs/design/type-color.html, orange O1/O2): a colored fill
/// over an ink outline, with an optional ink drop shadow. Shared by the app and the report
/// extension, which cannot use the app's code.
struct OutlinedText: View {
    let text: String
    let font: Font
    var fill: Color = OutlinedText.orange
    var ink = Color(red: 0.106, green: 0.106, blue: 0.106)
    var outline: CGFloat = 2
    var drop: CGFloat = 4

    /// Riso orange: the color for the numbers that matter.
    static let orange = Color(red: 1, green: 0.424, blue: 0.184)
    /// A deeper orange for small text, so it stays readable on paper.
    static let orangeDeep = Color(red: 0.91, green: 0.353, blue: 0.118)

    var body: some View {
        let base = Text(text).font(font).lineLimit(1).minimumScaleFactor(0.5)
        ZStack {
            if drop > 0 {
                base.foregroundStyle(ink).offset(x: drop, y: drop)
            }
            // Eight ink copies around the fill make the outline.
            ForEach(0..<8, id: \.self) { i in
                let a = Double(i) * .pi / 4
                base.foregroundStyle(ink).offset(x: outline * CGFloat(cos(a)), y: outline * CGFloat(sin(a)))
            }
            base.foregroundStyle(fill)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}
