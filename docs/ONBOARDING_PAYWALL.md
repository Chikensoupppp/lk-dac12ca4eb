# Welcome slides and the Plus offer (research and proposal)

Written 2026-11-04. Sources are blogs, benchmark posts and developer forums; several are weak or from vendors who sell paywall tools. Treat numbers as direction only. Check Apple's current App Review Guidelines (3.1.2) before building. Not built yet. The four-tab layout is saved for later (`docs/design/tabs-ideas.png`).

## What the research says
- **Show value first, then the offer.** One analysis found multi-page onboarding paywalls converted about 37% better than single-page ones (9.07% vs 12.41%). It suggests 2 to 3 value screens before asking for money.
- **Onboarding paywalls convert well.** Adapty's 2026 report is quoted as saying a paywall in onboarding converts almost 4x better than one shown later. I saw a summary only.
- **Where apps put it.** In one sample of 40 flows, 77.5% put the paywall after the two-thirds mark and 27.5% on the very last step. That shows habit, not what converts best.
- **Typical numbers:** paywall view to trial start 5-15%; trial to paid about 40-70% (Adapty median 53%).
- **Short onboarding.** One source says Headspace cut onboarding to three questions after a 38% drop-off. Unverified.
- **Forest's weak point.** Its teardown criticises forced email sign-up before the first session.
- **Trial trust.** Headspace and Opal show a timeline on the paywall (today, reminder, first charge). Duolingo sends a reminder about 2 days before the trial ends and tested letting users pick the day. Both aim to remove "surprise charge" fear.
- **Wording.** Opal and Headspace use "Try for $0" instead of "Start free trial".

## Apple rules to respect (from forum and notice text, verify live)
- Show the subscription name, length and price clearly, with the price easy to read.
- Link to Terms of Use and Privacy Policy.
- Explain that it renews, and how to cancel (iOS Settings > Subscriptions).
- Give ongoing value to subscribers.
- Include Restore Purchases (standard practice; not confirmed by this search).
- Free trials work only with auto-renewable subscriptions.

## Proposed first-run flow
1. **Three welcome slides.** Swipe or tap. Skip button on every slide. No account, no email.
2. **Allow Screen Time.** One button. Can be skipped; explained by the slide before.
3. **Plus offer (soft, closable).** "Try Plus free for 7 days." Timeline: today, day 5 reminder, day 7 first charge. Big "Not now" that keeps the free app. Prices are placeholders until set in App Store Connect.
4. **First session.** The 45-minute LOCK IN screen.
5. **Second, gentle offer after the first finished session** (the value moment), and any time someone taps a Plus feature.

Why this order: the research favours showing value before the offer, and a paywall in onboarding converts well. Our rule stays: the free app must be good and the close button must be easy. No trap.

## Welcome slide copy (short)
1. "Lock in." / "Your phone and your PC focus together."
2. "Shield your apps." / "See what is really on. We never fake it."
3. "Your PC gets ready." / "One tap opens your work."

## Plus offer copy
- Title: "Lock In Plus"
- Four lines: "PC workspaces", "Lock PC if you quit early", "Lock screen countdown", "History and weekly report".
- Buttons: "TRY FREE FOR 7 DAYS" and "Not now".
- Small print line: price, renewal, "Cancel any time in iOS Settings", Terms, Privacy, Restore Purchases.

## Ideas to make it better than others
- **Honest timeline** on the paywall and a **real reminder** before the first charge (local notification, day 5).
- **Choose-your-reminder day**, like Duolingo's test. Low effort.
- **One plain price line,** no fake "was $99" strikethrough.
- **Lifetime option** next to yearly. Research says people dislike subscription traps.
- **Show Plus in use,** not a feature list: a tiny picture of the PC opening a workspace.
- **Calm tone.** Cream look, no red countdown timers, no pressure.

## Open choices for Brandon
- Prices (yearly, lifetime, monthly?).
- Trial length (7 days is the common default).
- Whether Plus ever blocks the first session. Recommendation: never.

## Sources
- https://superwall.com/blog/new-postmulti-page-onboarding-paywalls-convert-37-better-than-single-page-heres-why.md
- https://adapty.io/state-of-paywalls/report/
- https://www.lazyweb.com/research/how-far-into-onboarding-do-apps-place-the-paywall
- https://mwm.ai/glossary/paywall
- https://screensdesign.com/showcase/opal-screen-time-control
- https://screensdesign.com/apps/forest-focus-for-productivity/
- https://developer.apple.com/forums/thread/768364
- https://community.revenuecat.com/general-questions-7/app-review-rejection-guideline-3-1-2-ongoing-value-6617
- https://growth-dives.kit.com/posts/growth-dives-what-do-duolingo-blinkist-strava-get-right-about-paywalls

## Update 2026-11-05: what Opal and Freedom actually do (ScreensDesign video chapter lists)
Source: https://screensdesign.com/apps/opal-screen-time-control/ and https://screensdesign.com/apps/freedom-screen-time-control/ (chapter titles only; I did not run the apps).
- **Opal** (24 steps listed before and around the paywall): welcome, social proof, 4 quiz questions (screen time, habit to change, age, occupation), "Building your plan", personalized report (bad news, then good news), rating prompt, Screen Time permission, data-driven goals, commitment screen, THEN the paywall. After it: streak intro, account, friends, pick distracting apps, notification permission.
- **Freedom**: 3 value slides, "Momentum unlocked", 4 quiz questions, each followed by a one-line "reinforcement" screen (for example "Games are irresistible"), account creation, premium benefits, trial timeline, notification warm-up, paywall, then device setup and Screen Time permission.
- **Pattern:** about 12 to 14 steps before the paywall. One question per screen. A short "we understand you" screen between questions. A report or plan screen that feels personal. Permission only after the user has been given a reason. Commitment screen before the offer.
- **Our 6 slides are much shorter.** Not proven better or worse. Rule: do not copy the length, copy the pacing (one question at a time, a reaction after each answer).

## Update 2026-11-05: wording and icon research (secondary sources, check originals before citing)
- Apple HIG, onboarding: https://developer.apple.com/design/human-interface-guidelines/onboarding.md . As quoted on a mirror page: a custom screen before a permission request should offer one action only, and that action must open the system alert. Do not label it "Allow" (people may think they already granted access). Use "Continue". NEEDS CHECK against Apple's live page. Our slide 9 button says "Allow Screen Time": change it.
- Keep onboarding brief and about the app, not about how to use the phone.
- Icons: NN/g summary via https://uxdesign.cc/do-icons-need-labels-6cb4f4282c00 and https://cxl.com/icon-usability-testing/ : only home, print and search are widely understood alone. Pair icons with text. 5-second rule: if finding an icon takes longer than 5 seconds, use words.
- Copy: plain language, benefits not feature lists (https://www.parallelhq.com/blog/ux-writing-best-practices). Weak source; no primary study found.
