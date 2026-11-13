# Open design problem: which apps may be open during a session?

Written 2026-11-13. For any AI or person who wants to help find the idea. Nothing here is final.

## What exists today (built, works on a real Windows PC)
- The phone starts a focus session. The PC companion (`apps/windows-companion/`) shows a small buddy
  character and checks the front window every 1 second (`Watch/SessionWatch.cs`).
- Only apps on a distraction list can ever be touched (`Watch/Distractions.cs`): browsers on
  YouTube, TikTok, Reddit, Instagram, Netflix, Twitch; Steam and other game launchers; Discord,
  Telegram, WhatsApp. Word, Excel, editors, school sites are never touched.
- Today the buddy ASKS: "Is YouTube for your work?" with "It's for work" / "Back to work" and a
  12 second timer. "Yes" allows the app for the session and remembers it per task (`Watch/AllowStore.cs`).
  No answer or "Back to work" minimizes the window (never closes it, so no work is lost).
- New endpoint `GET /session/choices?task=Studying` lists the apps a phone could show as chips,
  with the ones this task allowed before first.
- Protocol: `docs/PC_BUDDY_PROTOCOL.md`.

## The problem
1. **Asking is easy to lie to.** Anyone can tap "It's for work". Users of other focus apps say those
   apps are "not strict enough". A lie must not get a free pass.
2. **Real work sometimes needs a "distraction" app.** A YouTube lecture, Discord for a team project,
   Steam for a game developer. Hard blocking everything punishes honest users.
3. **Picking apps before each session is too tedious.** Many people cannot say up front which apps
   they will need, and they will not do it daily. A surprise need in the middle of a session must
   also work.

## Rejected ideas (and why)
- Time pool for allowed apps (for example 20% of the session): the owner does not want time limits
  per app.
- "Pick up to 3 apps free": people pick three time-wasters.
- Ask-and-trust (the current build): lying defeats the purpose.

## Current best idea (not built): preset groups
Groups unlock small bundles. Examples: Focus (nothing), Learning (YouTube), Team work (Discord,
Telegram, WhatsApp), Game making (Steam, Discord, YouTube). A group is saved on the task, so a
repeat session needs zero taps. Everything not in the group is blocked at once with no question.
Mid-session "Add a group": 60 second wait, then it unlocks, at most 2 per session, and the end
screen lists what was added.

## Rules for any answer
- Blocked apps must stay blocked with no yes/no question to lie to.
- Usual day: zero or one tap. No typing app names.
- A real need in the middle of a session must still be possible.
- Never close windows (data loss). Minimize only. Never read page contents; names and window titles only.
- Teens and young adults. The tone must stay kind, never mean.
- Windows only for now. The PC app can see: front process name, window title, window handle.
  It cannot see inside apps.

## Questions to answer
1. Where does the best design break? How would a determined user cheat it?
2. Which 5 to 8 preset groups cover most students and young adults, and what does each unlock?
3. How can groups be chosen automatically (task name, past sessions, time of day)?
4. Can window titles tell a lecture from a video feed (for example "Lecture 4 - YouTube")? Is that
   reliable enough, and is it fair?
5. How should a mid-session need work without being easy to cheat?
6. What do Opal, Freedom, Cold Turkey, Forest and Focusmate do here? Copy or avoid?

Answer with one concrete recommendation first, then the reasons.
