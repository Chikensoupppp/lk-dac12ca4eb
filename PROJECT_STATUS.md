# Project status

Updated: 2026-11-02

## Implemented

- Private GitHub repository and permanent local checkout.
- Shared project instructions and product documents.
- Versioned session protocol with explicit lifecycle and capability reporting.
- Windows companion service with loopback health, session start, and session stop endpoints.
- SwiftUI iPhone shell for selecting duration and starting/stopping a local session model.
- Titanium countdown clock (`apps/ios/LockIn/Clock/`) driven by a single end-timestamp (`SessionTiming`).
- XcodeGen project and macOS simulator CI; UI tests and screenshot capture are included.

## Verified

- `dotnet build apps/windows-companion/LockIn.Companion.csproj`
- Live HTTP check: `/health`, `/session/start`, and `/session/stop` on `127.0.0.1:47821`
- GitHub Actions run 41492862464: Xcode 16.4 generated the project, compiled for iOS Simulator, and passed two unit tests.
- GitHub Actions run 41493405111: full workflow passed, including UI start/end and natural completion. Idle simulator screenshots were captured and visually inspected for iPhone SE (3rd generation), iPhone 16, and iPhone 16 Pro Max. No clipping was observed in those idle images.

## Not yet verified

- New background-return tests, active/completed screenshots, accessibility sizing, VoiceOver, motion behavior, and physical-device behavior remain unverified.
- Screen Time authorization and signing.
- iPhone/Windows network pairing (Milestone 2).
- Actual Windows application/site restriction enforcement.
