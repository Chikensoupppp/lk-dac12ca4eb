# Handoff

## Current state

The repository is bootstrapped with a Windows companion vertical slice and an iPhone SwiftUI shell. The companion intentionally binds to loopback and has no unauthenticated LAN mode.

## Important discoveries

- This Windows machine has .NET and GitHub CLI, but not a Swift/Xcode toolchain; iOS build verification must happen on macOS.
- iOS restriction behavior must be capability-gated through Screen Time APIs; unsupported controls must be surfaced as unavailable rather than simulated as active.

## Clock

`apps/ios/LockIn/Clock/` holds the reusable `CountdownClockView`. `FocusView.timing` (`SessionTiming?`) is the only session clock; the view renders from it. GitHub Actions run 41493405111 passed and produced idle screenshots on iPhone SE (3rd generation), iPhone 16, and iPhone 16 Pro Max; all three were visually inspected, with no visible clipping. Run 41494428865 passed two unit tests and five UI tests, including background return before and after expiry. Its exported active, elapsed, completed, and large-text-launch screenshots were inspected. Dynamic Type changes were added afterward; inspect run 41495360016 and its screenshots before claiming those changes work. VoiceOver remains unverified. See `docs/WINDOWS_IOS_DEVELOPMENT.md`.

## Recommended next work

1. On branch `ios/native-clock-ci`, inspect run 41495360016 with `gh run view 41495360016`; if it fails, inspect `gh run view 41495360016 --log-failed`. Do not assume success while it is running.
2. Download its artifact using `./scripts/ios-ci.ps1 -Action download -RunId 41495360016`. Inspect `test-attachments/manifest.json` and the large-text image, as well as the compact and large idle screenshots. Verify scaled controls are readable and reachable; fix and rerun if not.
3. Test Reduce Motion and VoiceOver where practical; the existing large-text test checks reachability, not that the text actually scaled. The completion image in run 41494428865 was captured during a transition. Session data is in memory only.
4. Confirm duplicate-completion behavior, improve compact-device active/large-text coverage, and update status from actual CI evidence. Neither Xcode Preview nor physical-device signing/install has been verified.
5. Later: authenticated pairing, clock-drift and reconnect testing, reversible Windows workspace profiles, and physical-device Screen Time authorization. These are separate from the present iOS clock milestone.

## Git and collaboration

The work is committed and pushed to `origin/ios/native-clock-ci`; it has not been merged into the default branch. Read `AGENTS.md`, `PROJECT_STATUS.md`, and Git status before editing. Preserve other agents' work. The private repository has no Apple signing secrets configured here; do not upload or publish without authorization.
