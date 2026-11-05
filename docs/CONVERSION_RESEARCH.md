# How to get more people to buy Plus (research)

Written 2026-11-04. Sources are mostly paywall-tool vendors (RevenueCat, Superwall, Adapty). They sell tools, so read the numbers as hints. Most are not controlled tests. Nothing here is built.

## What the numbers say
- **Hard paywall vs freemium.** RevenueCat 2026: median Day-35 trial-to-paid 10.7% for hard paywalls vs 2.1% for freemium. Hard paywalls also have more refunds (5.8% vs 3.4%). This compares different apps, so it is not proof that the paywall type caused it. A hard paywall only works when people understand the value first.
- **Longer trials convert better, per trial.** RevenueCat 2026: trials of 17 to 32 days convert at a median 42.5%; trials under 4 days convert at 25.5%. Other sites list 5-9 days at 37.4% and 10-16 days at 35.4% (second-hand, not confirmed). This is the share of trial starters who pay. It does not count how many people start a trial.
- **One page beat a multi-page paywall in one test.** Stompers (Superwall case study): single-page paywall raised overall conversion by over 16%. The losing version had a reminder page before the price. This is one app. It differs from the earlier "multi-page onboarding +37%" claim, which was about value screens before the paywall, not extra paywall pages. Our plan fits both: value slides first, then one offer page.
- **Productivity apps.** One source says people who buy directly are worth more than trial users ($55.45 vs $40.13). Unverified source.

## Claims with weak or no evidence
- "Pre-select yearly and add a save-40% badge moves 15% more people to yearly." Vendor claim, no test cited. Cheap to try.
- "Add ratings and a testimonial for +10-15%." One real test (Glam AI) showed 2.54% vs 2.43%, which is noise.
- "A reminder before the trial ends raises conversion." No measured lift found. It still builds trust and prevents refund anger.
- Lifetime plan as a default: no test found.

## Rules we must follow (check the live text before building)
- Show the price and billing period clearly on the offer. They must match App Store Connect.
- Link Terms and Privacy. Include Restore Purchases. Say how to cancel.
- Cancelling must be easy. The US FTC "click to cancel" rule was finalized in 2024. One headline says it was struck down. Status unconfirmed.
- No fake countdowns, no fake "was $99", no hidden close button. This is also our own rule.

## What I would do for Lock In
1. **Keep the free app good** and never block the first session. Decide on a hard paywall only if you accept fewer installs kept.
2. **Show value first**: the three slides, then one offer page. Second soft offer after the first finished session, and when someone taps a Plus feature.
3. **Make Plus about the PC.** That is our difference. Show Plus in use (a PC opening a workspace) instead of a feature list.
4. **Offer a 7-day or 14-day trial.** Longer trials convert better per trial. Pick one and test the other later. Tell people the exact charge date.
5. **Yearly first, lifetime next to it.** Plain price line. Easy "Not now".
6. **Use real numbers**, for example "You focused 6 hours this week". Honest and personal.
7. **Test, do not guess.** A/B testing needs a tool (RevenueCat or Superwall) and enough users. A small app may need weeks per test.

## Open choices for Brandon
- Free app stays open (my pick) or hard paywall after the slides?
- Trial: 7 or 14 days?
- Prices.

## Sources
- https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026
- https://www.revenuecat.com/blog/growth/hard-paywall-vs-soft-paywall/
- https://www.airbridge.io/blog/hard-vs-soft-paywalls
- https://superwall.com/case-studies/stompers.md
- https://adapty.io/blog/markdown/glam-ai-paywall-tests.md
- https://catdoes.com/blog/free-trial-vs-pay-upfront
- https://dev.to/paywallpro/mobile-app-monetization-benchmarks-2026-paywalls-trials-pricing-ai-apps-135h
