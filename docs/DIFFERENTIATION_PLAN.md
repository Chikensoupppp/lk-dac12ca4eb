# Plan: how Lock In stays different from Opal

Written 2026-11-05. This is a plan. Nothing here is proven. Read with `docs/POSITIONING_RESEARCH.md` (competitor notes) and `docs/WEEKLY_REPORT.md`.

## The honest starting point
- If Lock In is "Opal with different branding", it loses. Opal has the users, the money, and the name.
- A correction: Freedom already blocks across phone and laptop (see POSITIONING_RESEARCH). So "phone plus PC" alone is not new. What no source mentioned is one tap that starts both devices and also opens the PC workspace. That is an absence in search results, not proof.

## The one-line promise
"Tap once. Your phone locks and your PC opens your work."
Test: if the line also fits Opal, it is not ours. This one does not fit Opal.

## Five pillars (what makes it different)
1. **One tap, both devices, work opens.** Phone and PC start together. The PC opens the saved work (project, docs, music). When the session ends, it restores the old setup.
2. **Work first, blocking second.** The session starts with "What are you working on?" Blocking is one extra, not the front door.
3. **Honest proof.** Show what is really on. Warn if Screen Time access is turned off mid-session. Never say "protected" unless it is. This answers the "silent failure" complaint.
4. **Real numbers on first open.** The PC scan and Apple's phone report show real data at once. Opal waits a week for its report.
5. **Fair price.** Free app stays open. Plus adds the PC parts. No subscription trap. See `docs/PRICING_PLAN.md`.

## Who it is for (decide one group)
Pick one first group. Examples: students, or people who work on a PC all day. Do not aim at everyone. Decision needed from Brandon.

## Phases (each has a gate)
**Phase 0. Prove the core. Build only the tap-once path.**
- QR pairing, Windows tray app, workspace launch, restore after.
- Give it to 10 people in the chosen group for one week.
- Gate (a starting guess, adjust later): at least 6 of 10 use it on 3 or more days, and at least 5 say they would miss it. If not, change the idea before building more.

**Phase 1. Make setup easy.**
- Build the welcome flow from `docs/design/welcome-human.png` and `facts-human.png`.
- Start a first session in under 10 seconds. Ask for Screen Time later, not first.

**Phase 2. Make it a habit.**
- Weekly goal page, reminders, Sunday report, first-open "last 7 days" screen. See `docs/WEEKLY_REPORT.md`.

**Phase 3. Make money.**
- Plus through Apple In-App Purchase (needs App Store Connect setup). Soft offer after the first finished session.

**Phase 4. Grow.**
- Short video of the tap-once moment. Posts where the chosen group already talks. Not tested yet.

## Do not build yet
Gamification, friends, widgets, many blocking modes, Android.

## What to measure
- People who pair a PC.
- Sessions finished per week.
- Still active after 7 days.
- Free to Plus rate (only after Phase 3).

## Words for the App Store
- Lead with getting work done.
- Use words people search ("focus", "app blocker") but describe blocking as one feature.
- Do not name Opal or other apps in marketing.

## Risks
- Apple may require approval for Screen Time use before release. Not checked.
- The Windows tray app and pairing are not built. The whole edge depends on them.
- One person cannot build everything. The gates stop wasted work.
- Competitors can copy features. The hardest to copy is the working phone-to-PC path.
- All claims about competitors come from reviews and help pages, not from using their apps.

## The two core differences (saved 2026-11-05, decided by Brandon)
Everything else in this plan supports these two. Build them first. If they do not work, the app is mostly the same as Opal.

### 1. Phone and PC work together
- One tap on the phone starts a session on both devices. Ending the session ends it on both.
- Needs: QR pairing between phone and PC (the phone side can scan a QR code today), a Windows tray app that listens for start and stop, and a safe way to recover if the link drops.
- Status: not built. Pairing and the Windows app are open work.
- Note: Freedom already blocks across phone and laptop. This alone is not new. It becomes new together with difference 2.

### 2. The PC opens your work
- When a session starts, the PC opens the saved work for that task: apps, files, sites. When the session ends, it restores the old setup.
- Needs: a saved workspace per task, a launcher on the Windows side, and a restore step. Also the "What are you working on?" start on the phone.
- Status: not built. This is the strongest difference. No source in our research mentioned another app doing it. That is an absence in search results, not proof.

### Definition of done for both
- On a real phone and a real Windows PC: tap Start on the phone, the PC opens the workspace within a few seconds, and ending the session restores the PC.
- Tested with at least one real person besides Brandon.

### Build order
1. QR pairing and a tray app that can receive "start" and "stop".
2. Workspace launch and restore.
3. The "What are you working on?" start on the phone.
4. Only then: welcome flow, goals, weekly report, Plus.
