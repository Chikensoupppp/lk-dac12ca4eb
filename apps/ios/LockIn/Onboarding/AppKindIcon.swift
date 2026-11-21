import SwiftUI

/// A stand-in app icon for a kind of app, wherever the app shows apps that are not the user's own
/// (the pings on slide 5, the kinds on "What pulls you in?", the PC slides). An iOS-style squircle in
/// the colors that kind of app usually has, with one white symbol, so it reads as "a video app" or
/// "a chat app" at a glance. Brandon, 2026-11-20: the letter tiles ("M", "C") were hard to get.
/// Never a real app's logo or look; the user's own apps are always drawn by Apple (`Label(token)`).
struct AppKindIcon: View {
    enum Kind {
        case video, social, games, chat, shopping, news, web
    }

    let kind: Kind
    var size: CGFloat = 40

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
        shape
            .fill(LinearGradient(colors: kind.colors, startPoint: .top, endPoint: .bottom))
            .overlay {
                Image(systemName: kind.symbol)
                    .font(.system(size: size * kind.scale, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: kind == .video ? size * 0.03 : 0)
            }
            .overlay(shape.strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

extension AppKindIcon.Kind {
    var symbol: String {
        switch self {
        case .video: return "play.fill"
        case .social: return "heart.fill"
        case .games: return "gamecontroller.fill"
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .shopping: return "bag.fill"
        case .news: return "newspaper.fill"
        case .web: return "globe"
        }
    }

    /// Glyph size as a share of the icon (wide symbols a little smaller).
    var scale: CGFloat {
        switch self {
        case .games, .chat: return 0.42
        case .news: return 0.44
        default: return 0.48
        }
    }

    /// Top to bottom. Strong enough to read as app icons, a touch softer than neon.
    var colors: [Color] {
        switch self {
        case .video: return [Color(hex: 0xF0564E), Color(hex: 0xC92F2A)]
        case .social: return [Color(hex: 0xF4719B), Color(hex: 0xD63C78)]
        case .games: return [Color(hex: 0x9873F0), Color(hex: 0x6544C9)]
        case .chat: return [Color(hex: 0x4FA7F2), Color(hex: 0x2B76D2)]
        case .shopping: return [Color(hex: 0xFFA74D), Color(hex: 0xE77A1F)]
        case .news: return [Color(hex: 0x6B7689), Color(hex: 0x434C5C)]
        case .web: return [Color(hex: 0x58B6E8), Color(hex: 0x2F86C6)]
        }
    }
}
