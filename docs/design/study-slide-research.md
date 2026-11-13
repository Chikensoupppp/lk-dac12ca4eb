# Study slides: competitor research and options

Written 2026-11-09. Covers the four hours-based slides in `HoursFactStep`
(`apps/ios/LockIn/Onboarding/OnboardingFlow.swift`). Mock sheets: `docs/design/study-options.html`
(`?o=A`, `?o=B`, `?o=C`).

## What I saw and what I only read

Seen with my own eyes:
- Opal's first-run flow, in a public screen recording of a reviewer's phone (360p), so layout and
  big text are clear, small text is not: [App Breakdown #1](https://www.youtube.com/watch?v=A0qSicY1UQ8).
- The public App Store screenshots of Opal, one sec, Jomo, ScreenZen, Clearspace, Brick and
  BePresent (from the iTunes lookup API). These are marketing images, not onboarding screens.

Only read about (not seen):
- one sec and Jomo onboarding screens. The UXKIN tools are not signed in (they need `/mcp`).
  [screensdesign.com](https://screensdesign.com/explore/apps/one-sec/onboarding/) lists two one sec
  screens ("screen time assessment", "intervention mode explanation") as locked thumbnails.
- Opal's chat-style redesign: [Retention.blog](https://www.retention.blog/p/chat-based-onboarding).

## Opal first-run, as seen (order in that recording)

1. "How much time do you spend on your phone?" Rolling number, slider, "I don't know" link, one white pill button.
2. "What habit would you like to change?" List with a social-proof chip ("+1.4M people in common").
3. "How old are you?" Wheel picker, "Skip" top right.
4. A short interlude: "Some not-so-good news, and some great news."
5. "The bad news ... you'll spend 114 days on your phone this year ... on track to spend 22 years of
   your life looking down at your phone." One big purple-to-blue number, tiny footnote that states the
   assumption ("based on an average 16 waking hours each day"). These are example numbers from that recording.
6. "Connect Opal to Screen Time, Securely." An arrow points at the system button. A privacy line sits below.
7. "Opal can help you get back 6 years of your life", three benefit rows, a "fist bump" button.
8. Paywall with a before/after bar chart and "100,000+ Reviews".

What Opal does NOT do: it shows no third-party study. Its numbers are the user's own answers turned
into a projection, plus its own benefit claims with no source on the slide.

## Patterns across the category

- One big number, few words, one white button. Opal slide 5 is about 40 words plus a footnote.
- The big number is personal or an effect (114 days, 22 years, "Get back 1h23m", "Cut screen time in half").
  Lock In's slides use the study's sample size (124, 143, 844) as the big number.
- Research is used as proof in marketing: one sec's store images say "scientifically proven" and
  "peer-reviewed research with Max-Planck Institute". Its [research page](https://one-sec.app/max-planck-study)
  gives a 57% figure with no sample size, design or caveat on the page. Lock In can beat that by showing
  size, design and a link to the paper.
- Permission screens are primed with a reason and a privacy line (Opal; also OffScreen and FocusFlight in
  [this teardown](https://screensdesign.com/articles/screen-time-app-design/)).
- Tone ranges from blunt (Opal) to playful (Jomo's mascot). The teardown advises no shame and no
  correlation presented as a health conclusion.
- Flow length: the average app in Mobbin's 1,460-flow sample has 25 onboarding screens; Lock In has 9
  numbered steps plus 2 short interludes ([Mobbin study](https://mobbin.com/blog/the-long-onboarding-a-study-of-1-460-flows)).

## What I found in Lock In's slides (current build)

- Text contrast, measured: label and citation gray `#8E97A3` is 5.9:1 on the card and 6.7:1 on the page;
  body `#D2D4D9` is 11.8:1 on the card; accent numbers are 9.5 to 10.1:1; dark text on the three accent
  banners is 10.7 to 11.4:1. All pass 4.5:1. (`DESIGN.md` said "about 6.5:1, not measured": now measured.)
- The big number is the least meaningful number on the slide. What changed (3 checks a day, 10 minutes)
  sits in the sentence.
- Only the 7+ slide says "link, not proof". The other two studies are randomized experiments, which is a
  stronger claim, and the slides do not say so.
- The 5 to 6 and 7+ slides are the tallest. In the mock at 852 pt the banner touches the button. On
  smaller phones the content area scrolls. I have not run any of this on a device.
- Personal math already lives in the "Look at your year" step (days a year, days back if halved), so the
  study slide should not repeat it.

## Study facts (from abstracts and publisher or PubMed records, not full papers)

| Study | Design | What the slide may say |
|---|---|---|
| [Kushlev & Dunn 2015](https://doi.org/10.1016/j.chb.2014.11.005), Computers in Human Behavior 43:220-228 | 124 adults, one week limited to 3 email checks a day, one week unlimited, assigned at random | Less daily stress in the limited week. Many people found it hard to comply. |
| [Hunt et al. 2018](https://doi.org/10.1521/jscp.2018.37.10.751), J Soc Clin Psychol 37(10):751-768 | 143 Penn undergraduates, randomly assigned, Facebook + Instagram + Snapchat capped at 10 min each a day, 3 weeks | Bigger drops in loneliness and depression than the control group. One university, students only. |
| [Exelmans & Van den Bulck 2016](https://doi.org/10.1016/j.socscimed.2015.11.037), Soc Sci Med 148:93-101 | 844 adults, one survey | Bedtime phone use was linked to poorer sleep and more fatigue. A link, not cause and effect. |

The first DOI I guessed for Exelmans pointed at a different paper. The one above is the checked one (PubMed 26688552).

Gain-framed messages beat loss-framed ones for prevention behaviors, but only slightly:
r = 0.083 across 94 studies ([Gallagher & Updegraff 2012](https://link.springer.com/content/pdf/10.1007/s12160-011-9308-7.pdf)).
That supports "what you gain" wording but is not a strong reason on its own.

## Options (mock sheets)

- **A. Sharper card.** Keeps the card, banner, badge and accents. Big number becomes what changed
  (3, 10 min, 844 adults surveyed). Badge says "experiment" or "survey". Sample size and weeks go in a
  small line. Source is a tappable row. Smallest code change.
- **B. Big number.** No card. One huge number, one short sentence, a type chip, a source pill, the banner.
  Closest to Opal's cinematic look and the quickest to read. Drops the card you asked to keep.
- **C. See how it worked.** Card plus a small hand-drawn picture of the test (tally marks for check-ins,
  three 10-minute tiles, a dashed "link" for the survey). Most distinct and the most trust, but the
  most new drawing code and the tallest at large text sizes.

Recommendation: A. It keeps what the brief said to keep, fixes the three real problems (what the big
number means, study type, source), and reuses the same SwiftUI view. B and C can borrow from it later.

## Not verified

- No one sec or Jomo onboarding screens were seen. Their patterns here come from text sources.
- The "meaningful number" change is my judgment. It has not been tested with users.
- The mocks are drawings in a browser, not the app. No device or simulator check.
- Study details come from abstracts and publisher or PubMed pages.
