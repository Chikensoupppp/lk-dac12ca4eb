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

## Copy
- Short labels and one-line status only. No explanatory, legal or how-to paragraphs.

## Do
- Support Dynamic Type and Reduce Motion. 44 pt minimum targets.

## Don't
- No pulsing, timers or flashing for pressure. No emoji icons. No extra chrome in a running session.
