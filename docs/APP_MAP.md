# What fills the Lock In app (proposal)

Written 2026-11-04. Today the app has one screen plus two sheets. This maps the screens and features other apps use, and what we should add. Source notes are from store pages and rival blogs; tab names change between app versions, so check the live apps before copying anything. Proposal only; nothing here is built.

## What other apps have
- **Opal:** Home (daily screen time, focus score, pickups, streak), Blocks (pick apps and sites, focus history), Community and leaderboard, Profile and Settings (including "uninstall protection"). Focus reports need a week of data.
- **Forest:** one core loop (pick time, grow a tree), strict mode, stats, friends group focus, account sync. A teardown says the email sign-up before the first session is a friction point.
- **Timer apps in general:** break timers (short and long), ambient sounds (often paid), tasks or to-do lists, widgets, Live Activities, Apple Watch, Focus filters and Shortcuts.
- Thin results: app groups and schedules. Needs a separate look.

## Proposed app map
A bottom bar with four tabs:
1. **Focus** (exists). Clock, minutes, LOCK IN. Add: today pill (ring and streak), PC status.
2. **Progress.** Today and streak, milestone cards, weekly receipt, history list. See `docs/design/gamify-ideas.png`.
3. **PC.** Pairing status, workspace profiles ("Study", "Code"), what opens, PC Lockdown time. Our main difference. Empty state: one big SCAN QR CODE button, no paragraph.
4. **You.** Restrictions (shield apps), exit strength (Gentle, Firm, Locked), themes and icons, plan (Free or Plus), about.

## Onboarding (3 short screens, no account)
1. One line of promise and a picture. 
2. Allow Screen Time (button only).
3. Start your first session. Pairing a PC is optional and comes later.
Lesson from Forest's teardown: let people try a session before asking for anything.

## Features to add, in order
1. Today pill, ring and streak (chosen).
2. Milestone cards and weekly receipt (chosen).
3. Intent card before a session, and exit budget (our anti-quit idea).
4. Breaks: optional 5-minute break between sessions. Cheap and common.
5. Lock screen countdown (Live Activity). Plan: `docs/LIVE_ACTIVITY_PLAN.md`.
6. Widgets: today ring on the home screen.
7. Workspace profiles on the PC (Plus).
8. Ambient sounds (Plus). Common, often paywalled. Low priority.
9. Focus filter and Shortcuts hook so Lock In can start with iOS Focus.
10. Apple Watch: later; limited value without a Mac to build it.

## Skip for now
- Leaderboards and gems (fade fast).
- Full to-do list. The intent card is enough and keeps the app calm.
- Account and sign-up. Not needed for a phone-and-PC pair on one network.

## Sources
- https://apps.apple.com/US/app/id1497465230
- https://www.opal.so/help/how-when-and-where-does-opal-report-your-screen-time
- https://screensdesign.com/apps/forest-focus-for-productivity/
- https://forestapp.cc
- https://apps.apple.com/app/focus-deep-work-timer/id975017240
- https://apps.apple.com/us/app/calmly-focus-timer/id6759624884
