# Features Brandon asked for (and where they stand)

Written 2026-11-12 from Brandon's own chat messages (2026-11-02 to 11-12) and the plan docs.
Status is checked against `apps/` code by search, not on a device.

## Built (code exists)
- Focus clock, start and stop, session survives app close.
- Screen Time blocking and app picker. Never tested on a real iPhone.
- Streak screen after the first finished session of a day.
- Phone-to-PC pairing, both sides (QR, secure link, start and stop sync). Never tested phone-to-PC for real. No Windows tray app.
- Onboarding with the brain slide (builds 16-18). The new "printed" onboarding v2 is only a mock (`docs/design/ob-v2.html`).

## Asked for, not built
| # | Feature | Brandon's words / source | Plan doc |
|---|---|---|---|
| 1 | Plus: real subscription purchase. Code written 11-12 (not compiled); needs the product in App Store Connect | "tell them if they want to buy the subscription" (11-05) | `PRICING_PLAN.md`, `ONBOARDING_V2.md` |
| 2 | Goal page in the app + reminders ("you're 25% to your goal") | 11-05 | `WEEKLY_REPORT.md` (Goals) |
| 3 | Sunday weekly report: apps and time, PC data too, "you hit your goal" | 11-05 | `WEEKLY_REPORT.md` |
| 4 | The PC opens your work (workspace launch and restore) + Windows tray app | "i love this" (11-04) | `DIFFERENTIATION_PLAN.md` |
| 5 | PC Lockdown: quit early and the PC locks for a while (Plus) | 11-04 | `COMPETITOR_FEATURES.md` |
| 6 | Hard-to-cheat early exit ("not just wait 30 sec"). Built 11-12: free watched wait + typed sentence + widget scar; Plus Locked mode with Friend Key (in person + iCloud) and weekly emergency exit. Not tested on devices | 11-04, 11-12 | HANDOFF.md |
| 7 | Lock screen countdown (Live Activity). Built 11-12 (build 25): lock screen card + Dynamic Island, lives in the widget extension. Not tested on device | "yea" (11-04) | `LIVE_ACTIVITY_PLAN.md` |
| 8 | Proof Check: warn if Screen Time access gets turned off. Built 11-12 (build 25): checked on app open; mid-session it counts as a quit + scar, "turn it back on" re-applies shields; widget shows SIGNAL LOST. Not tested on device | "save it" (11-04) | `COMPETITOR_FEATURES.md` |
| 10 | Brain widget: rots as phone time and one heavy app add up today; always has a heartbeat. Code written 11-12, not compiled | 11-12 | HANDOFF.md, `docs/design/widget-brain.html` |
| 9 | Onboarding v2 in the real app (guess, real hours reveal, heart-monitor brain, study card). Code written 11-12, not compiled | 11-12 | `ONBOARDING_V2.md` |

## Before a public release
- Remove the "Replay intro" and "Show streak" test buttons in `FocusView`.
- Device test of Screen Time (see `SCREEN_TIME_RESTRICTIONS.md`).
