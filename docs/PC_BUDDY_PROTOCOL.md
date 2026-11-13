# Phone to PC: task, desk buddy, status

Written 2026-11-13. The phone side is built (iOS `LockIn/PC/`). The Windows side is next.
All calls are the existing HTTPS + pinned certificate + bearer token from pairing.

## `POST /session/start` (existing, two new fields)
```json
{ "id": "UUID", "durationSeconds": 1500, "startedAt": "2026-11-13T18:00:00Z",
  "task": "Studying", "buddy": true, "allow": ["youtube"] }
```
- `allow` (optional): apps or sites already known to be fine for this session, lower-case names
  as the PC reports them in `app` (`youtube`, `discord`, `steam`). The PC adds what this task
  remembered from earlier sessions. Most people never send it: the buddy asks instead (below).
- `task`: what the user picked under "Working on" (or `null`). The PC opens the workspace saved
  under this name (apps, files, sites). Unknown name: open nothing, offer to save the current
  windows as that workspace after the session.
- `buddy`: show the desk buddy for this session.
- Old PC apps ignore both fields (System.Text.Json skips unknown properties).

## `POST /session/status` (new)
Request `{ "id": "UUID" }`. Reply 200:
```json
{ "app": "YouTube", "onTask": false, "nudges": 2, "asking": "YouTube" }
```
- `app`: plain name of the window in front (process friendly name), or `null`.
- `onTask`: false when the front app is on the distraction list and not allowed (or not in the task's workspace).
- `nudges`: times a distraction was minimized this session (the user said "back to work" or did not answer).
- `asking`: the app the buddy is asking about right now ("Is YouTube for your work?"), or `null`.
- 404 for an unknown session. The phone polls every 15 s during a session and stops on any
  4xx, so a PC app without this endpoint is harmless.

## Phone behavior
- "Working on" pill above the minutes picks the task (stored on the phone, names only).
- PC sheet has a "Desk buddy" switch (default on).
- During a session the line under the title shows `STUDYING · PC: DOCS` or, when off task,
  `STUDYING · PC: YOUTUBE · NUDGED 2×` in orange.
- The phone never waits for the PC; a missing PC changes nothing.

## Allowing apps without making a list (built 2026-11-13)
Nobody should have to name every app up front. So:
1. Only apps on the distraction list can ever be touched. Word, Excel, an editor, a school site: never.
2. When a listed one comes to the front, the buddy asks: "Is YouTube for your work?" with two
   buttons, "It's for work" and "Back to work", and a 12 second countdown.
3. "It's for work": allowed for the rest of the session AND remembered for this task
   (`allowed-apps.json` in the state folder: names only, per task). Next "Studying" session it is
   not asked again.
4. "Back to work", or no answer in 12 seconds: minimized (never closed) and counted as a nudge.
   The buddy then leaves it alone until the user comes back to it.
5. Allowing is per site, not per browser: YouTube allowed does not allow TikTok.

## Windows side to build
1. Tray app (starts with Windows) around the existing companion.
2. Workspaces: name, list of apps / files / URLs; "Save what is open now" button.
3. On start: open the workspace; show the buddy (small always-on-top window, brain art in its
   six moods; happier as the session goes on).
4. Watch the front window every 1 s. Distraction list (default: browsers on YouTube, TikTok,
   Reddit, Instagram, Netflix, Twitch, games, Steam, Discord, Telegram, WhatsApp): the buddy asks
   first (see above). DONE: ask, allow, remember per task, minimize, nudges. Still to build: a
   button that brings a workspace window to the front, and a "manage allowed apps" list.
5. Answer `/session/status`.
