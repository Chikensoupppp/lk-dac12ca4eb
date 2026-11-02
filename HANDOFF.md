# Handoff

## Current state

The repository is bootstrapped with a Windows companion vertical slice and an iPhone SwiftUI shell. The companion intentionally binds to loopback and has no unauthenticated LAN mode.

## Important discoveries

- This Windows machine has .NET and GitHub CLI, but not a Swift/Xcode toolchain; iOS build verification must happen on macOS.
- iOS restriction behavior must be capability-gated through Screen Time APIs; unsupported controls must be surfaced as unavailable rather than simulated as active.

## Clock

`apps/ios/LockIn/Clock/` holds the reusable `CountdownClockView`. `FocusView.timing` (`SessionTiming?`) is the only session clock; the view renders from it. GitHub Actions run 41493405111 passed and produced idle screenshots on iPhone SE (3rd generation), iPhone 16, and iPhone 16 Pro Max; all three were visually inspected, with no visible clipping. Run 41494428865 passed two unit tests and five UI tests, including background return before and after expiry. Runs 41495360016 and 41496429343 passed after Dynamic Type changes; iPhone 16 Pro and iPhone SE large-text images were inspected and show enlarged, unclipped controls. VoiceOver remains unverified. See `docs/WINDOWS_IOS_DEVELOPMENT.md`.

## Recommended next work

1. Run 41496429343 passed the full workflow and compact iPhone SE accessibility-size UI test; its exported screenshot was inspected and shows no visible clipping.
2. Download run 41495360016 with `./scripts/ios-ci.ps1 -Action download -RunId 41495360016` if needed. `test-attachments/manifest.json` maps screenshots to test states.
3. Run 41497590045 failed because SwiftUI's Reduce Motion environment value is read-only. Commit e18801f replaced that injection with a debug-only override; run 41497821630 completed successfully with two unit tests, six UI tests, and the compact-device test. The Reduce Motion active-state screenshot was inspected. This is not a manual VoiceOver test, and actual system-level Reduce Motion behavior still needs verification. The completion image in run 41494428865 was captured during a transition. Session data is in memory only.
4. Run 41499182488 tests duplicate-completion behavior using a debug-only completion counter; inspect its result before claiming the race is covered. Improve compact-device active-state coverage and update status from actual CI evidence. Neither Xcode Preview nor physical-device signing/install has been verified.
5. Later: authenticated pairing, clock-drift and reconnect testing, reversible Windows workspace profiles, and physical-device Screen Time authorization. These are separate from the present iOS clock milestone.

## Git and collaboration

The work is committed and pushed to `origin/ios/native-clock-ci`; it has not been merged into the default branch. Read `AGENTS.md`, `PROJECT_STATUS.md`, and Git status before editing. Preserve other agents' work. The private repository has no Apple signing secrets configured here; do not upload or publish without authorization.
