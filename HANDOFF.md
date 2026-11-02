# Handoff

## Current state

The repository is bootstrapped with a Windows companion vertical slice and an iPhone SwiftUI shell. The companion intentionally binds to loopback and has no unauthenticated LAN mode.

## Important discoveries

- This Windows machine has .NET and GitHub CLI, but not a Swift/Xcode toolchain; iOS build verification must happen on macOS.
- iOS restriction behavior must be capability-gated through Screen Time APIs; unsupported controls must be surfaced as unavailable rather than simulated as active.

## Clock

`apps/ios/LockIn/Clock/` holds the reusable `CountdownClockView`. `FocusView.timing` (`SessionTiming?`) is the only session clock; the view renders from it. GitHub Actions run 41492862464 compiled it on Xcode 16.4 and passed two timing unit tests. Run 41493405111 also passed its UI tests but was still capturing simulator screenshots at the last check. Run 41493946600 includes new background-return testing and XCTest screenshot attachments. Inspect those runs before claiming screenshots or full workflow success. See `docs/WINDOWS_IOS_DEVELOPMENT.md`.

## Recommended next work

1. Add authenticated pairing using a short-lived code and a local encrypted credential store.
2. Add an integration test for start/stop/reconnect and clock drift.
3. Move workspace operations behind an explicit reversible profile interface.
4. On macOS, create the Xcode project target and verify Screen Time authorization on a physical iPhone.
