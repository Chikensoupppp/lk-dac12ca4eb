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

Signing handoff: Bundle IDs `com.brandon132199.lockin` and `com.brandon132199.lockin.monitor` were registered on the owner's Apple team on 2026-11-02 with Family Controls (Development). The Windows-to-iOS guide documents Apple team, bundle ID, provisioning, archive, and TestFlight prerequisites. No Apple account access, signing identity, signed archive, upload, or distribution has been verified.

## iPhone session recovery and Screen Time (2026-11-02)

- `apps/ios/LockIn/Session/SessionRecord.swift`: persisted record (id, startedAt, duration), `SessionRecovery.resolve`, UserDefaults store. `FocusView.timing` is still the only clock; it is rebuilt from the record at launch. Expired sessions complete once and the record is cleared in `.onAppear`.
- `apps/ios/LockIn/Restrictions/`: `RestrictionController` (lifecycle), `RestrictionPlanner` (pure rules), `ScreenTimeClient` (only file touching Apple frameworks), `RestrictionsSheet` (shield icon, top right when idle).
- `apps/ios/LockInMonitor/`: Device Activity monitor extension, backup cleanup only. `apps/ios/Shared/RestrictionNaming.swift` is compiled into both targets.
- Design choices: backup interval is scheduled before any shield is applied; if scheduling fails, no shield. Sessions under 15 minutes get no shields. Reconcile on launch and foreground clears stale or revoked state. No selection by default.
- Apple facts used (from developer.apple.com): minimum interval 15 minutes; `intervalDidEnd` runs only when the device is in use, so removal may lag; settings are not guaranteed to govern behavior; individual authorization lets the user remove protections. Not tamper-proof.
- Evidence: runs 41518261198 (persistence), 41519691608 (Screen Time build), 41521075050 (sheet UI test). All passed.
- Requirements and device test plan: `docs/SCREEN_TIME_RESTRICTIONS.md`. Needs the owner's Apple Developer account, Family Controls entitlement for app and extension, real bundle IDs, a physical iPhone.

Next steps: (1) owner gets entitlement and signs a development build; (2) run the device test plan; (3) record results; (4) only then claim enforcement. Windows pairing stays after that. Nothing was uploaded, merged, or published.

## TestFlight (2026-11-03)

- Owner registered bundle IDs (app and .monitor, Family Controls Development ticked), created the App Store Connect app record ("Lock in focus123"), and added GitHub secrets ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 (an Admin-role API key; App Manager failed with a cloud-signing permission error). Never put these values in Git or chat.
- `.github/workflows/ios-testflight.yml` + `apps/ios/project.testflight.yml`: a clock-only build (no Family Controls entitlement, no monitor extension) built with Xcode 26 (Apple requires the iOS 26 SDK), archived unsigned, signed at export with cloud-managed distribution signing. A branch push is a dry run (export only). A tag `testflight-*` uploads. Upload only with the owner's explicit yes.
- Evidence: run 41580614532 dry run passed (export succeeded). Run 41580725772 (tag testflight-2) uploaded to App Store Connect ("Upload succeeded", package processing). Tag testflight-1 failed validation (SDK too old) and uploaded nothing.
- The TestFlight build contains the placeholder icon (`LockIn/Assets.xcassets`). Screen Time shows as unavailable there. Screen Time on a device still needs a registered iPhone (UDID), a development profile, and a cable or other install path; distribution needs Apple's Family Controls approval.
- Not yet verified: the build on a real iPhone via TestFlight.

## Windows pairing, PC side (2026-11-04, not committed)

- `apps/windows-companion/Pairing.cs` + `Program.cs`: two doors. `http://127.0.0.1:47821` (this PC only, as before). `https://0.0.0.0:47822` (LAN): everything except `/health` and `/pair` needs `Authorization: Bearer <token>`. Self-made ECDSA certificate, key kept with DPAPI in `%LOCALAPPDATA%\LockIn\companion-state.json` (override with `LOCKIN_STATE_DIR`). Only a SHA-256 of each phone token is stored.
- Pairing: `LockIn.Companion.exe --pair` (or loopback `POST /pairing/open`) makes a 5-minute, single-use code and writes `pair-phone.png` (a QR of `{v,hosts,port,fp,code,expiresAt}`). The phone pins `fp` (SHA-256 of the cert) and posts `{code, deviceName}` to `/pair`; it gets `{deviceId, token, serverTime}`. Five wrong codes close the window. Loopback only: `GET /pairing/devices`, `DELETE /pairing/devices/{id}` (revoke).
- Session mirroring: `POST /session/start {durationSeconds, id?, startedAt?}` takes the phone's id and start time (same id twice is safe, a different id gives 409, a start more than 60 s ahead or an already-over session gives 400). `POST /session/stop {id?}` ignores a stale id. `GET /session` returns the session and `serverTime` for drift checks.
- Evidence: `dotnet run --project tests/windows-companion/LockIn.Companion.Checks.csproj` passed 32 checks on 2026-11-04. A live run on this PC confirmed 401 without a token, 404 for `/pairing/*` on the LAN door, pairing, reuse of a code (403), mirrored start/repeat/conflict/stale stop, and revoke (token then 401). Tested through localhost only.
- Not verified: a real phone reaching the PC over Wi-Fi; Windows Firewall (an inbound rule for TCP 47822 on private networks is needed); router client isolation; no iPhone code exists yet; no tray app or installer; the QR picture was written but not scanned.

## Git and collaboration

The work is committed and pushed to `origin/ios/native-clock-ci`; it has not been merged into the default branch. Read `AGENTS.md`, `PROJECT_STATUS.md`, and Git status before editing. Preserve other agents' work. The private repository has no Apple signing secrets configured here; do not upload or publish without authorization.
