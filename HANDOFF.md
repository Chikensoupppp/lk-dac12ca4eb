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
4. Run 41499182488 passed its build and UI test step, including a debug-only counter checking one completion after background expiry. Run 41499712871 passed the full workflow and added compact-device start/end coverage; its active iPhone SE screenshot was inspected without visible clipping. Run 41501083353 passed its full workflow, including selected-state and changing accessibility-value assertions on standard and compact simulators. Neither Xcode Preview nor physical-device signing/install has been verified.
5. Later: authenticated pairing, clock-drift and reconnect testing, reversible Windows workspace profiles, and physical-device Screen Time authorization. These are separate from the present iOS clock milestone.

Run 41501970643 passed and its small- and large-device active, elapsed, completion, and large-text screenshots were inspected. Controls fit, but the SE completion image showed a distorted arc during the parent transition. Commit 0193e7a disables parent animation on the timestamp-driven readout. Run 41503492932 passed; its compact completion screenshot was inspected with no visible arc distortion in that frame. Video or live inspection is still needed to verify the whole transition.

Run 41506311990 passed after sampling was extended to fourteen frames. The compact frames inspected span the countdown and reset with no visible recurrence of the distorted arc. Inspected Pro Max samples were already after completion. Sampling is not continuous video and may miss frames.

## Windows session reliability

The loopback-only companion now evaluates expiry against an injected clock when the store is read or started, rejects simultaneous/duplicate starts with HTTP 409, and no longer advertises a placeholder workspace capability. `dotnet run --project tests/windows-companion/LockIn.Companion.Checks.csproj` passed boundary, stop, and concurrent-start checks. Live HTTP checks passed for 200/409/400 paths. GitHub Actions Windows run 41514843623 passed the same lifecycle checks. Expiry is lazy, state is not persistent, and endpoints are unauthenticated; do not expose to LAN. Expiry uses UTC wall-clock time, so clock adjustments can shorten or extend sessions; decide and test clock-change and cross-device reconciliation semantics before enforcing restrictions. Pairing needs authenticated encrypted transport, explicit approval, and recovery design before remote control.

Signing handoff: `com.lockin.focus` is an unverified development placeholder, not a claimed App Store identity. The Windows-to-iOS guide documents Apple team, bundle ID, provisioning, archive, and TestFlight prerequisites. No Apple account access, signing identity, signed archive, upload, or distribution has been verified.

## Git and collaboration

The work is committed and pushed to `origin/ios/native-clock-ci`; it has not been merged into the default branch. Read `AGENTS.md`, `PROJECT_STATUS.md`, and Git status before editing. Preserve other agents' work. The private repository has no Apple signing secrets configured here; do not upload or publish without authorization.
