import SwiftUI

/// Matte black palette for the Focus screen. Sheets keep the Cream palette.
enum Matte {
    static let bgTop = Color(hex: 0x121417)
    static let bgMid = Color(hex: 0x0A0B0D)
    static let bgBottom = Color(hex: 0x08090A)
    static let text = Color(hex: 0xF3F5F8)
    /// Secondary labels. About 6.5:1 on the matte background.
    static let textSoft = Color(hex: 0x8E97A3)
    static let textDim = Color(hex: 0x7E8794)
    static let textQuiet = Color(hex: 0xC3CAD3)
    static let faceTop = Color(hex: 0x1D2025)
    static let faceMid = Color(hex: 0x121417)
    static let faceLow = Color(hex: 0x0C0D0F)
    static let track = Color(hex: 0x1B1F24)
    static let trackShade = Color(hex: 0x050607)
    static let tick = Color(hex: 0x323841)
    static let tickMajor = Color(hex: 0x5D6674)
    static let tray = Color(hex: 0x0B0C0E)
    static let chipHigh = Color(hex: 0x2E3238)
    static let chipLow = Color(hex: 0x1F2227)
    static let edge = Color(hex: 0x2B2F35)
    static let tip = Color(hex: 0xEAF5FF)
    static let latch = Color(hex: 0x96C8FF)

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

    private static let blue = [Color(hex: 0x2C5FA8), Color(hex: 0x4B3FA0), Color(hex: 0x1F7C86)]
    private static let warm = [Color(hex: 0xB8742C), Color(hex: 0xA8462F), Color(hex: 0x8A6A2A)]
    private static let gray = [Color(hex: 0x2A2D32), Color(hex: 0x25282C), Color(hex: 0x2A2D32)]

    private static let ice = [Color(hex: 0xB5DCFC), Color(hex: 0x6AAEF0), Color(hex: 0x4C8EE0)]
    private static let amber = [Color(hex: 0xFFD9A8), Color(hex: 0xF0A860), Color(hex: 0xD9822F)]
    private static let steel = [Color(hex: 0x9AA3AE), Color(hex: 0x6C7480), Color(hex: 0x565D68)]

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
        case .running: return 0.6
        case .lastMinute: return 0.75
        case .finished: return 1.15
        case .endedEarly: return 0.5
        }
    }

    /// Running states pull the glows in and slow the drift.
    var calm: Bool { self == .running || self == .lastMinute }
}
