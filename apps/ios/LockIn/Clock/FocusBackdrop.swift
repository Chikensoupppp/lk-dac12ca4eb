import SwiftUI

/// Flat matte black backdrop, the same dark gradient as the welcome slides. No glows, dust or vignette.
/// The ring color on the clock still shows the session mood.
struct FocusBackdrop: View {
    let timing: SessionTiming?
    let flash: FocusMood?

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Matte.bgTop, location: 0),
                .init(color: Matte.bgMid, location: 0.6),
                .init(color: Matte.bgBottom, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Warm cream backdrop kept for the sheets (Restrictions, PC).
struct CreamBackdrop: View {
    var body: some View {
        LinearGradient(colors: [Cream.top, Cream.bottom], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}
