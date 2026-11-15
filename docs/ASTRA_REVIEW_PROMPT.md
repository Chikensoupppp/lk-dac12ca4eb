# Prompt: full product review of Lock In (for Astra or any strong AI)

Copy everything below the line into the AI.

---

You are a senior product designer, iOS engineer and growth strategist. Use your deepest
reasoning. Take your time. Go through the whole app before you give any advice.

## The app

Lock In is a focus app for teens and young adults. Purpose: "Lock In helps you finish what
you're working on." It is not "block everything".

Repo: https://github.com/Chikensoupppp/lk-dac12ca4eb (branch `ios/native-clock-ci`).

Parts:
- iPhone app, SwiftUI: `apps/ios/LockIn/`. A focus timer with Screen Time app blocking
  (FamilyControls), a 12-slide first run (`Onboarding/`), a brain mascot coach
  (`Onboarding/FocusCoach.swift`), streaks (`Streak.swift`), weekly goals and a Sunday report
  (`Goals/`), friend "Key Holders" who can unlock you (`Keys/`), a hard-to-quit flow (`Quit/`),
  a Plus subscription with Locked mode (`Plus/`), and a home screen widget (`LockInWidget/`).
- Windows desk buddy: `apps/windows-companion/`. A pink brain on the PC desktop. It pairs with
  the phone, watches which app is in front during a session, asks before you open a
  distraction, and gives a gentle reminder after long scrolling on YouTube Shorts or Reddit.
- Browser extension for Chrome, Edge and Firefox: `apps/browser-extension/`. It only counts
  scrolling on Shorts and Reddit feeds. No page content leaves the PC.

Read these first: `AGENTS.md`, `PROJECT_STATUS.md`, `HANDOFF.md`, `DESIGN.md`,
`docs/design/DESIGN_SKILLS_FOR_AI.md`, `docs/PC_BUDDY_PROTOCOL.md`,
`docs/PC_BUDDY_BLOCKING_PROBLEM.md`, `docs/ONBOARDING_PAYWALL.md`, `docs/PRICING_PLAN.md`,
`docs/COMPETITOR_FEATURES.md`, `docs/FEATURE_WISHLIST.md`.
Look at the pictures in `docs/design/` (newest are best), for example `tutorial-v2.png` and
`brain-mascot-exact.png`.

## Your job

1. Walk through the app like a new user: first launch, the 12 intro slides, the paywall, the
   coach, a first session, finishing, quitting early, the streak, goals, keys, the widget, and
   pairing the PC. Read the real code for each screen; do not guess from file names.
2. Compare it with real competitors: Opal, one sec, Forest, Freedom, Cold Turkey, ScreenZen,
   Brick, Jomo, Finch, Duolingo (for habit and mascot ideas). Say what they do better and
   what Lock In does that none of them do.
3. Find what makes Lock In stand out, and how to make that sharper.
4. Find what stops people from paying, and what would make them pay.

## What to return

Short, plain English. Sort by impact. For each item: what is wrong or missing, why it matters
(with evidence: code file and line, a competitor, or a known study), the exact fix, and the
effort (small / medium / large).

Sections:
- Top 10 changes, most impact first.
- First run and onboarding: drop-off risks, too many slides, permission and paywall timing.
- Core loop: start, focus, finish, come back tomorrow. What makes someone return on day 2 and day 7.
- The mascot and the PC buddy: how to make them a reason to talk about the app.
- Pricing and paywall: what is free, what is Plus, price, trial, and the wording.
- Standout features: 3 to 5 ideas that no competitor has and that fit this app.
- Marketing: the one-line pitch, App Store screenshots plan, TikTok and short-video angles,
  and who to target first.
- Bugs and risks you found in the code (with file and line).
- App Store review risks (Screen Time, subscriptions, privacy).

## Rules

- Respect the owner's taste rules in `DESIGN.md` and `docs/design/DESIGN_SKILLS_FOR_AI.md`:
  no explainer paragraphs in the app, no dimmed tooltip tours, no scary mascot, kind tone,
  calm colors.
- Privacy is a selling point: no screenshots, no keylogging, no reading page content, no cloud
  AI on browsing data. Do not suggest breaking that.
- Do not invent numbers, reviews or studies. If you are not sure, say so.
- Do not change code. This is a review. If you want to show a fix, describe it.
- End with the 3 things you would do this week if you owned the app.
