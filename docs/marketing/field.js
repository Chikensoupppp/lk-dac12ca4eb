// The onboarding slides' moving halftone field (apps/ios/LockIn/Onboarding/HowItWorksSteps.swift,
// HalftoneField), ported 1:1 for the marketing images: newsprint #E7E8E3, a staggered 15 pt dot grid,
// tone-on-tone dots that grow with a slow drifting wave in the lower part of the frame, and ripples
// that spread out through the dots from one point and fade.
(function () {
  function value(x, y, t, top, fade, ripples) {
    const m = Math.min(Math.max((y - top) / fade, 0), 1);
    if (m <= 0) return 0;
    const a = Math.sin(x * 0.014 - y * 0.010 + t * 0.62 + 1.4 * Math.sin(y * 0.006 + t * 0.18));
    const b = Math.sin(y * 0.012 + x * 0.006 + t * 0.47);
    let v = m * (0.50 + 0.30 * a + 0.20 * b);
    const reach = Math.min(m * 1.8, 1);
    for (const r of ripples) {
      const d = Math.hypot(x - r.x, y - r.y);
      const k = (d - r.dt * r.speed) / 52;
      v += r.amp * Math.exp(-k * k) * Math.exp(-r.dt) * reach;
    }
    return v;
  }

  // ripples: [{x, y, start, amp?, speed?}] in CSS px and seconds; `now` is the same clock as start.
  window.drawField = function (canvas, t, now, fadeStart, ripples) {
    const dpr = window.devicePixelRatio || 1;
    const w = canvas.clientWidth, h = canvas.clientHeight;
    if (canvas.width !== Math.round(w * dpr)) { canvas.width = Math.round(w * dpr); canvas.height = Math.round(h * dpr); }
    const ctx = canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);
    const top = h * fadeStart, fade = h * 0.35;
    const live = (ripples || []).map(r => ({ x: r.x, y: r.y, dt: now - r.start, amp: r.amp ?? 0.9, speed: r.speed ?? 520 }))
      .filter(r => r.dt >= 0 && r.dt < 4);
    const step = 15;
    const blue = new Path2D(), sun = new Path2D();
    let row = 0;
    for (let y = step / 2; y < h + step; y += step, row++) {
      for (let x = row % 2 === 0 ? 0 : step / 2; x < w + step; x += step) {
        const v = value(x, y, t, top, fade, live);
        if (v <= 0.05) continue;
        const rb = 5.4 * Math.min(v, 1);
        if (rb > 0.4) { blue.moveTo(x + rb, y); blue.arc(x, y, rb, 0, Math.PI * 2); }
        const rs = 5.6 * Math.min(Math.max((v - 0.62) / 0.5, 0), 1);
        if (rs > 0.4) { sun.moveTo(x + 2.2 + rs, y + 1.6); sun.arc(x + 2.2, y + 1.6, rs, 0, Math.PI * 2); }
      }
    }
    // Same inks and order as the app: the lighter "sun" dots first, the darker ones over them.
    ctx.fillStyle = 'rgba(201,202,193,0.9)'; ctx.fill(sun);
    ctx.fillStyle = 'rgba(185,186,176,0.55)'; ctx.fill(blue);
  };
})();
