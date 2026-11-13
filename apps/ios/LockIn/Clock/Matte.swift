import SwiftUI

/// Focus screen palette. Since 2026-11-13 it is the riso print look of the slides: grey
/// newsprint, riso black text, a riso Medium Blue ring (`Ink` in Onboarding/Print.swift).
/// The name stays "Matte" so every screen that uses it changes together.
enum Matte {
    static let bgTop = Color(hex: 0xEAEBE6)
    static let bgMid = Color(hex: 0xE7E8E3)
    static let bgBottom = Color(hex: 0xE2E3DE)
    static let text = Color(hex: 0x1B1B1B)
    /// Secondary labels. About 5.5:1 on newsprint.
    static let textSoft = Color(hex: 0x575A55)
    static let textDim = Color(hex: 0x5F625C)
    static let textQuiet = Color(hex: 0x2C2E2A)
    static let faceTop = Color(hex: 0xF7F7F3)
    static let faceMid = Color(hex: 0xF0F1EC)
    static let faceLow = Color(hex: 0xE6E7E1)
    static let track = Color(hex: 0xD8DAD2)
    static let trackShade = Color(hex: 0xC8CAC1)
    static let tick = Color(hex: 0xB8BBB1)
    static let tickMajor = Color(hex: 0x7A7E75)
    static let tray = Color(hex: 0xF3F4F0)
    static let chipHigh = Color(hex: 0x2A2B28)
    static let chipLow = Color(hex: 0x1B1B1B)
    static let edge = Color(hex: 0xC4C6BD)
    static let tip = Color(hex: 0xFFB511)
    static let latch = Color(hex: 0x3255A4)
    /// Riso Medium Blue: the ring, the main button, Locked mode on.
    static let riso = Color(hex: 0x3255A4)

    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Cream.rounded(size, weight)
    }
}

/// True when decorative motion should be off: system Reduce Motion or Low Power Mode.
func motionLimited(_ systemReduceMotion: Bool) -> Bool {
    #if DEBUG
    // The CI simulator draws on the CPU. UI tests turn the live background off so they stay fast.
    if ProcessInfo.processInfo.arguments.contains("-ui-testing-calm-background") { return true }
    #endif
    return effectiveReduceMotion(systemReduceMotion) || ProcessInfo.processInfo.isLowPowerModeEnabled
}

/// What the Focus screen feels like right now. Drives glow color, glow strength and ring color.
enum FocusMood: Equatable {
    case idle, running, lastMinute, finished, endedEarly

    static func resolve(timing: SessionTiming?, flash: FocusMood?, now: Date) -> FocusMood {
        if let timing {
            return timing.remaining(at: now) <= 60 ? .lastMinute : .running
        }
        return flash ?? .idle
    }

    private static let blue = [Color(hex: 0x3A7BD8), Color(hex: 0x6A4FD6), Color(hex: 0x229BA6)]
    private static let warm = [Color(hex: 0xB8742C), Color(hex: 0xA8462F), Color(hex: 0x8A6A2A)]
    private static let gray = [Color(hex: 0x2A2D32), Color(hex: 0x25282C), Color(hex: 0x2A2D32)]

    private static let ice = [Color(hex: 0x5C7DC6), Color(hex: 0x4366B2), Color(hex: 0x3255A4)]
    private static let amber = [Color(hex: 0xFFD36B), Color(hex: 0xFFC23A), Color(hex: 0xF0A800)]
    private static let steel = [Color(hex: 0xA9ACA5), Color(hex: 0x8E918A), Color(hex: 0x777A73)]

    var glows: [Color] {
        switch self {
        case .lastMinute: return Self.warm
        case .endedEarly: return Self.gray
        default: return Self.blue
        }
    }

    var ring: [Color] {
        switch self {
        case .lastMinute: return Self.amber
        case .endedEarly: return Self.steel
        default: return Self.ice
        }
    }

    var glowAmount: Double {
        switch self {
        case .idle: return 1
        case .running: return 0.9
        case .lastMinute: return 1.0
        case .finished: return 1.15
        case .endedEarly: return 0.6
        }
    }

    /// Running states pull the glows in and slow the drift.
    var calm: Bool { self == .running || self == .lastMinute }
}
