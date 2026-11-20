import SwiftUI

/// How the loading covers on slides 3 and 4 leave for the real slide under them (mock:
/// docs/design/reveal-load.html): the cover fades, blurs and grows a touch, as if lifted toward
/// you, while Apple's report underneath stays still. Apply to the cover, which sits on top of the
/// report. With Reduce Motion it only fades.
struct CoverLift: ViewModifier {
    let lifted: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        let move = lifted && !reduceMotion
        content
            .blur(radius: move ? 10 : 0)
            .scaleEffect(move ? 1.03 : 1)
            .opacity(lifted ? 0 : 1)
    }
}

extension View {
    func coverLift(_ lifted: Bool, reduceMotion: Bool) -> some View {
        modifier(CoverLift(lifted: lifted, reduceMotion: reduceMotion))
    }
}

extension Animation {
    /// A strong ease-out: the cover starts leaving at once, then settles.
    static let coverLift = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.55)
}
