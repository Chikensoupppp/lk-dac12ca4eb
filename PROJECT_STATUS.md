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
- GitHub Actions run 41493405111: build and test step passed, including UI start/end and natural completion. Screenshot capture was still running at the last check; the full workflow is not yet verified.

## Not yet verified

- Background-return test, simulator screenshots, visual tuning, accessibility and physical-device behavior remain unverified.
- Screen Time authorization and signing.
- iPhone/Windows network pairing (Milestone 2).
- Actual Windows application/site restriction enforcement.
