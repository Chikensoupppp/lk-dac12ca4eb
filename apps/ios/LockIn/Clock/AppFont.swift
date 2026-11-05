import CoreText
import SwiftUI
import UIKit

/// The app's one typeface: Onest (SIL Open Font License, see Resources/Fonts/Onest-OFL.txt).
/// It is a variable font, so the weight axis gives every weight from one file.
/// If the file is missing, SwiftUI quietly falls back to the system font.
enum AppFont {
    static let family = "Onest"

    /// Call once at launch, before the first view draws.
    static func register() {
        guard let url = Bundle.main.url(forResource: "Onest", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(family, size: size).weight(weight)
    }

    /// Navigation bar titles and the QR scanner are UIKit-drawn, so they need the font set directly.
    static func styleNavigationBar() {
        let traits: [UIFontDescriptor.TraitKey: Any] = [.weight: UIFont.Weight.semibold]
        let descriptor = UIFontDescriptor(fontAttributes: [.family: family, .traits: traits])
        UINavigationBar.appearance().titleTextAttributes = [.font: UIFont(descriptor: descriptor, size: 17)]
    }
}
