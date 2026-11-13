// Lock In Focus Buddy: counts scrolling on YouTube Shorts and Reddit feeds, nothing else.
// Every 15 seconds, while such a page is the focused tab, it sends four numbers to the desk buddy:
// scroll events, how far the page moved (in screen heights), how many Shorts or pages changed, and
// whether a video was playing. It never reads or sends the URL, titles, post text, comments, messages,
// what you type, or anything on the screen.
(() => {
  "use strict";

  const REPORT_MS = 15000;
  const SCROLL_GAP_MS = 250; // one "scroll" per quarter second at most, so a fast wheel is not 50 events

  /** "youtube-shorts", "reddit-feed", or null for every other page (watch pages, posts, search, ...). */
  function siteNow() {
    const host = location.hostname;
    const path = location.pathname;
    if (host.endsWith("youtube.com")) return path.startsWith("/shorts/") ? "youtube-shorts" : null;
    if (host.endsWith("reddit.com")) {
      if (path.includes("/comments/")) return null; // reading one post is not a feed
      const feed = /^\/(?:(?:best|hot|new|top|rising)\/?)?$|^\/r\/[^/]+\/?(?:(?:best|hot|new|top|rising)\/?)?$/;
      return feed.test(path) ? "reddit-feed" : null;
    }
    return null;
  }

  let scrolls = 0;
  let screens = 0;
  let items = 0;
  let playing = false;
  let lastScrollAt = 0;
  let lastPlace = location.pathname + location.search;
  const lastTop = new WeakMap();

  function onScroll(event) {
    if (!siteNow()) return;
    const target = event.target === document ? document.scrollingElement : event.target;
    if (target && typeof target.scrollTop === "number") {
      const before = lastTop.has(target) ? lastTop.get(target) : target.scrollTop;
      screens += Math.abs(target.scrollTop - before) / Math.max(window.innerHeight, 1);
      lastTop.set(target, target.scrollTop);
    }
    countScroll();
  }

  function countScroll() {
    const now = Date.now();
    if (now - lastScrollAt >= SCROLL_GAP_MS) {
      scrolls++;
      lastScrollAt = now;
    }
  }

  // Capture, so scrolling inside a page's own scroller (the Shorts player) is seen too.
  window.addEventListener("scroll", onScroll, { capture: true, passive: true });
  window.addEventListener("wheel", () => { if (siteNow()) countScroll(); }, { capture: true, passive: true });
  window.addEventListener("touchmove", () => { if (siteNow()) countScroll(); }, { capture: true, passive: true });

  // Both sites change pages without reloading, so look once a second.
  setInterval(() => {
    const place = location.pathname + location.search;
    if (place !== lastPlace) {
      lastPlace = place;
      if (siteNow()) items++;
    }
    if (siteNow() && [...document.querySelectorAll("video")].some((v) => !v.paused && !v.ended && v.readyState > 2)) {
      playing = true;
    }
  }, 1000);

  setInterval(() => {
    const site = siteNow();
    const focused = document.visibilityState === "visible" && document.hasFocus();
    if (site && focused) {
      const report = { v: 1, site, scrolls, screens: Math.round(screens * 100) / 100, items, playing, focused: true };
      try {
        chrome.runtime.sendMessage(report).catch(() => {});
      } catch {
        // The extension was reloaded or removed; this old copy of the script just stops reporting.
      }
    }
    scrolls = 0;
    screens = 0;
    items = 0;
    playing = false;
  }, REPORT_MS);
})();
