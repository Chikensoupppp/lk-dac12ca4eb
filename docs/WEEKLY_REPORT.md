# Weekly report (plan)

Written 2026-11-05. Plan only. Nothing here is built. Pictures: `docs/design/weekly-report-human.html` and `.png`. All numbers in the pictures are samples.

## What Brandon asked for
- Every week, Lock In shows a review of apps and time spent.
- It shows PC data too, once the user has used the app for a week.
- The first time the user opens the app, it already shows how much time they spent on their phone, like Opal.

## The two moments
1. **First open ("Your last 7 days").** Right after the user allows Screen Time. Shows the phone report and the PC scan. No waiting.
2. **Every week ("Your week").** A review. Apps and time, trend versus last week, sessions, best day, time by task.

## Where each number comes from
| Number | Source | Can Lock In read it? |
| --- | --- | --- |
| Phone time per app | Apple Screen Time report view (DeviceActivityReport) | **No.** Apple draws it. Lock In cannot read or save the numbers. |
| PC time per app, lifetime | Windows UserAssist registry scan (tested on Brandon's PC, 561 entries) | Yes, on the PC. |
| PC time per app, each day | Tray app records the front window from install on | Yes, on the PC. |
| Sessions, minutes focused, best day, time by task | Lock In's own session log | Yes. |

## How to show iPhone data (like Opal)
- Put Apple's report view on a Lock In screen. The user sees their real last 7 days.
- Likely works right after Screen Time access is granted, because iOS already keeps the history. Not tested.
- Lock In cannot put those numbers in its own sentences. Sentences use PC data and session data.
- Apple forum threads confirm the report cannot send data out: https://developer.apple.com/forums/thread/809823

## What competitors do (help pages and reviews only; no real screens seen)
- Opal: weekly Focus Report after a full week. Users ask for a week-over-week comparison and for productive apps not to count as bad.
- RescueTime: 0 to 100 score. Says to watch the trend over weeks. Says labeling apps right matters most.
- Forest: day, week, month, year. Time by tag. Best days and times.
- Apple Screen Time: weekly totals only. Reviewers call it blunt.

## Our edge
- Opal needs a week before the report. The PC scan shows real numbers on first open.
- Time by task ("What are you working on?") comes from Lock In's own sessions.

## Rules
- Say what the data shows. Never say Lock In caused a change.
- Ask permission before the PC scan. Keep the data on the PC. Do not record window titles or web pages.
- Let the user relabel apps as Work, Neutral, or Distraction.
- No fake scores. If there is no last week to compare, say nothing about it.

## Open questions
- Does Apple's report show 7 days of past data on the first open? Needs a real phone test.
- Does the app need Apple's approval for Screen Time use before release?
- Tray app and pairing are not built, so no PC numbers flow yet.
- Which weekday and time to deliver the report (idea: Sunday evening, by local notification, no numbers in the notification text).

## Goals (added 2026-11-05)
Pictures: `docs/design/goals-human.html` and `.png`. All numbers are samples.

- **Two slides after the quiz.** "Building your plan" (a few seconds, shows steps), then "That adds up": the user's own quiz answer turned into hours a week and days a year. It is plain arithmetic (3.5 h a day is about 25 h a week and about 53 days a year). Label it an estimate.
- **Goal page, inside the app (not in the slides).** The user sets a weekly goal in hours of real focus, 2 to 8 h, with a suggested start. A switch turns reminders on. A second switch limits them to weekdays.
- **Reminders through the week.** Local notifications from Lock In's own session log, such as "You're 25% of the way to 4 hours." They need notification permission. Use a warm-up screen before Apple's box. Progress comes from Lock In sessions only, never from Apple's report (Lock In cannot read it).
- **Sunday report, goal reached.** "You did it. Goal: 4 hours. You focused 4 h 20." Then a button to set next week's goal, with a suggested higher goal.
- **Not decided.** What the report says when the goal is missed. Suggest a calm line with no shame, and offer a smaller goal. Not drawn yet.
- **Not built.** Nothing in this section exists in the app yet.
