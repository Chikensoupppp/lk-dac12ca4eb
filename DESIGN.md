# Lock In design

## Focus screen · 2026-11-16

The pink brain sits inside the dial above the time. Use the bundled `BrainExact` image at its original aspect ratio. Keep all dial marks outside the artwork. The first-run coach uses its existing expressions and takes the mascot's place while teaching.

- Paper `#F6F3EC`, ink `#171513`, secondary text `#6F6A60`, hairlines `#E4DED3`. The amber `#A97029` arc shows the selected duration while idle and time remaining during a session. Focus colors live in `Clock/Matte.swift` under `FocusPaper`.
- Onest for the wordmark and tabular countdown. Use Dynamic Type for the controls and status. Left-align the task, minutes label and primary action. Three pencil strokes cross the lower rim.
- Keep the duration picker and session action at the foot of the screen. Long content above can scroll. At accessibility sizes the picker wraps and the clock caption moves below the dial.
- The brain settles slightly higher when a session starts. Reduce Motion suppresses this movement. The clock reads the same end timestamp as the session. Start, completion and early-exit haptics stay tied to session events.

## Brain mascot (changed 2026-11-13)
- Owner correction in this session: use the exact right-hand artwork on the black background, not a code redraw. `docs/design/brain-mascot-exact.png` is that image with only its black surround removed. Identical PNGs are bundled by both apps; facial expressions and existing mood marks are layered on top. `scripts/extract-brain-assets.py` reproduces the assets from the owner's comparison image.
- The soft plush brain is now bundled as the exact raster artwork in both `apps/ios/BrainArt/BrainDrawing.swift`
  and `apps/windows-companion/Watch/BrainArt.cs` (keep assets and expressions in step): oval wider than tall, a smooth
  round dome on top (Brandon asked for a rounder top; approved) and puffy bumps on the sides and bottom, pastel pink (#F9BAD2) with a darker lower half, soft plum outline (#6B4561), cream
  sticker edge, swirl folds and a split on top, short glossy marks, smaller eyes set wider, oval
  blush, tiny smile. All moods (sleepy to rotten) keep their marks and colors.
- Rejected: realistic dense folds with blue eyes ("too scary"), code-drawn detailed folds ("horrible").

## First-run coach (implemented 2026-11-13, physical-device review pending)
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
