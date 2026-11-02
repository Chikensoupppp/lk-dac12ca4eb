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
- GitHub Actions run 41495360016: the scaled-text implementation passed the full workflow; the iPhone 16 Pro accessibility-size screenshot was inspected and shows visibly enlarged controls without clipping.
- GitHub Actions run 41496429343: full workflow passed, including a separate iPhone SE accessibility-size UI test for all duration controls and the primary button. The SE screenshot was inspected and shows no visible clipping.
- GitHub Actions run 41497821630: the full workflow passed with two unit tests, six UI tests including the debug-only Reduce Motion override and timer accessibility-value check, and the separate compact-device test. The exported Reduce Motion active-state image was inspected.
- GitHub Actions run 41499182488: the build and UI test step passed with the debug-only completion counter asserting exactly one completion after background expiry; the remaining device-capture steps were still running at last check.
- GitHub Actions run 41499712871: full workflow passed, including iPhone SE start/end and accessibility-size controls. The compact active-state screenshot was inspected with no visible clipping.
- GitHub Actions run 41501083353: full workflow passed, including selected-duration accessibility state and changing countdown accessibility-value assertions on standard and compact simulators.
- GitHub Actions run 41501970643: full workflow passed with idle, active, partially elapsed, completion, and large-text UI captures on iPhone SE and iPhone 16 Pro Max. The images were inspected; controls fit. The SE completion capture showed arc distortion during the transition. Commit 0193e7a disables parent animation for the timestamp-driven readout; run 41503492932 must verify the change.

## Not yet verified

- Manual VoiceOver, actual system-level Reduce Motion behavior, physical-device behavior, and profiling remain unverified. The debug override test does not establish that every animation is absent or verify operating-system settings.
- Screen Time authorization and signing.
- iPhone/Windows network pairing (Milestone 2).
- Actual Windows application/site restriction enforcement.
