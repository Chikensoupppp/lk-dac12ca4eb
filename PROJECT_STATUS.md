# Project status

## 2026-11-13 work in progress

- PC buddy detects natural session expiry and displays a six-second cheer; four deterministic timing checks and the existing Windows checks passed locally. Actual desktop behavior has not yet been observed.
- First-run Focus coach and iPhone session-start allow-list payload are implemented in source; iOS compilation, simulator behavior, screenshots, and physical-device behavior are pending.
- Save for Later is not implemented yet. No TestFlight build has been uploaded for these changes.

Updated: 2026-11-02 (branch ios/native-clock-ci)

## Implemented

- Private GitHub repository and permanent local checkout.
- Shared project instructions and product documents.
- Versioned session protocol with explicit lifecycle and capability reporting.
- Windows companion service with loopback health, session start, and session stop endpoints.
- Windows session store expires elapsed sessions on read or start and returns an HTTP conflict for duplicate starts. A .NET console check suite covers timing boundaries, early stop and concurrent starts.
- SwiftUI iPhone shell for selecting duration and starting/stopping a local session model.
- Titanium countdown clock (`apps/ios/LockIn/Clock/`) driven by a single end-timestamp (`SessionTiming`).
- XcodeGen project and macOS simulator CI; UI tests and screenshot capture are included.
- First-run onboarding (`apps/ios/LockIn/Onboarding/`): 9 steps with Back, "N of 9", and Skip on the hours, apps and focus questions. Screen Time access and the app picker are on the real screens. PC pairing is not in onboarding; it stays in the PC sheet and belongs after Plus. Plus is a "coming soon" preview only; it is not built. Added 2026-11-05 (not compiled and not CI-tested; Brandon tests by hand): reaction stickers after the hours and goals answers, a "Working it out" screen between goals and year (5 s, auto-advances, skipped when hours were skipped), a hold-to-start final screen (3 s hold, VoiceOver gets a "Start now" action), and a streak screen (`StreakView`, `StreakStore`) after the first finished session of a day. Test buttons "Replay intro" and "Show streak" on the main screen must be removed before a public release.

## Verified

- GitHub Actions run 42079862575 (10-step onboarding build): passed on simulator, including the first-run UI test and the unit tests. Screens were inspected. Not verified: Screen Time authorization and the app picker (need a physical device), QR scanning, the 9-step version with Back and Skip, VoiceOver.

- `dotnet build apps/windows-companion/LockIn.Companion.csproj`
- Live HTTP check: `/health`, `/session/start`, and `/session/stop` on `127.0.0.1:47821`
- Windows session checks passed locally, including exact expiry and 32 concurrent start attempts. Live HTTP checks returned 200 for health/start/stop, 409 for duplicate start, and 400 for invalid duration.
- GitHub Actions Windows run 41514843623 passed the companion lifecycle checks on a hosted Windows runner.
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
- GitHub Actions run 41501970643: full workflow passed with idle, active, partially elapsed, completion, and large-text UI captures on iPhone SE and iPhone 16 Pro Max. The images were inspected; controls fit. The SE completion capture showed arc distortion during the transition. Commit 0193e7a disables parent animation for the timestamp-driven readout. Run 41503492932 passed, and its SE completion frame was inspected with no visible arc distortion; a still does not verify every frame of the transition.
- Run 41506311990 passed. SE sampled frames showed the countdown and reset without the prior arc distortion. Inspected Pro Max samples were captured after completion, so they do not verify its transition.

- Run 41521075050 (branch ios/native-clock-ci, commit after 41519691608): full workflow passed. 10 unit tests (session persistence and recovery: restore active, expiry boundary, relaunch after expiry, early cancel, clock moved backwards, corrupt data; Screen Time lifecycle with a fake client: denied, failed scheduling, 15-minute minimum, stale and revoked reconcile, cleanup-callback rules) and 10 UI tests (active session survives app termination, relaunch after expiry completes exactly once and a third launch is idle, early cancel does not restore, Restrictions sheet reports "access is off"). Screenshots of idle, sheet, and restored-active were inspected.
- The app plus the LockInMonitor Device Activity extension build for iOS Simulator with the Family Controls entitlement (unsigned).

- GitHub Actions run 41580725772: archived with Xcode 26.3, signed with cloud distribution signing, and uploaded to App Store Connect (TestFlight processing). Not yet installed on an iPhone.

- 2026-11-13: PC desk buddy (committed 54486fd) and Focus Guardian (uncommitted): gentle scrolling reminders from a Chrome/Edge extension over native messaging and a per-user named pipe. Guardian checks pass; see HANDOFF.md "PC desk buddy and Focus Guardian" for what was and was not verified.
- 2026-11-04 (uncommitted): Windows companion got an authenticated HTTPS LAN door, one-time QR pairing, and phone-supplied session mirroring. 32 local checks pass and a live localhost run passed. See HANDOFF.md "Windows pairing, PC side". The iPhone side is not written.

## Not yet verified

- Manual VoiceOver, actual system-level Reduce Motion behavior, physical-device behavior, and profiling remain unverified. The debug override test does not establish that every animation is absent or verify operating-system settings.
- **Screen Time enforcement.** The simulator cannot grant access. No shield has ever been applied by this code on a device. Authorization, picker, shield, backup-removal timing, and revocation are untested on hardware. See `docs/SCREEN_TIME_RESTRICTIONS.md`.
- Signing, entitlement approval, bundle IDs (placeholders).
- Session persistence uses UserDefaults and wall-clock timestamps; a device clock change can shorten or extend a session (a clock moved back by more than 60 seconds discards the record).
- iPhone/Windows network pairing (Milestone 2).
- The Windows store is in-memory and lazy-expiring, wall-clock adjustments affect its deadline, and it is not a restriction enforcement or recovery mechanism.
- Actual Windows application/site restriction enforcement.

- 2026-11-04: Focus screen rebuilt as matte black with a living background (drifting glows, dust, rim glint, ripples), mood colors (running, last minute, finished, ended early), start edge-run and ring, light sweep on finish, heavy/success/warning haptics. Run 41951086970 passed (33 unit and 10 UI tests; UI tests run with the live background off via `-ui-testing-calm-background`). Idle screenshots on SE, 16 and Pro Max were inspected. The animated state, battery use and frame rate are NOT verified on a device. Sheets (Restrictions, PC) still use the Cream look.
