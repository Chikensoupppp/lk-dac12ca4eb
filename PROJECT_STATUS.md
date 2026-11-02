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
- GitHub Actions run 41493946600: two unit tests and three UI tests passed, including returning after the session expired in the background.
- GitHub Actions run 41494428865: two unit tests and five UI tests passed, covering return before and after expiry, natural completion, start/end, and control reachability under a large-text launch setting. Test screenshots were exported and inspected for active, partially elapsed, completed, and large-text launch states on iPhone 16 Pro.

## Not yet verified

- The large-text screenshot looks similar to the default because the interface uses fixed-size fonts; actual Dynamic Type scaling has not been established. VoiceOver, Reduce Motion behavior, physical-device behavior, and profiling remain unverified.
- Screen Time authorization and signing.
- iPhone/Windows network pairing (Milestone 2).
- Actual Windows application/site restriction enforcement.
