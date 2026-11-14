// Passes reports from content.js to the Lock In companion on this PC through native messaging
// (host "com.lockin.guardian", set up by `LockIn.Companion.exe --register-browser`). No network.
// It also sends a small "alive" signal every 15 seconds, with whether it may run in private windows,
// so the buddy knows this browser is covered. A browser without that signal is paused during a session.
"use strict";

const api = globalThis.browser ?? globalThis.chrome; // Firefox uses `browser`, Chrome/Edge `chrome`
const HOST = "com.lockin.guardian";
const SITES = new Set(["youtube-shorts", "reddit-feed"]);
const ALIVE_MS = 15000;
let port = null;

function connect() {
  if (port) return port;
  try {
    port = api.runtime.connectNative(HOST);
  } catch {
    port = null;
    return null;
  }
  port.onMessage.addListener(async (message) => {
    if (typeof message?.savePage !== "string" || !/^[a-f0-9]{32}$/.test(message.savePage)) return;
    // Only an explicit buddy click requests a URL. Never enumerate history or background tabs.
    try {
      const window = await api.windows.getLastFocused();
      if (!window.focused) return;
      const [tab] = await api.tabs.query({ active: true, windowId: window.id });
      const url = cleanLaterUrl(tab?.url);
      if (url) send({ v: 1, kind: "later-save", request: message.savePage, url });
    } catch { /* tab closed or permissions changed: save nothing */ }
  });
  port.onDisconnect.addListener(() => {
    void api.runtime.lastError; // host not installed, or the companion closed: the alarm tries again
    port = null;
  });
  return port;
}

function send(message) {
  try {
    connect()?.postMessage(message);
  } catch {
    port = null;
  }
}

function cleanLaterUrl(value) {
  if (typeof value !== "string" || value.length > 2048) return null;
  try {
    const url = new URL(value);
    if (url.protocol !== "https:" || url.username || url.password || url.port) return null;
    return ["youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be", "reddit.com", "www.reddit.com", "old.reddit.com"].includes(url.hostname) ? url.href : null;
  } catch { return null; }
}

async function privateAllowed() {
  try {
    const result = api.extension.isAllowedIncognitoAccess();
    if (result && typeof result.then === "function") return (await result) === true;
  } catch {
    // older callback-only form below
  }
  return new Promise((resolve) => {
    try {
      api.extension.isAllowedIncognitoAccess((allowed) => resolve(allowed === true));
    } catch {
      resolve(false);
    }
  });
}

async function alive() {
  send({ v: 1, kind: "alive", incognito: await privateAllowed() });
}

/** Only the exact shape content.js sends gets through; everything is rebuilt, nothing is copied blindly. */
function clean(msg) {
  if (!msg || msg.v !== 1 || !SITES.has(msg.site) || msg.focused !== true) return null;
  const num = (x, max) => (Number.isFinite(x) ? Math.min(Math.max(x, 0), max) : 0);
  return {
    v: 1,
    site: msg.site,
    scrolls: Math.round(num(msg.scrolls, 200)),
    screens: num(msg.screens, 50),
    items: Math.round(num(msg.items, 30)),
    playing: msg.playing === true,
    focused: true,
  };
}

api.runtime.onMessage.addListener((msg, sender) => {
  if (sender.id !== api.runtime.id || !sender.tab) return; // only our own content script
  const report = clean(msg);
  if (report) send(report);
});

// While the native connection is open the browser keeps this worker running, so the timer keeps
// ticking. If the worker was stopped, the alarm (every 30 s, the shortest allowed) starts it again.
setInterval(alive, ALIVE_MS);
// No URL in this poll. A request comes back only after "Save it for later" was clicked.
setInterval(() => send({ v: 1, kind: "later-poll" }), 1000);
api.alarms?.create("lockin-alive", { periodInMinutes: 0.5 });
api.alarms?.onAlarm.addListener(alive);
api.runtime.onStartup?.addListener(alive);
api.runtime.onInstalled?.addListener(alive);
alive();
