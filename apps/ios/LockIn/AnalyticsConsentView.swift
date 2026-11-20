import SwiftUI

/// The one-time "Help improve SwipeLater?" screen, shown over the first launch in the EU, EEA, UK
/// and Switzerland (`Analytics.needsConsentPrompt`). Yes and No are the same size and weight, so
/// neither is nudged. Nothing is sent before an answer. Printed look, like the intro.
struct AnalyticsConsentView: View {
    let answered: (Bool) -> Void

    var body: some View {
        ZStack {
            Ink.paper.ignoresSafeArea()
            Grain(color: Ink.ink.opacity(0.09)).ignoresSafeArea().allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                Text("HELP IMPROVE\nSWIPELATER?")
                    .font(PrintFont.head(UIScreen.main.bounds.height < 700 ? 44 : 56))
                    .foregroundStyle(Ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("Share anonymous usage stats: which screens you reach and what you tap. Never your apps, your Screen Time or who you are.")
                    .font(PrintFont.mono(15))
                    .foregroundStyle(Ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 18)
                Text("Change it anytime in the apps list.")
                    .font(PrintFont.mono(12))
                    .foregroundStyle(Ink.soft)
                    .padding(.top, 10)
                Spacer(minLength: 0)
                VStack(spacing: 12) {
                    Button { answered(true) } label: { Text("YES, SHARE") }
                        .buttonStyle(PrintButtonStyle())
                        .accessibilityIdentifier("analytics-yes")
                    Button { answered(false) } label: { Text("NO THANKS") }
                        .buttonStyle(PrintButtonStyle(fill: Ink.receipt, text: Ink.ink))
                        .overlay(Capsule().stroke(Ink.ink, lineWidth: 2))
                        .accessibilityIdentifier("analytics-no")
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(.light)
    }
}
