# SwipeLater's block screen

What people see when they open an app that a session blocked: SwipeLater's own screen instead of
iOS's grey one. Option A "paper" (mock: `docs/design/ios-block-screen.html`, picked 2026-11-20).

- Cream paper background, the brain, the app's name: "Instagram can wait." / "You're locked in.
  18 min left. It'll still be here after." Buttons: **Back to focus** (closes the app) and
  **Swipe it later** (closes it and sets a reminder for the session's end).
- Locked mode (Plus): "Locked till 4:25. No way out this time. That was the deal." One button.
- Apple fixes the layout (picture, title, text, two buttons, system font, no animation). Only
  colors, the picture and the words are ours.

## Code

- `apps/ios/LockInShield/` draws it (shield configuration extension).
- `apps/ios/LockInShieldAction/` handles the buttons (shield action extension).
- `apps/ios/Shared/ShieldNote.swift` has the words and the session end time. The app writes it when
  shields go on (`RestrictionController.begin`), the monitor writes it for Plus "Lock by itself".
  Tests: `LockInTests/ShieldNoteTests.swift`.
- `project.yml` (simulator CI) builds both. `project.testflight.yml` defines them but does not embed
  them yet (the two commented `- target:` lines), because export fails until Apple approves them.

## Apple setup (Brandon, once)

1. developer.apple.com > Certificates, IDs & Profiles > Identifiers > **+** > App IDs > App.
   Description `SwipeLater Shield`, Bundle ID (Explicit) `com.brandon132199.lockin.shield`.
   Tick **Family Controls** and **App Groups**. Register. Then edit it: App Groups > Configure >
   `group.com.brandon132199.lockin`.
2. Same again for `SwipeLater Shield Actions`, `com.brandon132199.lockin.shieldaction`.
3. Ask Apple for Family Controls (Distribution) for each of the two IDs, the same form used for
   the app and the report: developer.apple.com/contact/request/family-controls-distribution
4. When both show as approved, uncomment the two lines in `project.testflight.yml` and push.

## Not verified

Never compiled here (no Xcode on Windows) and never seen on an iPhone. Check on a device: the
brain picture size, the app name showing (Apple gives it to the extension), the minutes left, the
Swipe it later reminder (needs notification permission), and Locked mode.
