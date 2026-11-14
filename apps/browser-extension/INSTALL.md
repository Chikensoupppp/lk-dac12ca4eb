# Install Lock In Focus Buddy in your browser

You need this once. It takes about 2 minutes.

## Chrome or Edge (uses Developer mode)

Chrome and Edge only run extensions from outside their store when **Developer mode** is on.
That's normal for us until the Chrome Web Store listing exists.

1. In PowerShell, run this from the `apps\browser-extension` folder:

```bash
.\install.ps1
```

   It links your browsers to Lock In and opens this folder for you.
2. In Chrome or Edge, open `chrome://extensions` (Edge: `edge://extensions`).
3. Turn on **Developer mode** (switch at the top right).
4. Click **Load unpacked** and pick this folder (`apps\browser-extension`).
5. Open the extension's details and turn on **Allow in Incognito**.

Without step 5, the buddy pauses that browser during a session. That's on purpose.

Undo: run `LockIn.Companion.exe --unregister-browser`, then remove the extension.

## Firefox (uses a signed file, no Developer mode)

Firefox only runs add-ons that Mozilla has checked and signed. Ours is signed by Mozilla
with the **unlisted** option. That means:

- Mozilla checks the file automatically, usually within minutes.
- The add-on does **not** appear in the Firefox store. Only people with the file can install it.
- You install it once, and it stays installed (unlike a test load, which Firefox removes on restart).

To install:

1. Open Firefox, go to `about:addons`.
2. Click the gear icon, then **Install Add-on From File**.
3. Pick `apps\browser-extension-builds\lockin-focus-buddy-firefox-0.1.0.xpi`.

Note: that file is version 0.1.0, which is older. The "Save it for later" button needs a newer signed
version. A new signed file needs a higher version number in `manifest.json` and a new signing run.

## Later: Chrome Web Store (no Developer mode for anyone)

When the Chrome Web Store listing exists (one-time $5 developer fee), people install from the store
and never see Developer mode. The store gives the extension a new ID, so the companion's
`NativeHost.ExtensionId` must be updated to match.
