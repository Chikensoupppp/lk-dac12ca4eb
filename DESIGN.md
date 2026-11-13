# Lock In design

Updated 2026-11-04. The Focus screen is now **matte black with a living background**
(mocks: `docs/design/matte-black-animated.html`, `docs/design/focus-motion.html` and `.mp4`).
The Cream look (A2) stays on the sheets (Restrictions, PC) until they are redrawn.

## Intent
A calm, premium focus timer. One machined object (a dark bezel and a glowing ice-blue ring) on a
matte black field with slow light behind it. Everything else stays quiet and short. No help
paragraphs in the app.

## Look (Focus screen)
- Dark (`.preferredColorScheme(.dark)`). Colors live in `enum Matte` (`Clock/Matte.swift`).
  Text `#F3F5F8`, soft text `#8E97A3` (about 6.5:1 on the background; not yet measured with a tool).
- Backdrop `FocusBackdrop`: near-black gradient, three blurred glows (blue, violet, teal), rising
  dust, soft vignette.
- Clock: angular-gradient bezel, dark face, 60 dial marks, thick rounded ring in an ice gradient
  (`#B5DCFC` to `#4C8EE0`) with a soft glow, a glint circling the rim, faint ripples.
- Type: SF Rounded (`Cream.rounded`). Semibold large numerals. Labels 11 to 13 pt, tracking 2 to 4.
- Buttons (`MatteButtonStyle`): prominent = pale metal plate with dark text. Quiet = dark plate with
  a 1.5 pt edge.
- Sheets still use `CreamBackdrop` and `CreamButtonStyle`.

## Motion (all of it off with Reduce Motion or Low Power Mode, except short color fades)
- Mood (`FocusMood`): idle, running (glows pulled in and calm), last minute (glows turn amber, no
  flashing), finished (glows brighten, light sweep, ring closes), ended early (glows go gray).
- Pick minutes: the ring glides to the new length. Digits roll.
- Start: a bright edge runs around the button and one ring spreads out. Ring grows to full, then drains.
- Haptics: heavy impact on lock, success on finish, warning on early end.
- The timestamp-driven readout is never animated by its parent.

## Brain mascot (changed 2026-11-13)
- Brandon picked the soft plush brain made in Figma (`docs/design/brain-mascot-chosen.png`, Figma
  file "Lock In brain mascot"). Drawn in code to match, in both `apps/ios/BrainArt/BrainDrawing.swift`
  and `apps/windows-companion/Watch/BrainArt.cs` (keep them in step): oval wider than tall, a smooth
  round dome on top (Brandon asked for a rounder top; approved) and puffy bumps on the sides and bottom, pastel pink (#F9BAD2) with a darker lower half, soft plum outline (#6B4561), cream
  sticker edge, swirl folds and a split on top, short glossy marks, smaller eyes set wider, oval
  blush, tiny smile. All moods (sleepy to rotten) keep their marks and colors.
- Rejected: realistic dense folds with blue eyes ("too scary"), code-drawn detailed folds ("horrible").

## First-run coach (designed 2026-11-13, not built)
- Mock `docs/design/tutorial-mock.html`, animated prototype `docs/design/tutorial-proto.html`
  (poses in `docs/design/tutorial-assets/`, drawn by `LockIn.Companion.exe --draw-poses`).
- The pink brain coaches the user through a real first session: Working on, minutes, hold to lock
  in, then a "FIRST LOCK-IN · DAY 1" stamp with confetti. The user taps the real controls; no Next
  buttons. Everything not being taught fades back. Skip is always there.
- Brain poses: looks at the target (LookX/LookY), keen brows, charge-up shake while holding, star
  eyes and a big grin on each win, plus a short "YES!" / "NICE!" sticker and a haptic.
- Tool buttons (Goal, Keys, Apps) are explained the first time each is opened, not in the tour.
- Borrowed from: Duolingo (coach mascot, celebrate wins, learn by doing), Slack (real actions),
  Opal (tips on the real screen, first reward).
- Reduce Motion: fades only; no travel, squash, shake or confetti.

## Copy
- Short labels and one-line status only. No explanatory, legal or how-to paragraphs.

## Do
- Support Dynamic Type and Reduce Motion. 44 pt minimum targets.

## Don't
- No pulsing, timers or flashing for pressure. No emoji icons. No extra chrome in a running session.
