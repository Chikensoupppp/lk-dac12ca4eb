# Design rules for Lock In (for any AI helper, e.g. DeepSeek or Codex)

Read this before you design or change any screen, icon, mascot or animation in Lock In.
Written 2026-11-13 from the owner's feedback and the design work so far.

## 0. The brain file to use (most important)
- The mascot brain is the **exact artwork** in `docs/design/brain-mascot-exact.png` (black background
  removed). `docs/design/brain-mascot-chosen.png` is the comparison picture it came from.
- Do NOT redraw the brain in code. Owner rejected code redraws ("horrible") and dense realistic folds ("too scary").
- Use the bundled exact art in both apps. Keep the iOS and Windows copies in step
  (`apps/ios/BrainArt/BrainDrawing.swift`, `apps/windows-companion/Watch/BrainArt.cs`).
- Expressions (look, keen brows, cheer grin, sleepy, sad, rotten marks) go ON TOP of that art. Never change the art itself.
- `scripts/extract-brain-assets.py` rebuilds the assets from the owner's comparison image.

## 1. Who and why
- Lock In is a calm, premium focus timer for teens and young adults, with a desk buddy on the PC.
- Purpose: "Lock In helps you finish what you're working on." Not "block everything".
- Tone: kind, short, plain English. Never blame, shout, shame or guilt. No help paragraphs in the app.

## 2. Look and feel (taste rules)
- Focus screen: matte black, a calm glowing ice-blue ring, one machined object. Light is slow; nothing flashes.
- Cream/print look on the phone sheets and onboarding: paper `#E7E8E3`, panel `#F3F4F0`, ink `#1B1B1B`,
  riso blue `#3255A4`, sunflower `#FFB511`, alarm `#D25A44`. Use tokens (`enum Matte`, `Cream`), never raw hex in views.
- Too many bright colors feel overstimulating. Use one base and one or two meaningful accents.
- Mascots: cute, round, glossy, big low eyes, no stem or limbs. No realistic anatomy, no dense dark lines,
  no blue realistic eyes. Soft, plush, friendly, never scary.
- Avoid the generic AI look: symmetric rings, identical rounded card grids, orbiting tiles, purple-blue
  gradients, default fonts, emoji used as icons. Use asymmetry, hand-drawn marks (circles, arrows, stickers, tape),
  one real metaphor per screen.
- Typography: the app uses SF Rounded (`Cream.rounded`) for UI, and bold condensed display type on print-style
  screens (Anton-like). Labels 11 to 13 pt, tracked. Running text in full ink, 16 px or more.

## 3. Process (always, in this order)
1. **Study first.** Before any new screen, research 3 to 6 real apps that solve the same thing
   (Duolingo, Slack, Opal, Forest, Cold Turkey, Headspace, Finch, the platform's own apps). Name what you borrow.
   The owner said: "study what other people do and take inspiration from that."
2. **Pick one direction** that fits the product. Write it in `DESIGN.md`.
3. **Mock it** (HTML is fine), render it, look at the picture. Show the owner the picture as a file.
4. **Critique** the render: hierarchy, rhythm, contrast, density, consistency, tone. Write the 2 to 4 weakest points.
5. **Fix and re-render.** Stop when what's left is a taste call.
6. **Verify behavior** on a real device or simulator when possible; say what was not checked.
7. **Report** in short plain language: what you made, the idea, what you verified, what you could not test.

## 4. Coach and tutorial rules (first-run)
- Do NOT use a dimmed overlay with tooltips ("sucks", owner said).
- A mascot coach (the brain) guides the user through doing the REAL thing:
  Working on -> how long (try 25) -> hold to lock in -> "FIRST LOCK-IN · DAY 1" stamp + confetti.
- The user taps the real controls. No "Next" buttons. Everything not being taught fades back. Skip is always visible.
- Coach copy is short and enthusiastic: "First up!", "Try 25.", "Ooh, tools!", "Hold it… and LOCK IN!", "We did it!"
- Tool buttons (Goal, Keys, Apps) are explained the first time each is opened, not in the tour.
- Reduce Motion: keep fades and color; drop travel, squash, shake and confetti.

## 5. Motion rules (animate skill)
- Animate only when it helps: feedback, spatial continuity, state change, or a rare delight moment.
  Never animate keyboard-like, frequent actions. Keep UI motion short (150 to 300 ms).
- Use ease-out for entering, ease-in-out for moving on screen. Never ease-in on UI.
- Animate transform and opacity only. Never scale from 0; start at about 0.9 with opacity 0.
- Use transitions for things users can trigger rapidly. Use springs for gestures.
- Every animation ships with reduced-motion and (on web) hover/pointer gating.
- The focus timer readout is never animated by its parent view.

## 6. Interaction and accessibility
- Touch targets at least 44 pt. Support Dynamic Type (test the largest size) and VoiceOver labels.
- Contrast: body text at least 4.5:1. The soft secondary text `#575A55` on paper is about 5.5:1.
- States: default, pressed, focus, disabled, empty, loading, error. Cover all of them.
- Haptics: heavy impact on lock, success on finish, warning on early end.
- Never block reading with animation. Never flash for pressure.

## 7. Copy rules
- Short labels and one-line status only. No explanatory, legal or how-to paragraphs in the app.
- Kind, never mean: "Videos can wait. Ready to go back?" not "Stop wasting time!"
- Give the buddy a voice: plain, warm, one idea per sentence.

## 8. Privacy rules that also shape design
- No screenshots, no keylogging, no reading page contents in the product. Names and window titles only.
- Browser help only counts scrolling and sends a URL only after the user taps "Save it for later".
- No paid AI APIs and no cloud processing of browsing data.

## 9. Things the owner has rejected (do not repeat)
- Code-drawn detailed mascot art ("horrible").
- Dense dark folds and realistic blue eyes on the mascot ("too scary").
- A dimmed tooltip tour (tutorial "sucks").
- Limbs and stems on the brain (earlier feedback). The 2026-11-13 sneakers/arms idea was only a reference, not chosen.
- Pure time pools per app ("I don't want time limits per app").
- Making people pick every app before every session ("too tedious").
- Yes/no "it's for work?" questions as the only control (people just lie).

## 10. Where things live
- `DESIGN.md`: the project's design system and decisions (read it first).
- `enum Matte` (`apps/ios/LockIn/Clock/Matte.swift`), `Cream` tokens, `PrintScaffold` (`Onboarding/Print.swift`).
- Brain art: `docs/design/brain-mascot-exact.png`; code in `BrainDrawing.swift` and `BrainArt.cs`.
- Walkthrough: mock `docs/design/tutorial-mock.html`, animated prototype `docs/design/tutorial-proto.html`
  (video `tutorial-proto.mp4`), poses in `docs/design/tutorial-assets/`.
- Design history and references: `docs/design/` (many mocks and PNG renders; the newest are the best reference).

## 11. Quick checklist before you hand back a design
- [ ] Studied 3 to 6 real references and named what was borrowed
- [ ] Brain uses the exact art; expressions only on top
- [ ] One base color plus at most two accents; tokens, not raw hex
- [ ] No symmetric ring / identical card grid / generic AI look
- [ ] No dimmed tooltip tour; the coach guides real actions
- [ ] Short copy, kind tone, no help paragraphs
- [ ] Reduced motion, Dynamic Type, 44 pt targets, VoiceOver labels
- [ ] Rendered, looked at, critiqued, fixed; picture sent as a file
- [ ] Said what was not verified (device, screen reader, other browsers)
