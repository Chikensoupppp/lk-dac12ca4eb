# Lock In Focus Buddy (Chrome / Edge extension)

Lets the Windows desk buddy notice long scrolling on YouTube Shorts and Reddit feeds during a focus
session, and give a gentle reminder. Part of Focus Guardian (`docs/PC_BUDDY_PROTOCOL.md`).

## What it sends
Every 15 seconds, only while a Shorts page or a Reddit feed is the focused tab:
`{ v, site: "youtube-shorts" | "reddit-feed", scrolls, screens, items, playing, focused }`.
Counts only. Never URLs, titles, post text, comments, messages, typing, or screenshots.
Watch pages, single posts and every other site send nothing.

## How it reaches the PC
Chrome native messaging (`chrome.runtime.connectNative("com.lockin.guardian")`). Chrome starts
`LockIn.Companion.exe` with this extension's origin; the host passes clean reports to the running
companion over a named pipe that only this Windows user can open. No network port.

## Set up (once)
1. `LockIn.Companion.exe --register-browser` (writes the host file and the per-user registry keys for Chrome and Edge).
2. Chrome or Edge: Extensions, Developer mode on, "Load unpacked", pick this folder.
3. The ID must be `aeamejjnehidcalejbnkpgkfkalefeda`. It comes from the public `key` in `manifest.json`;
   the host only accepts that ID (`NativeHost.ExtensionId`). Change both together.

Undo: `LockIn.Companion.exe --unregister-browser`, then remove the extension.

## Notes
- The private key for this ID is not in the repo. It is only needed to pack a `.crx`; the Chrome Web
  Store would assign its own ID, and `NativeHost.ExtensionId` must then be updated.
- If the companion is not running, reports are dropped. Nothing is stored.
