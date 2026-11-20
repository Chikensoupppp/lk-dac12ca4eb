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
- Both are built and embedded by `project.yml` and `project.testflight.yml`.

## Apple setup (done 2026-11-20)

`com.brandon132199.lockin.shield` (SwipeLater Shield) and `com.brandon132199.lockin.shieldaction`
(SwipeLater Shield Actions) are registered with Family Controls (Development and Distribution) and
App Groups (`group.com.brandon132199.lockin`). The team already had Family Controls Distribution,
so no new request to Apple was needed.

## Not verified

Never compiled here (no Xcode on Windows) and never seen on an iPhone. Check on a device: the
brain picture size, the app name showing (Apple gives it to the extension), the minutes left, the
Swipe it later reminder (needs notification permission), and Locked mode.
