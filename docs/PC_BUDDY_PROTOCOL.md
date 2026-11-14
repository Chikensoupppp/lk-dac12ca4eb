# Phone to PC: task, desk buddy, status

## Save it for later (2026-11-13)

- During a YouTube/Reddit question or scrolling reminder, the buddy offers "Save it for later".
- Extension 0.2.0 polls over native messaging with `{v:1,kind:"later-poll"}` (no browsing data). Only after an explicit buddy click does the companion reply with `savePage`, a five-second single-use request ID bound to the session and foreground browser window.
- The extension reads the active tab of the focused window and replies `{v:1,kind:"later-save",request,url}`. The native host stamps the real parent browser name; the companion checks session, window, browser, site and deadline before saving. Only HTTPS YouTube/Reddit URLs without embedded credentials/custom ports are accepted.
- Saved links live in `later.dat` under the companion state folder, encrypted with Windows DPAPI for this user. No cloud, HTTP route, page contents, history or screenshots. Other scrolling reports remain counts-only.
- Only after the save succeeds is the distracting window minimized. Never closed. A local Later window appears at natural or early session end when something was saved; each link can be opened or removed. `LockIn.Companion.exe --later` reopens the persisted list after a restart.
- Both companion and unpacked extension must be updated. The signed Firefox 0.1.0 XPI does not include this feature and still requires a new signed release.

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

## Focus Guardian: gentle scrolling reminders (built 2026-11-13, not committed)
Blocking stays as above. Guardian adds a reminder on pages the blocking left open (for example
YouTube allowed for "Studying"): having the site open is never enough, only steady feed scrolling.
- Browser side: `apps/browser-extension/` (Chrome/Edge, Manifest V3). Only YouTube Shorts and Reddit
  feeds. Sends counts every 15 s (see its README). No URLs, titles, text or screenshots.
- Link: Chrome native messaging to `LockIn.Companion.exe` (host `com.lockin.guardian`, only extension
  ID `aeamejjnehidcalejbnkpgkfkalefeda`), then a named pipe `LockIn.Guardian.<user SID>` to the
  running companion. The pipe allows only this Windows user and denies network logons. Neither HTTP
  door changed; there is no new endpoint. One-time setup: `LockIn.Companion.exe --register-browser`.
- Rules (`Watch/ScrollGuard.cs`): 30 s buckets. Busy bucket: on Shorts a new Short; on a Reddit feed
  two new pages or 3 screens of scrolling. One video playing never counts. A run allows single quiet
  buckets, two in a row end it. Run of 3 minutes, while a browser is in front and no blocking
  question is open: the buddy says "You've been scrolling for a bit. Back to your project?" with
  "Back to work" / "Not now" (12 s, no answer = Not now). Quiet for 10 minutes after a reminder or
  Not now, 5 minutes after Back to work. Session start and end reset everything. Phone-only mode
  (no buddy) ignores reports.
- Settings: optional `guardian.json` in the state folder:
  `{"thresholdSeconds":180,"bucketSeconds":30,"cooldownMinutes":10,"cooldownAfterBackMinutes":5}`.
- Back to work brings the last work window to the front (`WorkWindowMemory`: last front window that
  is not a distraction, not the shell, not untitled, not Lock In). If that is the same browser window
  (work in another tab), nothing moves and the buddy says "Switch to your work when you're ready."
  Never closes or minimizes anything.

## Every browser must have the extension (built 2026-11-13, not committed)
- The extension sends `{"v":1,"kind":"alive","incognito":<allowed in private windows>}` every 15 s
  (alarm every 30 s restarts it). The host adds the browser's process name from its parent process
  (past cmd.exe), so the extension cannot claim to be another browser.
- `Watch/BrowserGuard.cs`: once any heartbeat was ever seen on this PC (`browser-extension-seen` in
  the state folder), every browser in front during a buddy session must have had a heartbeat in the
  last 45 s AND private windows allowed. Otherwise: warning ("Lock In isn't on in Firefox. Turn it on
  to keep using it." / "Let Lock In run in private windows in Chrome too."), then after the grace time
  (`browserGraceSeconds`, default 60) the browser is minimized whenever it comes to the front ("…is
  paused until Lock In is back on"). Never closed. Unknown browsers (no extension possible) are paused
  the same way. Chrome's incognito window title has no marker, so private windows are covered by
  requiring the "Allow in Incognito" switch, like Cold Turkey does.
- Registration now also writes keys for Chromium, Brave, Vivaldi, and Firefox (Firefox uses
  `native-host-firefox.json` with `allowed_extensions: ["focus-buddy@lockin.app"]`).
- Limits: coverage is per browser program, not per profile (a second Chrome profile without the
  extension counts as covered while another Chrome profile has it); ending the companion process or
  deleting the state folder turns it off; Firefox needs a signed add-on to install permanently.

## Scroll reminder slider (built 2026-11-13, iPhone part not compiled)
- iPhone: PC sheet, under "Desk buddy": "Scroll reminder · after N min", 1 to 10 minutes, default 3
  (`PCSheet.remindKey`, sent as `PCSessionExtras.remindAfterMinutes`).
- `/session/start` takes optional `guardianSeconds`; the PC uses it for that session only (kept
  between 60 s and 1 hour), otherwise `thresholdSeconds` from `guardian.json` (default 180).
- Firefox: the add-on is signed by Mozilla (unlisted channel):
  `apps/browser-extension-builds/lockin-focus-buddy-firefox-0.1.0.xpi`. Re-sign after any change
  with `npx web-ext@8 sign --source-dir apps/browser-extension --channel unlisted` (needs the owner's
  `WEB_EXT_API_KEY` / `WEB_EXT_API_SECRET`; the version in manifest.json must go up).

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
