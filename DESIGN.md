# Lock In design

Rewritten 2026-11-04. The cold dark titanium look is gone. Brandon chose "A2 Cream"
(mock: `docs/design/cream-look.html`, `cream-look.png`).

## Intent
A warm, friendly focus timer. One soft object: a cream disc with a caramel ring. Everything
else stays quiet and short. No help paragraphs in the app.

## Look
- Light only (`.preferredColorScheme(.light)`). Warm cream gradient `FocusBackdrop`
  (`#FFFBF3` to `#F8ECD6`).
- All colors live in `enum Cream` (`Clock/ClockBody.swift`). Ink `#45321F`, soft ink `#7D6249`
  (about 5:1 on cream). Never pure black or grey.
- Clock: white-to-cream disc with a warm soft shadow, track `#EFE1C8`, thick rounded ring
  `#EFC38A` to `#D98550`.
- Type: SF Rounded (`Cream.rounded`). Light large numerals. Labels 11 to 13 pt, semibold or bold,
  tracking 2 to 4.
- Shape: continuous rounded rectangles, radius 14 (selected cell), 18 (tray), 24 (buttons).
- Buttons (`CreamButtonStyle`): prominent = butter `#F2C890` with brown text and a warm
  shadow. Quiet = cream fill, 2 pt `#E9D8BB` edge, `#7A5A3E` text.

## Layout
- Clock centered, sized from available height. Controls anchored to the bottom.
- One prominent button per screen. Quiet variant while a session runs.
- Sheets reuse `FocusBackdrop` and `CreamButtonStyle`. No stock grouped lists or system blue.

## Copy
- Short labels and one-line status only. No explanatory, legal or how-to paragraphs.
- An error gets one short sentence. If the user can fix it, give a button, not instructions.

## Motion
- Smooth 0.7 s state change; 0.2 s ease with Reduce Motion. The timestamp-driven readout is never
  animated by its parent. Haptics: impact on lock, success on completion.

## Do
- Support Dynamic Type and Reduce Motion. 44 pt minimum targets.

## Don't
- No dark surfaces (except the camera scanner), no cool greys, no emoji icons, no extra chrome in
  a running session.
