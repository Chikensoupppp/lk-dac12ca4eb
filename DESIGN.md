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

## Session done (2026-11-20, approved from a Rive render, built in SwiftUI)
- `SessionDoneView.swift`, drawn natively on a 390 x 844 design frame scaled to the screen. The approved
  design and timing live in `apps/rive/complete` (reference only: the Rive runtime is not in the app,
  because Rive's free plan puts a full-screen splash over every runtime file).
  It replaces the completion card and, for today's first session, the separate streak screen.
- Idea: the ring closes. A honey ring (gradient `#F4C26E` to `#D9832E`) draws shut around the brain,
  pops with a warm bloom and a spark burst; the brain cheers; the time lands (Onest 800, 66 pt);
  "locked in on <task>"; a week panel with today in the middle fills today, and on a new day a spark
  flies into the streak number, which rolls over. White-cream ground `#F6F3EC` with the onboarding's moving
  halftone dots (`HalftoneField`) low on the screen; they ripple when today fills and when the streak rolls.
- Rejected before it: small clip-art animations (stamp, sticker row) dropped into the old layouts.
- Buttons and the reminder pill sit inside the safe area (black pill "Keep it", "Change task").
  The streak number rolls with SwiftUI's numeric text transition.
- Reduce Motion or Low Power Mode: the finished picture at once; the brain is still, the ground is still.
- Borrowed from: Apple Fitness (closing ring + burst), Duolingo (rolling streak number, built in Rive),
  Headspace (one calm hero, little text).

## Slide 3, the real hours (2026-11-20, Apple Screen Time style)
- Brandon: make the hours pop, keep everything else minimal, Apple style. `LockInReport/RevealView.swift`:
  grey "Daily average", the hours as the one big thing (SF Pro bold 132 pt digits, 50 pt grey units,
  like Screen Time and Fitness), one orange line against the guess ("4 hours more than you guessed"),
  "That's 152 days a year." in grey, and a light "Most used" card (real app icons, thin bars, top 3).
  No receipt, stamp, pickups, outlined compressed type or slide tag. Preview: docs/design/reveal-apple.png.

## Stand-in app icons (2026-11-20)
- Anywhere the app shows apps that aren't the user's own (slide 5 pings, "What pulls you in?", the PC
  slides, the last slide's websites tile): `AppKindIcon`, an iOS-style squircle in that kind's usual
  colors with one white symbol (video red play, social pink heart, games purple controller, chat blue
  bubbles, shopping orange bag, news grey paper, web blue globe). Brandon: letter tiles were hard to get.
  Never a real app's logo or look. The user's own apps are always Apple's real icons (`Label(token)`).

## End of the intro (2026-11-20)
- Show real data from the user's own answers on the last slide (plan task and minutes, end time, the
  apps they picked). Never placeholder apps or features that don't exist.
- Free vs Plus on the time slide is information, not a choice; the paywall is the one place to buy.
- Paywall plans: one row each, billed price big with its period ("/ year"), per-month only as a note.
- PC slides (`PCSteps.swift`): a print-style laptop (ink lid, cream screen) with real PC features only:
  the desk buddy's "Is this for your work?" and Save for later. Preview `docs/design/pc-slides.mp4`.

## Free weekly Locked session (2026-11-20, not yet seen on device)
- Free users get one Locked session a week; Plus is every session. Shown once, after the Plus offer
  ("Not now"), as `FreeLockGiftStep`: "One locked session a week, on us."
- Idea: a gift ticket. A blue riso ticket ("ADMIT ONE / LOCKED SESSION", stub "1x EVERY WEEK", torn
  notches and a dashed tear line) tips up onto the page, a red FREE stamp slams onto it (heavy haptic,
  ticket squish, dot ripple), the brain hops onto the stub, a shine sweeps, then "Unlimited with PLUS"
  with a sunflower infinity disc. Newsprint ground with the moving halftone dots; color on the objects.
- On the Focus screen the Locked switch shows a "1 free" tag while it lasts, then "Plus".

## Copy
- Short labels and one-line status only. No explanatory, legal or how-to paragraphs.

## Do
- Support Dynamic Type and Reduce Motion. 44 pt minimum targets.

## Don't
- No pulsing, timers or flashing for pressure. No emoji icons. No extra chrome in a running session.
