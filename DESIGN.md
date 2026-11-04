# Lock In design

Written from the existing app (2026-11-03). It records the identity; it does not change it.

## Intent
A precise, calm instrument for focus. One object: a titanium countdown clock. Everything else
stays quiet so the clock is the only thing that asks for attention.

## Look
- Dark only (`.preferredColorScheme(.dark)`). Near-black cool-neutral backdrop (`FocusBackdrop`).
- Material: brushed titanium and silver, built from `ClockTone.metal(...)`. Never colored accents.
- Type: SF system. Light, large numerals for time. Small caps labels, wide tracking (3 to 5 pt),
  semibold 10 to 12 pt for chrome, 16 pt semibold tracked 4 for buttons.
- Shape: continuous rounded rectangles, radius 11 (selection), 15 (tray), 18 (buttons).
- Text opacity on dark: primary 0.9, secondary 0.5 to 0.62, decorative 0.3. Do not go below 0.45
  for text people must read.

## Layout
- Clock centered, sized from available height. Controls anchored to the bottom.
- One primary button per screen (titanium plate). Quiet variant while a session runs.
- Secondary screens (sheets) reuse `FocusBackdrop` and `TitaniumButtonStyle`; no stock grouped
  lists or system blue.

## Motion
- Smooth 0.7 s state change; 0.2 s ease with Reduce Motion. Timestamp-driven readout is never
  animated by its parent. Haptics: impact on lock, success on completion.

## Do
- Keep new UI in this material. Support Dynamic Type and Reduce Motion. 44 pt minimum targets.

## Don't
- No color accents, gradients with hue, emoji icons, stock iOS list styling, or extra chrome in a
  running session.
