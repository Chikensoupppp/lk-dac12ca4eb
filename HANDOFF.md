# Handoff

## Focus screen · 2026-11-16

The local redesign uses `BrainExact` inside a flat cream dial. The task, minutes, Locked Mode and PC pairing retain their existing actions. The session lifecycle and Live Activity code are unchanged. The supplied before picture and browser previews are design references. Run `FocusUITests` on the compact iPhone at Accessibility XXXL and check VoiceOver, coach and live countdown behavior before release.

## Habit features - 2026-11-15 (CI 43754543243 green on 426ae7b)

- Streak rest day: one missed day keeps a streak alive if the days around it were finished; usable once per 7 days (`StreakStore.run`). The streak screen says "rest day used. nice save".
- Daily reminder (`Nudge.swift`, `DailyNudge`): optional row on the finish card, "Remind me tomorrow at <start time>". Asks notification permission only on tap. Off switch in the weekly goal sheet.
- Tools hint: one bubble under the top-right buttons after the first finished session, once (`lockin.toolsHint.v1`).
- If-then line: default off; toggle and text in the weekly goal sheet; shows "When <cue>, I lock in." on Focus.
- Allowed on PC: per-task list (`AllowedApps`, `AllowedAppsSheet`), opened from the task picker, sent as `allow` with the session start. PC-side matching of names is unverified on a real PC.
- First-run bug fixed (53aee12): LOCK IN and the hold button start on a tap while the coach shows. Shipped as testflight-33. The habit features are NOT in testflight-33.
- Cleanup: removed the test-only Chromium native-messaging registry key for `com.lockin.guardian`. BlockP is still installed in Program Files; nothing of it was removed.

## Mobile milestone - 2026-11-15 (CI 43749652340 green on 1b1e77b)

- Shorter first run: slide 1 "START NOW" ends onboarding; the Focus coach then walks task, minutes, distracting apps, ONE hold-to-start. "See why first" keeps the long intro. No promise to sign, no tutorial holds, no Plus offer in the flow.
- Plus is offered once, after the first finished free session (`lockin.plusOffered.v1`).
- Coach: optional, Skip always visible (`skip-focus-coach`), points at the real controls.
- Quitting is neutral: no guilt sentence, no scars, no fake BPM. Emergency exit stays. Early end keeps the focused minutes (`FocusLog.recordQuit(minutes:)`) but counts no finished session, so the streak is untouched.
- Completion card (`CompletionCard.swift`): time focused, "Next time: task - N min" with KEEP IT / Change task; first-win badge only for the first ever.
- Widget is "Selected apps": time in picked apps only, no brain-health wording, mascot never worse than a little tired.
- Small iPhones: the clock shrinks on screens under 700pt tall so LOCK IN is fully visible (checked on the SE CI picture).
- Verified by CI: build, unit + UI tests (incl. partial credit, neutral quit, completion card), compact and large device checks, screenshots in the `ios-visuals` artifact.
- NOT verified: physical iPhone, Screen Time picker inside the coach, Plus-after-first-session on device, VoiceOver, widget on a real home screen.
- NOT built: nudge notification / "same time tomorrow", tools-area one-time hint, if-then line, streak grace. No TestFlight tag was pushed for this. Repo is PUBLIC; make it private only when the owner says.

## Current work - 2026-11-13

- Pulled clean branch at 82db621. Coach gaps filled: typed bubbles, gaze, star-eye YES!/NICE! rewards, charge-up shake, dimmed non-target controls, always-reachable Skip, Reduce Motion fades. The hold uses the proven non-Button gesture pattern after CI exposed a recognizer conflict. Coach persistence and active toolbar accessibility are fixed (7249ace).
- The owner requires the EXACT right-hand artwork from his comparison image. Both apps bundle the same PNGs; 76,504 original non-background pixels are unchanged in the normal asset. Expressions replace only the face. Degraded mood layers retain colors and damage marks, lose sparkles after stage 1 and gloss after stage 2. `scripts/extract-brain-assets.py` reproduces them; reference is `docs/design/brain-mascot-exact.png`.
- Windows CI 43533952859 passed: 128 checks plus 3 Node extension tests. Tests include encrypted persistence, corrupt-store preservation, concurrent store instances, single-use session/window-bound URL requests, actual duplex private-pipe round-trip and rendered save-button hit targets. UI renders use synthetic fixtures only.
- Save for Later is implemented in e846ee5. A buddy click requests the active YouTube/Reddit URL over native messaging; only chosen links are saved locally (Windows DPAPI). The list opens at natural or early session end; `LockIn.Companion.exe --later` reopens it. No cloud processing, page contents, screenshots or keylogging. Full live browser-to-buddy click-through remains unverified because the browser host is unavailable. Update both companion and unpacked extension 0.2.0; signed Firefox XPI remains 0.1.0.
- Natural-expiry PC cheer remains six seconds. Deterministic timing checks pass; live desktop transition remains unverified. The phone sends buddy/guardian settings and an optional allow list; remembered task allowances merge on PC.
- iOS main build/test step PASSED in 43535356052 (fb21ffd), after fixing hold recognition, pending state, hidden toolbar accessibility and the stamp's too-short lifetime (now six seconds). Compact/large-device checks remain in progress. Signed archive/export 43535496068 PASSED on the same iOS source (export only, no upload). TestFlight upload awaits the remaining device checks.
- GitHub private-repo billing blocked jobs. Repository is temporarily public with owner authorization; restore private after CI/TestFlight. Two independent reviewers were used total (owner's cap); data-loss and mood-layer findings are fixed. No further subagents.
- No local iOS simulator is available. The prototype video was inspected through extracted frames and its animation source. Preview rejected the local file URL; fallback browser host is unavailable. Physical-device Screen Time, VoiceOver and system Reduce Motion remain unverified.

## Current state

The repository is bootstrapped with a Windows companion vertical slice and an iPhone SwiftUI shell. The companion intentionally binds to loopback and has no unauthenticated LAN mode.

## Important discoveries

- This Windows machine has .NET and GitHub CLI, but not a Swift/Xcode toolchain; iOS build verification must happen on macOS.
- iOS restriction behavior must be capability-gated through Screen Time APIs; unsupported controls must be surfaced as unavailable rather than simulated as active.

## First-run onboarding

`apps/ios/LockIn/Onboarding/` (flow, components, store). 9 steps. Skippable: hours, apps, focus goals; skipping hours also skips the "year" step so no made-up number shows. `OnboardingStore.isDone()` skips it in UI tests unless `-ui-testing-onboarding`. Design mocks: `docs/design/` (`slides-v9.html`, `real-onboarding-sheet.png`). Plus (step 8) is a preview with one button, "Not now"; build Plus before changing that. PC pairing was moved out on purpose: do it after purchase. Unverified: Screen Time on a device, app picker icons (`Label(token)` size), QR scan.

Added 2026-11-05: reactions on steps 2 and 6; `WorkingStep` (not a numbered step, shows "6 of 9", flag `working` in `OnboardingFlow`); hold-to-start `ReadyStep` (3 s, identifier `hold-to-start`); `Streak.swift` + `StreakView.swift` (streak shown after the first finished session of a day, tests in `StreakTests.swift`; UI tests skip it unless `-ui-testing-streak`). This code was written on Windows and never compiled; the TestFlight build is the first compile. Remove the "Replay intro" and "Show streak" test buttons in `FocusView` before a public release. Also `HoursFactStep` (between steps 2 and 3, one screen per hours answer: praise for 1 to 2 h; Kushlev and Dunn 2015, Hunt 2018, Exelmans and Van den Bulck 2016 for the others; facts came from abstracts and news pages, not the full papers). Flow uses an `Interlude` enum (`fact`, `working`). Mocks: `docs/design/fact-mock.html`, `docs/design/flow-new.html` and `flow-new.mp4`.
 Updated 2026-11-08: `HoursFactStep` copy rewritten per Brandon (four variants; headlines, cards, banners), the study line is now a tappable `Link` to the DOI (Kushlev and Dunn 10.1016/j.chb.2014.11.005, Hunt 10.1521/jscp.2018.37.10.751, Exelmans and Van den Bulck 10.1016/j.socscimed.2015.11.037; the last DOI was wrong in an early guess and is now checked). Study details verified from abstracts and the publisher or PubMed records, not the full papers. Text uses `@ScaledMetric` for Dynamic Type; badge sits on the card edge so the banner stays above the button. Not run on a device.
Updated 2026-11-11: `HoursFactStep` and its study slides are gone. The screen after the hours question is now `BrainStep` (`Onboarding/OnboardingBrain.swift`): a cartoon brain takes one hit per tile and gets worse with more hours (1 to 2 hours: no hits, proud brain, the day as 24 squares; 3 to 4: 3 hits; 5 to 6: 5 hits and a plea; 7+: 6 hits, dead). After each hit it says a "1 more" line. Generic tiles only, no real logos. A "just for fun" sticker marks it as a joke, not a health claim. Reduce Motion shows the end state at once. CONTINUE is always enabled. Mocks: `docs/design/brain-rot.html` (`?h=0..3`), `flow-v3.html`. Not compiled or run on a device or simulator (no Xcode here). The three study DOIs are still in `docs/design/study-slide-research.md` if a study slide ever returns. The 1 to 2 hours ending is option X (24 squares); option Y (lock box) is only a mock.

Updated 2026-11-12: the whole first-run flow was rebuilt as onboarding v2, the "printed" look (`docs/ONBOARDING_V2.md`, mock `docs/design/ob-v2.html`, brain mock `docs/design/brain-v2.html`). NOT compiled and NOT committed; no Xcode here. Files: `Onboarding/Print.swift` (inks, fonts, `PrintScaffold`, stamp, receipt), `Onboarding/PrintSteps.swift` (hook, guess poster, why we ask, reveal, stickers, lock apps, year, goals, plan print-out, promise), `Onboarding/HeartBrainStep.swift` (heart-monitor brain plus study card), `Onboarding/OnboardingFlow.swift` (12 slides, Back via a history stack), `Plus/PlusStore.swift` + `Plus/PlusOfferStep.swift` (StoreKit 2, product `com.brandon132199.lockin.plus.yearly`), new extension `LockInReport/` (DeviceActivityReport draws the real hours; the guess rides in the context name, `ReportShared/ReportContext.swift`). `OnboardingBrain.swift` was deleted. Fonts are Apple system faces (compressed, monospaced, Marker Felt), so no font files. Flow rules: the user taps the band that matches their real hours, since the app cannot read them; no Screen Time access or no extension skips the reveal and uses the guess; no hours answer skips brain and year; signing the promise starts the first session after the offer. UI tests updated to the new labels. Open: (1) the product must be created in App Store Connect (yearly, 7-day free trial) and the Paid Apps agreement must be active, else the offer shows "NOT ON SALE YET"; (2) `LockInReport` is only in `project.yml`, not `project.testflight.yml`: register `com.brandon132199.lockin.report` with Family Controls and get Distribution approval, then add the target there and to the entitlement-embedding step in `ios-testflight.yml`; (3) there is no privacy policy URL (`PlusLinks.privacy` is nil); (4) Plus only unlocks PC pairing today, which App Review may find thin.

## Brain widget (2026-11-12, not compiled, not committed)

One medium home screen widget (`LockInWidget/`, bundle `com.brandon132199.lockin.widget`), mock `docs/design/widget-brain.html`. The brain rots as today's phone time crosses hour lines (1h tired, 2h dizzy, 4h fading, 5h begging, 7h rotten); one app over 2h makes it one stage worse. It never flatlines (weak red beat at 7h+). How it knows: the app cannot read Screen Time, so `LockIn/Brain/BrainWatch.swift` starts an all-day repeating Device Activity (`lockin.brain.daily`) with threshold events (total 1-7h for the apps picked to lock, and 2h/3h per single app, first 10 apps; `includesPastActivity` on iOS 17.4+). `LockInMonitor` records each event in the app group `group.com.brandon132199.lockin` (`Shared/BrainLevel.swift`, keyed by date) and reloads the widget. `FocusView` keeps the watch in step with the picked apps and Screen Time status. The brain drawing moved to `BrainArt/BrainDrawing.swift`, shared by the onboarding slide and the widget. It only watches the apps picked to lock. Open: the App Group and the widget bundle ID may need registering in the Apple developer portal if cloud signing does not create them; threshold timing and the widget look are unverified on a device; widgets cannot animate, so the heart trace is a still picture.

## Quitting early, Locked mode, Friend Key (2026-11-12)

- Free (`Quit/`): END SESSION opens `QuitSheet`: a watched wait (`WatchedWait`, restarts if you leave the app; 1, 5, then 15 min per week), then typing "I'm choosing my phone over my goal". Any early end scars today's widget brain (`BrainLevel.markScar`, one stage worse until morning, "quit early" on the widget). UI tests (`-ui-testing*`) skip straight to the end.
- Plus Locked mode: switch under the minutes (needs apps picked). `RestrictionController.begin(locked:)` also sets `application.denyAppRemoval` and `dateAndTime.requireAutomaticDateAndTime` in the same named store (cleared with the shield and by the monitor). Button reads GET OUT EARLY and opens `LockedExitSheet`: Key Holder in person, Key Holder remote, or the weekly emergency exit (15-min watched wait). TestFlight builds count as Plus (`PlusStore.hasPlus`).
- Friend Key (`Keys/`): per-phone P256 signing + key-agreement keys in the Keychain (`KeyStore`). Pair in person (Keys button, top right) over Multipeer Connectivity (`NearbyLink`, Bluetooth/peer Wi-Fi, service `_lockin-key`). Unlock in person: signed ask, Key Holder holds to approve, signed answer bound to request id + nonce; Nearby Interaction requires 1 m when both phones have the U1/U2 chip. Remote: CloudKit public DB `iCloud.com.brandon132199.lockin`, record types `UnlockRequest` (reason encrypted to the Key Holder) and `UnlockAnswer`; Key Holder's phone has a `CKQuerySubscription` push; asker polls every 5 s; yes starts a 10-min cool-down; 30 min without an answer means no.
- Apple setup done 2026-11-12 in the developer portal: iCloud container, iCloud (CloudKit) and Push on the app ID; CloudKit schema (both record types; queryable indexes holderID, createdAt, requestID) created in Development and deployed to Production. App entitlements: iCloud container + services, `aps-environment` (production in the TestFlight spec). `AppInfo/LockIn-Extra.plist` adds NSBonjourServices and the Nearby Interaction text.
- Not verified on devices: everything here. Needs two phones with the build for Friend Key. Apple says the delete lock is not guaranteed under individual authorization (turning off Screen Time access in Settings still ends it unless a Screen Time passcode is set).

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

## Windows pairing, iPhone side (2026-11-04)

- `apps/ios/LockIn/PC/`: `PCModels` (offer, link record, `PCTransport`), `PCClient` (HTTPS, certificate pinned to the QR fingerprint), `PCLink` (state, Keychain store, retrying start, serialized stop), `PCViews` (status line under the title, pairing sheet), `QRScannerView` (camera). `FocusView` calls `pc.sessionStarted/sessionEnded` next to the restriction calls and re-sends a restored session on launch.
- Phone is the boss of time; a PC that is off never changes a session. 401 from the PC forgets the pairing; 409 (PC busy) is shown and not retried.
- `NSCameraUsageDescription` and `NSLocalNetworkUsageDescription` added to `project.yml` and `project.testflight.yml`.
- Evidence: CI run 41776976228 (commit ddbd929) passed: 33 unit tests (12 new in `PCLinkTests.swift`) and 10 UI tests, plus compact and large device runs. The idle screenshot shows "PAIR A PC".
- Not verified: scanning a real QR with the camera, TLS pinning against the real PC certificate, Local Network prompt, Windows Firewall (inbound TCP 47822, private networks), any real phone-to-PC traffic. The PCLink unit tests use fakes, so the network path is untested. Not uploaded to TestFlight.

## PC desk buddy and Focus Guardian (2026-11-13)

- Desk buddy (`apps/windows-companion/Watch/`, committed in 54486fd): see-through always-on-top brain,
  moods by session time, speech bubble, ask-first blocking ("Is YouTube for your work?"), allows
  remembered per task, `GET /session/choices`. Protocol: `docs/PC_BUDDY_PROTOCOL.md`. Open design
  question about blocking vs lying: `docs/PC_BUDDY_BLOCKING_PROBLEM.md`.
- Focus Guardian (NOT committed): gentle reminder after about 3 minutes of steady Shorts or Reddit
  feed scrolling on sites the blocking left open. Files: `Watch/ScrollGuard.cs` (rules, settings,
  report parsing), `Watch/GuardianLink.cs` (native messaging host, named pipe, browser registration),
  `FrontWindow.BringToFront` + `WorkWindowMemory`, `Distractions.IsWorkWindow/IsBrowser`,
  `SessionWatch` (Report, reminder state, Back to work / Not now), buddy buttons per prompt
  (`AskChoice.NotNow`), `BuddyWords` reminder lines, `apps/browser-extension/` (MV3: content.js,
  background.js, manifest with a fixed public key). Details: `docs/PC_BUDDY_PROTOCOL.md` "Focus Guardian".
- Security: no new HTTP endpoint. Chrome/Edge native messaging (allowed origin = our extension ID only)
  then a named pipe for this Windows user only, network SID denied, client checks the pipe owner.
  Setup: `LockIn.Companion.exe --register-browser` (HKCU keys for Chrome and Edge, host file in the
  state folder); `--unregister-browser` removes them.
- Evidence: `dotnet run --project tests/windows-companion/LockIn.Companion.Checks.csproj` passes all
  71 checks (32 old, 39 Guardian: thresholds, video never counts, no reports never counts,
  slow reading, forgiven gaps, cooldowns, session reset, settings file, report parsing and caps,
  native message frames, work-window choice). Live run on this PC (2026-11-13, threshold set to 40 s
  via guardian.json): companion + session with YouTube allowed, a stand-in "Word" window, Chrome on a
  local page titled "Shorts - YouTube", and the real host exe started with the extension origin and
  fed framed Shorts reports. All 23 reports answered `{"ok":true}` (host to pipe to companion), the
  reminder appeared, a real mouse click on "Back to work" brought the Word window to the front
  ("Nice. Back to it!"), and more scrolling right after showed no reminder (cooldown). "Not now" was
  only checked in unit tests.
- Full real run (2026-11-13, default 3 minutes, no settings file): the unpacked extension loaded in
  Playwright's Chromium 153 (Chrome 157 ignores `--load-extension`; a test-only key
  `HKCU\Software\Chromium\NativeMessagingHosts\com.lockin.guardian` was added for it), real YouTube
  Shorts, real mouse-wheel swipes about every 3.7 s. Chromium started the host after 23 s; the
  reminder appeared about 3 minutes into swiping (46 swipes); a real click on "Back to work" brought
  the stand-in Word window to the front ("Nice. Back to it!"). That run found and fixed a bug: a
  browser titled "Untitled" while loading was remembered as the work window. Now blank browser pages
  never count and a window must stay in front 3 s (`WorkWindowMemory.DwellTicks`). 74 checks pass.
  The owner's BlockP blocker (removed at his request) had blocked Shorts and Reddit in earlier tries.
  Still not verified: Reddit feeds for real, Edge, branded Chrome with the extension installed by hand.
- Every-browser rule (`Watch/BrowserGuard.cs`, heartbeat in `background.js`, browser name from the
  host's parent process): 89 checks pass. Live (grace set to 15 s): Chromium with the extension but
  private windows off showed "Let Lock In run in private windows in Chrome too." then was minimized;
  Firefox (Playwright build, no extension) showed "Lock In isn't on in Firefox…" then was minimized.
  Not verified live: the "all good" case with private windows on (Chromium keeps that switch in
  protected preferences, so the test could not flip it; unit tests cover it), Edge, Brave, Firefox
  with the extension installed.
- Opera (2026-11-20): live-tested with Opera 140 (Chromium 157), unpacked extension, stand-in hosts on every
  Chromium key at once: Opera started the host only through `HKCU\Software\Chromium\NativeMessagingHosts`
  (already written by `--register-browser`); it ignored Chrome's key and the two Opera-named keys. So no Opera
  key is needed. The host's parent chain was `cmd.exe <- opera.exe`, so `ParentProcess.NameOf` gives "opera".
  Then the real pipeline, with the user's app stopped for a minute and the Chromium key pointed at the real
  `LockIn.Companion.exe` (debug build) as host and the real `GuardianPipe` (a test harness printing what it
  receives): Opera 140 with the unpacked extension sent `alive browser=opera incognito=False` every 15 s and a
  `youtube-shorts` signal (14 scrolls, 1.5 screens) over extension -> host -> pipe. The key and the app were
  restored afterwards; Opera was uninstalled again. The window-reading watch (`BrowserWatch`, `Distractions`)
  covers Opera without the extension, after one fix: Opera lists an empty unfocusable "Address bar" container
  before the real "Address field", and `FindAddressBar` took the first text box, so Opera was never classified.
  It now prefers a focusable text box. Live (stand-in youtube.com/shorts and reddit.com/r/all pages, real
  BrowserWatch): Opera 140, Chrome 157 and Edge all report youtube-shorts / reddit-feed and count a new Short
  as an item. Real mouse-wheel counting in Opera (14 notches sent with `mouse_event`, low-level hook):
  `scrolls=14 screens=1.5`. Note: the shipped 0.9.14
  window has no CONNECT BROWSERS button (removed in 5964e3a) and nothing calls `Installer.OpenExtensionHelp`
  or `--register-browser` on install. swipelater.app/pc dropped its extension step; `docs/pc/index.html` in this
  repo still has the old one. The 0.9.14 build also lacks the `FindAddressBar` fix; it ships with the next PC release.
- Bypass hardening (2026-11-20, PC app, not released): (1) a site is judged by the front browser's address
  as well as its title (`Watch/BrowserSites.cs`, fed by `BrowserWatch` every second; only the site's name is
  kept, for 5 s, for that window): a Reddit post's title never says "Reddit", so it used to count as work.
  The title check stays as the fallback. (2) The clock check adds drift up since the last correction
  (`ClockDrift`, 10 s limit) instead of judging each 2 s step against 30 s, so many small steps no longer
  run a Locked session out. (3) While Locked, the watchdog task and the startup entry are checked every 30 s
  and put back if deleted (`ShieldController.Repair`, `ShieldTask.Exists`). (4) Palemoon, SeaMonkey,
  Maxthon, Whale, Slimjet, Iridium, Wavebox and Sidekick count as browsers. Checks: 147 pass (13 new).
  Live: real Edge on a stand-in Reddit post page titled "Funny cat : r/aww" is judged Reddit, distraction,
  not work; the real `ShieldController` with a fake Locked session re-created the deleted task after 24 s and
  removed it at the session's end. Not tested live: the clock check (moving the clock needs admin; unit
  checks only) and the startup-entry repair. Still open by design: the extension is only required once it
  has connected (people who never set it up are not locked out), an elevated admin can still end the app,
  and a browser that is not in the list is not watched.
- Free-session passes (2026-11-20, PC app, not released): in a free (not Locked) session the buddy's "Is it for
  work?" yes is now a pass (`Watch/FreePasses.cs`): 2 per session, each opens that site for 15 min and then it is
  asked again, a yes within 3 s (first) or 6 s (second) of the question showing does not count ("Hold on 3 s..."),
  passes do not refill during the session, and a yes is no longer remembered for the task's next session
  (`AllowStore.Add` is not called any more; sites remembered earlier and the phone's allow list still apply).
  With both passes spent the buddy stops asking and minimizes with "No passes left." Locked sessions are
  unchanged (no question, no passes) and ending a free session is still always allowed. Numbers are constants in
  `FreePasses`; the waits are short because the question itself times out after 12 s. Checks: 156 pass (9 new).
  Live (real SessionWatch, BrowserWatch and buddy window, real Edge, taps raised through the buddy's event): early
  yes -> "Hold on 3 s", yes after 4.5 s -> pass (1 left), a Reddit post page (title without "Reddit") asked about
  by its address, yes after 7.5 s -> last pass, then a TikTok page -> "No passes left" and declined. Not observed:
  the window actually minimizing on that last step (same code path as a "no"), a pass expiring after 15 min (unit
  checks only), the phone (nothing changed there; phone-side friction for free users is not built).
  Later run (same day, fake clock + real Edge): a pass expired after +16 min and YouTube was asked about again,
  and the Edge window was minimized (IsIconic true) after "No passes left". Both gaps above are now observed.
- Wider distraction list (2026-11-20, PC app, not released): addresses now also cover X/Twitter, Facebook,
  Snapchat, Disney+, Hulu and Prime Video (`BrowserSites.cs`); chat adds Signal, Viber, Messenger; games add the
  launchers Battle.net, EA app, Ubisoft Connect, GOG Galaxy, Xbox app and about 100 game and emulator processes
  (shooters, MOBAs, sandbox, RPGs, sports, RetroArch, Dolphin and others). They are one table,
  `Distractions.GameNames` (process -> plain name), so adding a game is one line. A process name is the exe name
  lower case without ".exe"; some are guesses by game, so a game that is missed needs its real exe name added. Title fallback adds only Facebook, Snapchat, Disney+, Hulu (names that rarely sit in a work
  title); X is address-only. Phone chips (`/session/choices`) add X, Facebook, Snapchat. Not listed on purpose:
  Spotify and other music, Roblox Studio, game editors. Checks: 164 before the generic detector below.
- Any-game detection (2026-11-20, PC app, not released): `Watch/GameDetector.cs` catches games that are not in
  `GameNames`. Any one signal is enough: (1) the exe sits in a game library (steamapps\common, Epic Games, Riot
  Games, XboxGames, GOG, EA, Ubisoft, itch, any "\Games\" folder), (2) one of its 3 nearest ancestors is a game
  launcher (Steam, Epic, Battle.net, EA, Ubisoft, GOG, Riot, Xbox), (3) a game SDK or engine file sits next to
  the exe or one folder up (steam_api64, steam_appid.txt, EOSSDK, UnityPlayer, GameAssembly, galaxy, DLSS,
  OpenVR, Bink; looked up on disk), (4) Windows reports a Direct3D exclusive full-screen program and the front
  window covers its monitor. 1-3 are read once per window and cached; names come from the exe's ProductName,
  else the exe name. ANTI-CHEAT SAFE: the game process is never read or opened with more than
  PROCESS_QUERY_LIMITED_INFORMATION (its path, what Task Manager asks); the launcher chain is a Toolhelp
  process-list snapshot (no handle) and signal 3 reads files, not memory. Never add Process.Modules,
  Process.Handle or VM_READ to `GameDetector` (an earlier draft did, and the "no SDK yet" verdict was also
  cached forever; both are gone). `NeverGames` (Blender, Godot, Krita, Unity,
  Unreal Editor, Roblox Studio, OBS, Wallpaper Engine...) and the Unreal install folder are excluded, and the
  buddy's "It's for work" still lets a wrong guess through. Hooked in at `Distractions.IsDistraction` (any
  non-browser window) and `FriendlyName`. Also in a Locked session (no question there), so a wrong guess is
  costly: add the exe to `NeverGames`. Checks: 174. Live (real processes): game-library path, launcher parent
  (cmd copy named steam.exe), and a steam_api64.dll next to the exe were each caught; a plain program, this
  shell and protected processes (MsMpEng, csrss, lsass, System) were not, and none crashed it. NOT tested:
  signal 4 (needs a real exclusive full-screen D3D game; only its screen-cover math is checked; modern Windows
  may report most games as "busy", not "D3D full screen", so it may miss many), minimizing a real fullscreen
  game, and any real game or anti-cheat. The `\Games\` folder marker is broad.
- Browser games, multi-monitor and other cases (2026-11-20, PC app, not released, Checks: 189):
  (a) Browser games by address (`BrowserSites.cs`, now a table of `Site(Host, Name, Path?, Exact)`): Poki,
  CrazyGames, Miniclip, Y8, Kongregate, Newgrounds, itch.io, Game Jolt, Roblox (exact host, so create.roblox.com
  and devforum stay work), Chess.com, Lichess, .io games, cloud gaming (GeForce Now, Luna, xbox.com/play with a
  language prefix, nytimes.com/games) and any host or path containing "unblocked". Anything not in the table is
  still missed: a game on an unlisted site is work. The extension is NOT used to guess web games (deliberately).
  (b) Every visible window on any monitor is judged, not only the front one: `VisibleWindows.FindDistractions`
  (open, not minimized, not on another virtual desktop, not a tool/click-through/no-activate overlay, on a
  monitor) keeps a distraction only when at least 60,000 px and 25% of it shows past the windows above it (pure
  rectangle math, `VisibleArea`). `SessionWatch.Tick` picks a subject among them (the one already asked or
  declined first, so the question does not jump), asks, and minimizes THAT window; work is still judged by the
  front window. A fully covered window is ignored. Costs about 8 ms a tick. The process is already system-DPI
  aware (measured: `GetProcessDpiAwareness` = 1 on the installed app; it comes from the SDK/WPF default, not from
  our code), so `Enumerate` switches its own thread to per-monitor awareness (`SetThreadDpiAwarenessContext`,
  restored after) to get real pixels on mixed-scaling monitors. Because the process is DPI aware, windows must
  scale themselves: `HomeWindow` already did (`Px`/`Pf`); `BuddyWindow` (scene drawn at 100% and scaled by
  `DeviceDpi / 96`, mouse positions divided back) and `LaterWindow` (`Px`) did not, so they were physically small on
  a 125-200% screen until now. Checked only at 100% scaling: the buddy scene was rendered at 100/150/200% and its
  hit test checked by math; HomeWindow and LaterWindow at a scaled screen were not seen.
  (c) `BrowserWatch` reads the address of every open browser window (2 background windows per second, front
  first), keeps the site per window (`BrowserSites.Record(window, name)`), and counts wheel notches per window
  under the pointer, so a feed scrolled on the second monitor counts while another window has focus.
  (d) The buddy follows the question to the monitor of the window it asks about and returns to its saved
  spot afterwards (`BuddyWindow.FollowQuestion`); "Save for later" only shows when the asked page is the front
  one. (e) Store apps (Netflix, Disney+, Prime Video, TikTok, Instagram, Twitch, Facebook, Hulu by title in an
  ApplicationFrameHost window), Minecraft Java (javaw titled Minecraft, `.minecraft` folder, its launchers),
  Android emulators (BlueStacks, LDPlayer, MuMu, Nox, MEmu) and GeForce Now / Moonlight are named distractions.
  Live (real Edge, one monitor): a background Edge window with a stand-in YouTube address and an innocent title
  was read, asked about while the work window kept focus, then minimized (IsIconic) while the other stayed open;
  the same window fully covered by the work window was never asked about, and was asked once uncovered.
  NOT tested: a real second monitor (this PC has one, so buddy placement on another screen and negative or
  mixed-DPI coordinates are only reasoned, and the 60,000 px rule is not tuned on real layouts), picture-in-picture
  windows, background-tab audio, real browser games, and whether minimizing a window on another monitor
  interrupts a game or video the user chose to leave playing.
- Released 2026-11-20: `pc-0.9.15` (GitHub release, target 8232498, asset `SwipeLater-PC.exe`, signed with
  Azure Artifact Signing, Valid and timestamped; the public `releases/latest` download was re-downloaded and its
  hash matches the signed file). Smoke-tested before release (starts, session start/stop). Release notes are in the
  release. Brandon's own PC still runs the earlier unsigned build of the same code.
- Brandon's PC (2026-11-20): the installed app is the same code, unsigned (pre-release build). His `native-host.json` pointed at a
  missing `Nogbox.exe`; `SwipeLater.exe --register-browser` rewrote it (backup in the session scratchpad). I
  rewrote `docs/pc/index.html` to three steps (no extension step) and he asked for it back as it was, so it is
  unchanged and still shows the old CONNECT BROWSERS step.
- Not verified: the extension's own counting on real YouTube Shorts and Reddit pages (DOM and scroll
  behavior can change), Edge, a packed or store-installed extension (the store assigns a new ID), long
  sessions, a real second monitor, and whether Windows always allows Back to work to take the front.

## Git and collaboration

The work is committed and pushed to `origin/ios/native-clock-ci`; it has not been merged into the default branch. Read `AGENTS.md`, `PROJECT_STATUS.md`, and Git status before editing. Preserve other agents' work. The private repository has no Apple signing secrets configured here; do not upload or publish without authorization.

## Weekly report, history and partner view · 2026-11-16

Week report and history screens rebuilt (GoalViews.swift, free = 3 newest saved weeks, rest Plus). Partner view: PC partner sharing is always on, no switch (PartnerShare.cs); record types now deployed to production, phone seals status to partners through CloudKit (Keys/PartnerWatch.swift), partner can pause the app on the PC. Deployed to CloudKit production 2026-11-16: record types PartnerStatus (ownerID, holderID, payload, signature, updatedAt) and PartnerCommand (commandID, ownerID, holderID, payload, signature, createdAt) to the CloudKit production schema, with ownerID, holderID and createdAt queryable. Not built or run on iOS yet; compile happens in CI.

> **Brand update (2026-11-17):** the iPhone app is now **SwipeLater** (was Nogbox / Lock In). The Windows app is still Nogbox. Internal IDs (`LockIn*`, `lockin.*`, `nogbox://`) did not change. See `docs/BRANDING.md`.

## Session-done screen in Rive · 2026-11-20 (uncommitted, not compiled)

Brandon said the stamp/sticker version below "sucks" and asked for a very modern redo with Rive. He approved the render of a new full-screen scene and said "Wire it in". Design notes are in DESIGN.md ("Session done").

- `apps/rive/complete/`: `scene.rml` (artboard `Complete`, 390 x 844) plus `brain.rml`, a copy of the brain artboard renumbered to client id 1, used as a component. In this copy the brain cheers once by itself 0.9 s in and its own confetti is hidden. View model `Complete`: strings `focused`, `lead`, `task`, `streakFrom`, `streakTo`, `l1`-`l3`, `l5`-`l7` (day letters, today is fixed "Today"); numbers `p1`-`p3` (past days finished, 1 or 0) and `footer` (1 = draw the preview buttons, the app sets 0); booleans `newDay` (streak rolls over) and `still` (Reduce Motion: Settled state, brain paused through `isPaused`, no drift).
- State machine `Complete`, three layers: Main (Play, or Settled when `still`), Streak (Streak Beat, or Streak Static when `still` or not `newDay`), Ambient (drift unless `still`). The choices are made on entry, so the app writes every value before the first frame. Headless renders proved both (values preset in a scratch copy).
- Published `complete.riv` is in `apps/ios/LockIn/Resources/Rive/`. Re-publish with `rive apps/rive/complete --publish` and copy `build/complete.riv` over after any change.
- `SessionDoneView.swift` (new): the Rive view full screen (fit contain, top aligned, starts 350 ms after the cover slides up), SwiftUI footer ("Next time: …", black "Keep it" pill, "Change task", or "Done" with no task), a reminder pill at the top when the daily nudge is off, clear Text views for VoiceOver and the UI test ids (`completion-card`, `completion-minutes`, `first-lock-in-stamp`, `completion-keep`/`-change`/`-done`/`-nudge`). Success haptic when the ring closes, a light tick when the number rolls. Falls back to `CompletionCard` if the file is missing.
- `FocusView.swift`: the completion sheet is now a full-screen cover with `SessionDoneView`; `completeSession` records the streak before and after; the separate streak screen only shows when the completion screen is off (UI tests that ask for it).
- `Streak.swift`: `StreakStore.around()` gives the seven day letters around today and whether the three days before were finished. `CompletionInfo` gained `streakBefore`/`streakAfter`.
- Layout check (math, not rendered on device): the panel ends at 666 of 844 pt; the SwiftUI footer starts about 9 pt below it on iPhone SE and 6 pt below on the 13 mini. Tight but clear.
- NOT verified: compile (needs CI), real device look, haptic timing, VoiceOver order, the trailing space in "locked in on " surviving data binding on device (it does in the authored default).

## Rive animations · 2026-11-20 (brain, stamp, streak wired into the iOS code; pushed e010502; TestFlight export built)

- `apps/rive/brain/`: BrainExact mascot. States: idle breathing, blink (own layer), win cheer (squash, jump, star eyes, sparkles, confetti), sleepy. View model `Brain`: trigger `win`, boolean `sleepy`. Body art is `BrainBody0.png` with the baked sparkles removed (the iOS asset is unchanged).
- `apps/rive/lock/`: hold-to-lock button in the riso palette. View model `Lock`: boolean `holding`. 1.2s linear charge, slam + burst on completion, 220ms unwind on early release. The "Paper (preview ground)" shape is for the previewer only; delete it where the app supplies its own paper.
- Rive CLI 1.10.0 installed at `~/.rive/bin` (added to the user PATH). Preview with `rive apps/rive/<name>`. All four compile with 0 errors; frames were rendered headless in the CLI renderer.
- `apps/rive/stamp/`: completion stamp (riso red + blue misregistration ghost). View model `Stamp`: triggers `slam`, `clear`; strings `title`, `sub` (default "LOCKED IN" / "FIRST LOCK-IN · DAY 1"). Bundles `Onest.ttf` (copied from `apps/ios/LockIn/Resources/Fonts`, variable font, weights set with `TextStyleAxis`). Text uses `fitFontSize` so long titles shrink.
- `apps/rive/streak/`: week row of five stickers. Artboard `Week` (default) nests five stateful `Sticker` components (each needs a `NestedStateMachine` and a `ComponentAsset`, or nothing runs). View model `Week`: numbers `day1`..`day5`, 0 empty, 1 finished, 2 rest day. The app should write them about 120ms apart for the ripple. Day labels and the count-up number stay in SwiftUI.
- **Wired in (2026-11-20, same day):** signed in with `rive login`, then `rive . --publish` in brain, stamp, streak (paper preview shapes deleted first) gave `apps/rive/<name>/build/<name>.riv`; copies live in `apps/ios/LockIn/Resources/Rive/`. `project.yml` and `project.testflight.yml` add the `Rive` package (`rive-app/rive-ios` from 6.30.1, product `RiveRuntime`) to the LockIn target. `LockIn/Rive/RiveClip.swift` wraps the runtime's legacy `RiveViewModel` (deprecated upstream, still in 6.x; expect deprecation warnings) with auto-bound view model instances and three views: `RiveWeekRow`, `RiveStampView`, `RiveBrainCheer`.
- `StreakView.swift`: the five-circle row becomes the Rive sticker row on a newsprint strip (their ink outlines need a light ground; the screen is dark). Day names stay SwiftUI. Rest days still show as empty (`StreakStore.week()` does not expose them; kind 2 is unused).
- `CompletionCard.swift`: the top slot is the Rive stamp (first ever session, replaces the text stamp) or the Rive brain `win` cheer (every other session). The old `first-lock-in-stamp` accessibility id moved to the "First lock-in done." label so the UI test still finds a static text.
- Reduce Motion (or a build without the .riv) keeps the old static SwiftUI art. Rive clips are not used under Reduce Motion because the stickers pop and the stamp slams.
- **Lock is NOT wired.** The app starts a session with `SlideToLockIn` (a slide), and its holds (`HOLD TO LET OUT`, `HOLD TO SET MY INTENTION`) are 2 s print-style buttons, so the 1.2 s charge-and-slam disc has no control to replace. Needs a product call. Its .riv is not published or bundled.
- **Watermark:** the account is on a Rive plan with the splash screen, so every published .riv carries the Rive watermark. Check a build before TestFlight; fix is a paid plan, then re-publish and re-copy the three files.
- NOT verified: nothing has been compiled (CI is the only iOS compiler and nothing is pushed), no real-device look or feel check, the stamp and brain sizes on iPhone SE are estimates, and the `Rive` package version was picked from the latest release tag.
