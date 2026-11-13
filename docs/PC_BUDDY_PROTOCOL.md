# Phone to PC: task, desk buddy, status

Written 2026-11-13. The phone side is built (iOS `LockIn/PC/`). The Windows side is next.
All calls are the existing HTTPS + pinned certificate + bearer token from pairing.

## `POST /session/start` (existing, two new fields)
```json
{ "id": "UUID", "durationSeconds": 1500, "startedAt": "2026-11-13T18:00:00Z",
  "task": "Studying", "buddy": true }
```
- `task`: what the user picked under "Working on" (or `null`). The PC opens the workspace saved
  under this name (apps, files, sites). Unknown name: open nothing, offer to save the current
  windows as that workspace after the session.
- `buddy`: show the desk buddy for this session.
- Old PC apps ignore both fields (System.Text.Json skips unknown properties).

## `POST /session/status` (new)
Request `{ "id": "UUID" }`. Reply 200:
```json
{ "app": "YouTube", "onTask": false, "nudges": 2 }
```
- `app`: plain name of the window in front (process friendly name), or `null`.
- `onTask`: false when the front app is on the distraction list (or not in the task's workspace).
- `nudges`: times the buddy asked "Back to work?" this session.
- 404 for an unknown session. The phone polls every 15 s during a session and stops on any
  4xx, so a PC app without this endpoint is harmless.

## Phone behavior
- "Working on" pill above the minutes picks the task (stored on the phone, names only).
- PC sheet has a "Desk buddy" switch (default on).
- During a session the line under the title shows `STUDYING · PC: DOCS` or, when off task,
  `STUDYING · PC: YOUTUBE · NUDGED 2×` in orange.
- The phone never waits for the PC; a missing PC changes nothing.

## Windows side to build
1. Tray app (starts with Windows) around the existing companion.
2. Workspaces: name, list of apps / files / URLs; "Save what is open now" button.
3. On start: open the workspace; show the buddy (small always-on-top window, brain art in its
   six moods; happier as the session goes on).
4. Watch the front window every 2 s. Distraction list (default: browsers on YouTube, TikTok,
   Reddit, games, Steam, Discord): buddy looks sad and shows "Back to work?" with one button
   that brings a workspace window to the front. Count nudges.
5. Answer `/session/status`.
