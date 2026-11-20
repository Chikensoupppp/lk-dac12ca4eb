import ManagedSettings
import ManagedSettingsUI
import UIKit

/// SwipeLater's own block screen, instead of iOS's grey one (mock: docs/design/ios-block-screen.html,
/// option A "paper"). Apple fixes the layout: background, one picture, a title, a line of text and
/// up to two buttons, in the system font. Ours is the app's cream paper, the brain, and plain words:
/// "Instagram can wait. You're locked in. 18 min left." Locked mode (Plus) says when it opens and
/// has no second button. The words live in `ShieldNote` (Shared) so they can be tested.
final class LockInShield: ShieldConfigurationDataSource {
    private static let paper = UIColor(red: 0.906, green: 0.910, blue: 0.890, alpha: 1)
    private static let ink = UIColor(red: 0.106, green: 0.106, blue: 0.106, alpha: 1)

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make(name: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        make(name: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        make(name: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        make(name: webDomain.domain)
    }

    private func make(name: String?) -> ShieldConfiguration {
        let session = ShieldNote.current()
        let locked = session?.locked == true
        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: Self.paper,
            icon: UIImage(named: "BrainExact"),
            title: .init(text: ShieldNote.title(appName: name, session: session), color: Self.ink),
            subtitle: .init(text: ShieldNote.subtitle(session: session), color: Self.ink.withAlphaComponent(0.65)),
            primaryButtonLabel: .init(text: ShieldNote.primaryButton, color: Self.paper),
            primaryButtonBackgroundColor: Self.ink,
            // Locked mode has no way out, so no second button.
            secondaryButtonLabel: locked ? nil : .init(text: ShieldNote.secondaryButton, color: Self.ink.withAlphaComponent(0.55))
        )
    }
}
