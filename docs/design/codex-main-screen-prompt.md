Redesign the main screen of my iPhone app so it feels special, not generic or AI-made. Build it in SwiftUI in this repo. Do not push, commit, or tag anything. Show me before and after pictures first.

APP
Nogbox is a focus app for teens and young adults. You pick minutes and tap LOCK IN. Apple Screen Time blocks your chosen apps until the timer ends. The mascot is a cute pink brain (round, glossy, big low eyes, no limbs). Image: docs/pc/brain.png.

FILES
- apps/ios/LockIn/FocusView.swift (the main screen)
- apps/ios/LockIn/Clock/ (the timer ring, colors in Matte.swift)
- Read AGENTS.md, PROJECT_STATUS.md and HANDOFF.md first.

LOOK TO USE
- Flat cream background #F6F3EC (not orange cream).
- Ink #171513, soft gray #6F6A60, hairlines #E4DED3.
- At most one warm accent, used on objects only.
- Matches the Accountability partner screen in apps/ios/LockIn/Keys/KeyViews.swift.

THE BRAIN: DO NOT TOUCH IT
The brain mascot is finished. Do not redraw, edit, recolor, crop, replace, or re-create it, and do not add new faces or art for it. Use the existing image (docs/pc/brain.png, and whatever brain assets the app already uses) exactly as it is. If the app already has a brain in the code, leave that code and asset alone. You may only place it and move it (position, size, a gentle bob or breathing scale, a spring when you tap). Never change how the brain itself looks.

THE IDEA (pick this, do not blend with other ideas)
The brain is the clock. It sits inside the ring above the time. The ring and the empty space around it show what the brain is doing, using only motion and placement of the unchanged brain: it rests calmly before you start, and during a session it stays with you inside the ring. The empty space on the screen can hold a short thought bubble such as "25 min. Let's go." Add two or three hand-drawn marks (a crooked pencil arrow toward LOCK IN, tally ticks on the ring) so nothing feels perfectly centered or machine-made. The hand-drawn marks must not touch or overlap the brain art.

MUST KEEP
- Every existing feature and button: weekly goal, accountability partner, restrictions, task pill, minutes selector, hold-to-start coach, session states, Lock Screen countdown.
- Accessibility labels and identifiers (UI tests use them).
- Works on a small iPhone and at the largest text size. Respect Reduce Motion.
- No help paragraphs or long text.

DO NOT
- No purple or blue gradients, glow, emoji, or rows of identical cards.
- Do not draw or change the brain in code. Use the existing image only.

SKILLS (use them if you have them; if not, follow these rules, which are copied from them)

design-to-production (the process)
1. Read the existing code, theme colors and neighboring screens. Match them.
2. Decide type, color tokens, spacing, shape and motion on purpose. Real content, no lorem.
3. Cover states: empty, loading, error, pressed, disabled. Touch targets at least 44pt.
4. Render it and look at it. Write the 2 to 4 weakest things. Fix them. Look again.
5. Report: what you made, the idea, what you checked, what you could not test.

apple-design (how it moves)
- Respond on touch-down, not release. Feedback is continuous, never only at the end.
- Use springs, not fixed-time animations. Default: no bounce (damping 1.0, response 0.3 to 0.4 s). Add a little bounce (0.8) only after a flick or throw.
- Every animation can be interrupted and reversed. Start from the current on-screen value.
- Things leave the way they came in. Hint at where motion is going.
- Reduce Motion: replace slides and springs with a short cross-fade.
- Type: large text gets tighter letter spacing, small text slightly looser. Tight line height on big text.
- Simplicity is not minimalism: cut what is not needed, keep what gives the screen purpose.

taste-skill (not generic)
- One idea taken from the subject itself, not from the category. Test: would it still work for a competitor? If yes, it is too generic.
- Avoid: symmetric rings, identical rounded cards, centered stacks, soft gradients, little labels above everything, icon rows.
- Prefer: asymmetry, one dominant thing, big type, real objects, hand-made marks.
- Every section carries the idea, not only the first screen.

impeccable (final critique)
- Judge the render, not the code: hierarchy, spacing rhythm, contrast, alignment, density, polish, tone.
- Contrast at least 4.5:1 for text. Do not use light gray text on cream.
- Remove decoration that does not help. Fix, then look again.

VERIFY
iOS cannot build on this Windows PC, so say plainly what you could not run. Make an HTML or image mock of the result and send it to me before any push.
