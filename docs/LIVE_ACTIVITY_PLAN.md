# Lock screen countdown (Live Activity) - plan

Status: plan only. Nothing built. Written 2026-11-04.

## What the user sees
- Start a session: a countdown appears on the lock screen and in the Dynamic Island.
- It counts down by itself. The app does not need to stay open.
- Session ends or user taps End Session: it goes away.
- Look: the Cream design in `docs/design/cream-look.png` (warm ivory card, caramel ring, brown text).

## Why this is a good fit
`SessionTiming` already stores only absolute timestamps (`startedAt`, `duration`, `endsAt`). A Live Activity can show a system-driven countdown from an end date with `Text(timerInterval:)`. No push server, no per-second updates.

## Pieces to build
1. New app extension target `LockInWidgets` (WidgetKit + ActivityKit). Bundle ID `com.brandon132199.lockin.widgets`.
2. `LockInActivityAttributes` in `Shared/` (session id, start, end, minutes). Used by app and extension.
3. `LiveActivityController` in the app: `start(record)`, `end()`. Called next to `restrictions.begin/end` in `FocusView` (`startSession`, `endSession`, `completeSession`, launch reconcile).
4. Views: lock screen card, Dynamic Island compact, expanded, minimal. `Text(timerInterval:)` for the time, `ProgressView(timerInterval:)` for the ring/bar.
5. Info.plist key `NSSupportsLiveActivities = YES` in the app (via `INFOPLIST_KEY_` in `project.yml` and `project.testflight.yml`).
6. Shared cream color tokens in `Shared/` so the app and the widget use one palette.

## Rules to keep
- The activity never owns the time. App store stays the single source of truth.
- Launch reconcile: if no active session, end any leftover activity. If active and no activity, start one.
- Reduce Motion and Dynamic Type respected. Contrast checked on the cream card.
- Live Activities can be turned off by the user in Settings. If `areActivitiesEnabled` is false, do nothing and do not show an error.

## Apple-side steps (account)
- A new App ID `com.brandon132199.lockin.widgets` must exist. Automatic signing with the API key may create it on first build. If not, create it in Certificates, Identifiers & Profiles (no special capability needed).
- No Family Controls entitlement needed on the widget extension.

## Build and test
- Windows has no Xcode. Everything compiles only in GitHub Actions (macOS). Private repo has no free minutes, so the repo goes public for the build, then private again.
- Unit tests: attributes encoding, controller start/end rules with a fake activity client (the real `Activity` cannot run in unit tests).
- CI render: simulator screenshot of the app. Simulator can show the lock screen activity only partly; real check is on the iPhone via TestFlight.
- TestFlight workflow: unsigned archive then `codesign` entitlement trick. A new extension must be embedded, then export re-signs it. Needs one check run (no upload) before a tag.

## Risks (not verified)
- The unsigned-archive flow has not been tried with a widget extension. Export may need the new App ID registered first.
- Dynamic Island layout can only be judged on a real iPhone with Dynamic Island (Brandon's phone has one).
- Live Activities end after 8 hours on screen, plus 4 hours on lock screen. Max session is 90 minutes, so this does not matter.

## Order
1. Cream tokens in `Shared/` + widget views (small, visible).
2. Controller + wiring + tests.
3. CI check run, fix, then upload a TestFlight build.
4. Test on the iPhone.
5. Later: the full Cream restyle of the main app.
