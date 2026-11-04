# Free and paid plan for Lock In

Written 2026-11-04. These are proposals, not tested with users. Check competitor prices in the App Store before you set ours. Builds on `docs/POSITIONING_RESEARCH.md`.

## Rule for the split
Free must be good enough to keep and trust. Paid adds power and the two-device magic. Never put honesty (the app telling you the truth about what is really blocked) behind the paywall.

## Free
- Timer sessions, any length.
- Shield the apps you pick (Screen Time).
- Honest status: shows what is really on, warns if Screen Time access is removed.
- Streak (days in a row).
- Cream look.
- Pair one PC and mirror the timer to it (start and end together).

## Plus (paid)
- Workspace launch on the PC: one tap opens your project, docs and music, then puts the old setup back after.
- PC-side blocking of sites and apps during a session.
- Lock screen countdown (Live Activity).
- Schedules: sessions start by themselves.
- History and weekly report.
- Extra themes and icons.

Price idea: one cheap yearly plan plus a one-time lifetime unlock. The research found people dislike subscription traps. Subscriptions need Apple In-App Purchase, which is a separate setup job.

## Unique ideas (what others do not do, or do worse)

Ranked by value for effort. "Gap" means the research did not find it. That is absence in search results, not proof.

1. **Both devices, one tap, plus the workspace.** Gap in the research. Already our core. Paid part: workspace launch.
2. **Proof Check.** A live line that says "5 apps shielded, PC connected". If Screen Time access is removed mid-session, the phone says so at once and the PC shows it too. Answers the top complaint (silent failure). Free.
3. **Friction ladder instead of a hard lock.** Ending early is slow, not banned: a 30-second hold, then a short wait. Plus can set a "friend step" (confirm on the PC). Others either allow one-tap ignore or lock you in. Free basic, Plus custom.
4. **Parking note.** When a session ends or you quit early, type one line: "where I stopped". The PC shows it the next time you start. Cheap, and nobody in our research did it. Plus.
5. **Soft landing.** A 2-minute warning before the end. The PC closes things gently and asks first. Plus.
6. **Honest receipt.** After each session: minutes focused, whether it ended early, whether shields held. No fake scores. Free.
7. **Start from the PC.** A hotkey on the PC starts the phone session. iOS limits this (needs a push message or Live Activity). Hard. Later, and only if Apple allows it cleanly.
8. **Trusted friend ping.** A friend gets a message if you end early. Needs a server and privacy care. Later.

## Friction ladder: how it resists "just wait 30 seconds"
A fixed short wait is easy to beat. So the ladder must be chosen early and get harder:
- **Pick a strength before you start**, when you are calm: Gentle (hold 3 s), Firm (5-minute wait), Locked (PC or friend must confirm). The choice is locked once the session starts.
- **Cost rises.** Each early end in a day makes the next wait longer.
- **Early end costs something real:** the session does not count for the streak, and the receipt says "ended early".
- **Time already done is kept.** Ending at minute 20 of 45 still logs 20. This removes the reason to cheat the clock.
- **Honest limit:** Apple lets people remove Screen Time access, so no setting is absolute. The ladder adds cost. It does not guarantee.

## Better than waiting: three stronger ideas (proposals, untested)
1. **Exit budget.** You get 2 early exits per week. After that, sessions are locked until the week resets. Scarcity beats a timer, because waiting does not spend anything.
2. **Intent card.** Before a session you type one line: "Finish the report". The end-early screen shows your own words and asks "still want to quit?". The 20 minutes already done are kept.
3. **Reason mirror.** To end early you pick why (bored, urgent, tired, distracted). The weekly report shows the pattern. It changes the habit instead of only slowing it.
Real emergencies: calls always work. A "true emergency" exit does not use the budget.
Suggested combo: Intent card + Exit budget free; Locked mode (PC or friend confirms) in Plus.

## Plus feature: PC Lockdown (penalty for leaving early)
If you end a session early on the phone, the PC locks for a time you chose before the session.
- **You opt in and pick the time at session start** (for example 5, 15 or 30 minutes). Max 60 minutes. It never turns on by surprise.
- **How:** the Windows app calls the Windows lock screen (`LockWorkStation`) on the PC and repeats it for the chosen time. Windows has no safe way to "fully" lock a PC, so this is a re-lock loop. You can still sign in, but it locks you out again.
- **Safety valves:** a hard time cap; the phone can cancel it with a long hold ("emergency"); Ctrl+Alt+Del and power still work; it never blocks shutdown or sign-in for a second user.
- **Honest limits:** someone can end the Windows app in Task Manager, restart the PC, or use another account. A service or protected process can make that harder. Not built yet; needs the tray app first. Do not call it "unbreakable".
- **Not for Free:** this is the Locked mode from the ladder above.

## Gamification (proposals, untested)
Rules: reward real focus, never reward wasted time, never shame. Earlier research says gems and leaderboards fade after a week or two, so skip them.
1. **Daily ring.** A goal in minutes (say 90). A caramel ring on the home screen fills as sessions finish. Same look as the clock.
2. **Growing plant.** One small plant on the home screen grows with total focus hours. It never dies. Missing a day just pauses it. Free: one plant. Plus: more plants and themes.
3. **Streak with rest days.** Days in a row, plus 1-2 rest days a week that keep the streak. Strict streaks make people quit after one miss.
4. **Both-devices badge.** A session with the PC connected and the workspace opened earns a "Both devices" mark. Only Lock In can offer this.
5. **Milestone cards.** 10 hours, 50 hours, first 7-day streak. A calm card, shareable if the user wants.
6. **Weekly receipt.** Total hours, best day, how many sessions finished. No fake points.
7. **Later: friend challenge** (needs a server).
Early exits: the session keeps its minutes but earns no streak credit (links to the exit budget above).

## Chosen by Brandon (2026-11-04): gamification v1
- **Daily ring** (1): goal in minutes, caramel ring fills.
- **Streak with rest days** (3).
- **Milestone cards** (5): shown the moment a milestone is reached, any day of the week.
- **Weekly receipt** (6): shown at the end of the week.
- Not chosen for now: growing plant, both-devices badge, friend challenge.
- Design: Brandon will give references. Do not design these screens until he does.

## More ideas from a second search (2026-11-04)
Sources are mostly competitor blogs and store listings. Treat as signals.
- **Hard to bypass without being cruel.** Reports say Freedom on iOS can be beaten by deleting and reinstalling. Stricter apps get angry reviews for feeling controlling. Our friction ladder sits in the middle.
- **Block part of an app, not the whole app.** One blog says users want this (for example, block Reels but keep messages). Apple limits what we can do. Check what Screen Time allows before promising.
- **Price anger.** Opal is described as the most expensive (about $99.99 a year in one source). A fair price is a real selling point.
- **Body doubling (work beside someone).** Focusmate, Deeply and Pomoroom offer it. It is rare on phones. Idea: "silent PC buddy", a friend sees you are in a session and nothing more. Needs a server. Later.
- **Apple-only sync is common.** Most rivals sync through iCloud, so none pair with Windows. This supports our PC gap.
- **Do not let the app be killed by accident.** An Opal forum user closed the desktop app by mistake. Our PC app should warn before it quits mid-session.
- **Widgets.** Home screen, lock screen and Dynamic Island widgets are common. Treat as table stakes, not a differentiator.
- **Session journal.** Focus DNA keeps journal entries. Our parking note is a lighter version tied to the PC.

Sources: https://community.opal.so/t/missing-pro-features-49-app-limit-inactive-widget-and-lack-of-intentions/433/1 , https://unstar.app/blog/opal-forest-freedom-one-sec-jomo-screen-time-apps-ranked-2026 , https://habitdoom.com/blog/freedom-app-alternatives-iphone , https://apps.apple.com/app/id6760590860

## Suggested order
1. Ship the Cream look (in progress).
2. Proof Check and friction ladder (small, free, strong story).
3. Workspace launch + parking note (the paid core).
4. Live Activity, then schedules and history.
5. In-App Purchase last, when there is something worth buying.

## Honest limits
- Apple lets users remove Screen Time access. We can detect it and say so. We cannot prevent it.
- Windows blocking is not built.
- No pricing was tested with users.
