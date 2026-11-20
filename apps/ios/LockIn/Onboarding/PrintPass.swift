import SwiftUI

/// The reveal on slides 3 and 4 (mock: docs/design/reveal-wipe.html): a sunflower ink band rolls
/// down the slide like a riso drum pass. Above the band the real numbers are already printed; below
/// it the cover is still waiting. Apply to the cover, which sits on top of Apple's report.
struct PrintPassWipe: ViewModifier, Animatable {
    /// 0: the cover is whole. 1: the band has rolled past the bottom.
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    private static let band: CGFloat = 66

    func body(content: Content) -> some View {
        content
            .mask {
                GeometryReader { g in
                    Rectangle()
                        .frame(height: max(0, g.size.height - edge(g.size.height)))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .overlay {
                GeometryReader { g in
                    let bump = sin(.pi * progress)
                    Rectangle()
                        .fill(Ink.sun)
                        .overlay(Grain(color: Ink.ink.opacity(0.22)))
                        // A blue edge printed a hair off-register, like a second riso ink.
                        .overlay(alignment: .top) { Rectangle().fill(Ink.blue).frame(height: 3).offset(y: -3) }
                        .frame(width: g.size.width + 120, height: Self.band)
                        .scaleEffect(x: 1, y: 0.8 + 0.4 * bump)
                        .rotationEffect(.degrees(-2 + 1.5 * bump))
                        .shadow(color: Ink.ink.opacity(0.18), radius: 9, y: 10)
                        .position(x: g.size.width / 2, y: edge(g.size.height))
                        .opacity(progress > 0 && progress < 1 ? 1 : 0)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
    }

    /// Where the band's middle is: from just above the top to just past the bottom.
    private func edge(_ height: CGFloat) -> CGFloat {
        CGFloat(progress) * (height + Self.band) - Self.band / 2
    }
}

extension Animation {
    /// The strong ease-in-out used for the print pass.
    static let printPass = Animation.timingCurve(0.77, 0, 0.175, 1, duration: 0.85)
}
