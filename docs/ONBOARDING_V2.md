# Onboarding v2: "Printed" look and selling flow (proposal)

Written 2026-11-11. Mock: `docs/design/ob-v2.html` (picture: `docs/design/ob-v2-full.png`).
2026-11-12: written in Swift (see HANDOFF.md), not yet compiled or run. Differences from the mock: the reveal slide adds "Tap the one that matches" (the app cannot read the real number, so the brain and year use the band the user taps); a "lock apps" slide sits after the stickers; the "Locked in" slide is the real main screen with the session running. Numbers below come mostly from vendor blogs and podcast summaries; treat them as direction, not proof.
Extends `docs/ONBOARDING_PAYWALL.md`.

## What competitors look like (gap analysis)
- Opal: black, glowing orb, icy blue glass. Premium dark.
- Unrot, Brainrot, Jomo: cute brain mascots, pastels, app-logo stickers. (Our old comic brain sat here.)
- one sec, ClearSpace: calm white minimal.
- Nobody uses a loud, printed, real-world look. That is the gap.

## The look
- Idea: your phone habit, printed out. Every slide is a different real paper object (receipt, lost poster, stickers, calendar, notebook, print-out, permit, contract, member card). Same inks, different object, so slides never repeat.
- Inks (riso style, flat, a light dot grain): paper `#F2ECE1`, ink `#15120F`, signal orange `#FF4A1C` (the cost), blue `#2E4BFF` (the good news and the fix), navy `#0E1640` (Plus).
- Story in colour: loud orange for the problem, blue for the way out, navy calm for Plus, then black and quiet when you lock in (into the real app). The jump to the dark app is the payoff, not a clash.
- Type: condensed heavy caps for titles (Archivo, OFL, bundle it), mono for printed details (JetBrains Mono, OFL), a marker hand for handwriting (Caveat Brush, OFL).
- Colour research: no hue "sells" by itself. Tests show contrast and isolation of the main button matter. So: one black (or paper on navy) pill button per slide, nothing else that loud near it.

## What helps people subscribe (and how this flow uses it)
- Paywall right after a personal report. Opal's founder says moving the paywall to right after the lifetime screen-time report lifted trial starts from 7% to 17% of downloads. -> Slide 5 (your year, bad news then good news) leads to the plan, the promise, then the offer.
- Most trials start on day one (RevenueCat: 80%). -> The offer sits inside onboarding, not later.
- Personalise the offer with quiz answers (Superwall: +10 to 15% in one team). -> "Your plan is ready" and the print-out reuse the hours, apps and goals picked.
- Honest trial timeline with real dates (Blinkist reported +23%) and a reminder before the charge. -> Today / Day 5 reminder / Day 7 price.
- Commitment before the offer (Opal and Freedom both do it). -> Slide 9, hold to sign a promise.
- Annual plan as the main option; most top paywalls preselect annual. Trials longer than 4 days convert better. -> 7-day trial on yearly.
- "Try for $0" wording (Opal, Headspace).
- Long quizzes: no proof that length alone helps. Copy the pacing (one question per screen, a reaction after each), not the length.
- Free-trial toggles: one source says Apple started rejecting them in Feb 2026. Do not use one.
- Opal later moved to freemium: conversion fell from 20% to 9% but growth rose. Keep "Not now" easy; the free app stays useful.

## Slides (updated 2026-11-11, Brandon: no fake receipt; guess first, then the real hours)
1. Hook: "You lose hours to your phone." A blank "?H ??M" (digits flicker, then settle), marker note "you?". "Take a guess." Button "GUESS".
2. The guess: "LOST: MY DAY" poster; tear off your hours tab (1-2, 3-4, 5-6, 7+).
3. Now let's check: printer with a blank receipt. Three lines: reads Screen Time on this phone; stays on your phone, we never see it; also lets Lock In lock your apps. Button "Continue" opens the iOS alert. "Not now (keep my guess)" uses the guess for the rest.
4. Reveal: "Oh wow." "YOU GUESSED ~~3-4 HRS~~" then "6H 12M" + their real receipt (real app names and icons) + reaction stamp + days-a-year line. The guess is passed into the report extension through the app group (app -> extension is allowed).
   Technical limit: the app can never read Screen Time numbers. Only a DeviceActivityReport extension can draw them, and it cannot send them back (Apple: https://developer.apple.com/forums/thread/818174). So slide 3 is drawn by a new report extension, including the reaction text and stamp. The app can pass data into it (app group), not out. Needs a fallback when there is no Screen Time history yet. Only testable on a real iPhone.
   Later slides that need hours (brain, year) either get drawn by the extension too, or use the poster answer.
Fallback, only if they tap Not now: "LOST: MY DAY" poster; tear off your tab.
3. Brain (`docs/design/brain-v2.html`): heart-monitor look. "This is your brain over one day. Each hit = more time on your phone." A "TIME ON PHONE" clock counts up per hit; heart rate climbs 72 -> 188 (skipped beats, then chaos), then flatlines. At the end the brain shrinks and a study card slides up with three findings picked by hours, one marked "YOU ARE HERE", plus "Studies show links, not proof. Not medical advice." Findings are plain summaries, not word-for-word quotes:
   - 1-2h: up to ~2h/day not linked to harm, 120,000 teens (Przybylski & Weinstein, Psychological Science 2017).
   - 30 min: students who cut social media to 30 min/day felt less lonely and depressed in 3 weeks (Hunt et al., J. Social and Clinical Psychology 2018).
   - 3h+: teens on social media >3h/day, 1.6x risk of internalizing problems (anxiety, depression signs); >6h, 1.8x (Riehm et al., JAMA Psychiatry 2019).
   - 7h+: teens 14-17 on screens 7+h/day over 2x as likely to have been diagnosed with depression or anxiety vs 1h/day (Twenge & Campbell, Preventive Medicine Reports 2018).
   - Sleep: screen time tied to worse sleep in 90% of 67 studies (Hale & Guan, Sleep Medicine Reviews 2015).
   All are correlational and mostly about teens. Keep the "links, not proof" line.
4. What pulls you in: peel stickers.
5. Your year: 84 days crossed in orange; "+42" circled in blue (bad news, good news).
6. Goals: to-do list in handwriting.
7. Making your plan: dot-matrix print-out of their answers (loading).
8. Screen Time: permit card, one button "Continue" (Apple HIG: do not say "Allow").
9. Promise: contract, hold to sign.
10. Plus: member card, honest timeline, TRY FOR $0, Not now, Restore / Terms / Privacy.
11. Locked in: screen goes black, first session.

## Open choices
- Price and trial (placeholder $29.99/yr, 7 days).
- Name on the contract: ask for a first name (adds a step) or leave a blank line they "sign".

## Sources
- https://www.revenuecat.com/state-of-subscription-apps-2025
- https://www.rocketshiphq.com/revenuecat-state-of-subscription-apps-2025-summary/
- https://www.betterlaunch.co/playbooks/kenneth-schlenker-opal-121abs-3
- https://www.revenuecat.com/blog/growth/kenneth-schlenker-sub-club-podcast-2026
- https://superwall.com/blog/the-paywall-growth-lever-framework-how-to-build-smarter-experiments-faster
- https://ottergrowth.com/notes/paywall-defaults-and-framing
- https://thepaywallindex.substack.com/p/the-anatomy-of-the-best-performing
- https://adapty.io/blog/high-performing-paywall-2026/
- https://www.revenuecat.com/blog/growth/paywall-redesigns-case-studies/
- https://www.lazyweb.com/research/longest-app-onboarding-flows
- https://tenten.co/shopify/color-psychology-ecommerce-shopify/
- https://screensdesign.com/apps/opal-screen-time-control/
- https://screensdesign.com/apps/unrot-earn-your-screentime/
- https://screensdesign.com/apps/brainrot-screen-time-control/
- https://www.sciencedaily.com/releases/2018/10/181029150931.htm (Twenge & Campbell 2018)
- https://publichealth.jhu.edu/2019/social-media-use-by-adolescents-linked-to-internalizing-behaviors (Riehm 2019)
- https://www.healio.com/news/psychiatry/20190911/too-much-time-on-social-media-affects-internalizing-problems-in-adolescence (Riehm 2019 numbers)
- https://qz.com/quartzy/1459609/limiting-social-media-use-reduces-depression-say-researchers (Hunt 2018)
- https://sciencedaily.com/releases/2017/01/170113085940.htm (Przybylski & Weinstein 2017)
- https://researchconnect.stonybrook.edu/en/publications/screen-time-and-sleep-among-school-aged-children-and-adolescents-/ (Hale & Guan 2015)
