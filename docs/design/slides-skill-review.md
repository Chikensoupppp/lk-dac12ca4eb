# Onboarding review (plugin: Mobile App Design, skills ios-review + ios-flows)

Not based on real-app examples. The UXKIN server (`https://uxkin.com/mcp/mobile`) is not signed in, so no UXKIN lookups were run. Rendered mock was checked, not a simulator build.
Files: `slides-skill.html` (redesign), `compare-1.png`, `compare-2.png`, `compare-3.png`.

## Whole flow
- Must: no Back button on any step. Add a Back chevron and keep answers when going back.
- Must: steps 2, 3, 6 cannot be skipped (Next is disabled until a pick). Add Skip.
- Should: progress bars are hidden from VoiceOver. Add "Step N of 10".
- Should: titles use fixed sizes (`Cream.rounded(40)`); check Dynamic Type at the largest size on a device.
- Should: step 9 (Plus, not built) only persuades. Cut it from first run, or keep it as "Coming soon" + Next.
- Mock and code differ in places (below). The mock must match the code.

## Per slide
1. Hero: tiles copy Instagram and YouTube (camera on orange, play on red). Use plain tiles. Big gap under the subtitle.
2. Hours: "about average" sticker is an unverified claim; remove. Selected row is tilted and scaled, so it breaks the side margins. No tilt on controls.
3. Apps: tiles use six brand-like colours (more than one accent). White on orange is 3.67:1, on amber 3.86:1, on blue 4.19:1 (all under 4.5:1). Use neutral tiles and one accent. "Got it. Next, we lock them." is filler; remove.
4. Screen Time: mock draws a fake system box with a second Continue. Remove; one Continue only. Mock copy "Only you can unlock them" does not match code and is unverified. Use the code text.
5. Picker: mock shows app names (Instagram, X, YouTube). The real screen cannot read names; iOS draws icons only. Show nameless tiles. Add "Change apps". Mock subtitle differs from code.
6. Goals: mock is ragged chips with tilt; code is a 2-column grid. Show the grid. Floating sticker is not needed.
7. Year: mock shows 53 days but slide 2 picked "5 to 6 hours" = 84 days and 42 back (code math). Mock also lacks the estimate note that code has.
8. PC: mock draws a QR on the phone. The phone scans the PC's QR, so that is wrong. Mock invents `lockin.app/pc`. Show a scan frame instead. Button before the camera box should read Continue.
9. Plus: "Try Plus" implies a purchase that does not exist. Code says Next + coming soon. Sub-lines under each card break the no-paragraph rule.
10. Ready: "you got this" sticker is filler. Ring should be full. Mock lacks "Not now".

## Open decisions for Brandon
- Slide 8 and 5 keep a quiet text link ("I only have a phone", "Skip for now") next to Continue. Apple's one-button rule is about the primary button; check this against review.
- Slide 9 stays (Brandon decided). Its one button reads "Not now" until Plus is built. Then add "Try Plus" above it.
