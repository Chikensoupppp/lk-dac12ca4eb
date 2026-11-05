# Animation ideas per screen (matte black look)

Written 2026-11-04. Ideas only. Nothing here is built. Base look: `docs/design/matte-black-animated.html`.

## Rules for all screens
- Motion explains a change. It never just decorates.
- Reduce Motion on: stop the background, use a simple fade.
- Background motion stays slow and low in contrast. Test battery on a real iPhone.
- Haptics pair with the big moments (lock, finish).

## Focus
- Idle: glows drift, dust rises, glint circles the rim (done in mock).
- Pick minutes: the ring grows or shrinks to the new length with a soft spring. Digits roll.
- Press LOCK IN: hold the button, a ring fills around it, then a heavy "latch" haptic. The glows pull in and dim.
- Running: the ring tip pulses once a minute. Background goes calmer, not off.
- Last minute: the glow turns slowly warmer. No flashing.
- Finish: the ring closes, a soft light sweep crosses the clock, a success haptic, the glows brighten.
- End early: the ring drains backward. The glows fade to gray. Feels like a cost.

## Progress
- Open: the daily ring draws itself from zero.
- Streak: the number counts up. A small flame or dot glows more with longer streaks.
- Rest day: the dot dims softly, never red.
- Milestone card: slides up, a light glint crosses it once.
- Weekly receipt: lines print in one by one like a receipt, then the total lands with a haptic.

## PC
- Searching: a ring pulses out from a phone icon.
- Pair with QR: the scan frame snaps to the code, then goes green-blue.
- Connected: a thin line draws from phone to PC, one dot travels along it.
- Lockdown (Plus): the PC icon dims, a padlock closes, a slow countdown ring runs.

## You
- Plus card: a slow glint passes across it every few seconds.
- Toggles: a quick spring with a tiny haptic.
- Settings rows: no motion. Keep it quiet.

## Welcome slides
- Each slide: a single large shape moves as you swipe (parallax). Text fades in after.
- Slide 1: the clock ring draws itself.
- Fact slide: the number counts up, the source line fades in last.
- Last slide: the glows brighten into the Focus look.

## Plus offer
- Features list: rows slide in one by one.
- Price button: one slow glint. No pulsing or timers. Pressure tricks feel cheap.

## Order I would build
1. Lock In press and finish (the core moment).
2. Minutes change and ring draw.
3. Progress ring and receipt.
4. Welcome slides.
5. PC pairing line.
