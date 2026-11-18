# SwipeLater: App Store listing (US, English), ready to paste

Replaces the draft in `app-store-metadata.md`. Counts checked with a script on 2026-11-18.

## Data behind the choices (Sonar, US, 2026-11-18)

| Keyword | Popularity | Difficulty | Read |
|---|---|---|---|
| app blocker | 53 | 59 | Big, crowded. Already in the name. |
| screen time | 51 | 62 | Big, crowded. Needs a slot in the subtitle. |
| focus timer | 38 | 58 | Medium. "Focus" (name) + "Timer" (subtitle) cover it. |
| block apps | 28 | 51 | Small, mid difficulty. |
| doomscrolling | 18 (estimate) | 43 | Small but winnable (top 3 are weak). |

Top results for "app blocker focus": Opal (91k ratings), Brick (60k), Foqos (6k). We cannot beat them on
"app blocker" yet. Win the small terms first (study, doomscroll, brain rot) and use the hook
"Slide to lock in" to stand out. Not verified: Apple's real ranking for our app (the app is not live).

## Fields

- **Name (30):** `SwipeLater: Focus App Blocker` (29)
- **Subtitle (30):** `Screen Time & Study Timer` (25). Old one was `Block Apps. Lock In.`; the new one puts
  "screen time" (51) and "study timer" into the high-weight field. "Lock in" moves to the promo text.
- **Keyword field (100):** `block,lock,social media,brain rot,doomscroll,homework,limit,distraction,screentime,detox,scroll,task`
  (exactly 100). No spaces after commas. Do not repeat words from the name or subtitle.
- **Promo text (170 max, can change without review):**
  `Slide to lock in. SwipeLater blocks the apps that eat your time, so your distractions can wait.` (95)
- **Category:** Productivity. Secondary: Health & Fitness (optional).
- **Support URL:** https://swipelater.app
- **Marketing URL:** https://swipelater.app
- **Privacy Policy URL:** https://swipelater.app/privacy/

## Description (4000 max)

Your phone eats your day. SwipeLater gives it back.

Pick the apps that pull you in. Slide to lock in. Until your timer ends, those apps stay closed. No
willpower needed.

HOW IT WORKS
- Choose the apps you want to pause, once. Change them any time.
- Set a time and slide to lock in. Apple's Screen Time tools close the apps for you.
- Watch the brain on your home screen get happier as your focus time grows.

THINGS THAT MAKE IT STICK
- A friend as your Key Holder. If you want out early, your friend has to say yes.
- A weekly goal and a streak, so a good week feels like a win.
- Optional Windows app. Your PC and phone start a session together, and the desk buddy nudges you if
  you drift to a distracting window.
- A live timer on your Lock Screen.

PRIVATE BY DESIGN
No account. No ads. No tracking. Your focus history stays on your phone. Your app list stays inside
Apple's Screen Time and SwipeLater never sees the names.

SwipeLater Plus unlocks all features. Payment is charged to your Apple ID. A subscription renews
automatically unless you cancel at least 24 hours before the period ends. Manage or cancel it in
Settings > Apple ID > Subscriptions.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://swipelater.app/privacy/

(Check against the real Plus products in App Store Connect before pasting: if Plus is a one-time
purchase, delete the subscription sentences.)

## What's New (version 1.0)

Hello. This is the first version of SwipeLater. Pick your apps, slide to lock in, get your focus back.

## App Review notes (paste into "Notes")

- No sign-in is needed. The app has no accounts.
- Screen Time (Family Controls): on first run the app asks for Screen Time access. Tap Allow, then
  "Choose apps" and pick any apps. Start a session of 15 minutes or more to see the apps get locked.
  Sessions under 15 minutes do not lock apps by design.
- Subscriptions: SwipeLater Plus is offered at the end of the first-run slides and in Settings. It uses
  the sandbox, so reviewers can buy it free. "Restore" is on the same screen.
- Optional features that need extra hardware (not needed to review the app): Key Holder pairing needs a
  second iPhone; the Windows companion app needs a PC. The app works fully without them.
- Camera is used once, to scan the QR code that pairs a PC. Local Network is used to find that PC and a
  nearby Key Holder phone.
- Contact: put your email and phone number in the App Store Connect fields.

## Age rating

Likely 4+. No user-generated content, no web browsing, no mature content. Answer "None" to every
content question. Confirm in the questionnaire.

## App Privacy answers (App Store Connect). Check each against the real code before you submit

The privacy policy says no accounts, no ads, no tracking. Suggested answers, not verified by Apple:

- **Tracking:** No.
- **Purchases (purchase history):** Yes, collected through RevenueCat for app functionality. Not
  linked to your identity, not used for tracking.
- **Identifiers (User ID):** Yes. A random ID for RevenueCat and a random key ID for partner pairing.
  App functionality only. Not used for tracking.
- **Other user content:** Yes, only if you use a Key Holder: session status shared with the partner
  through iCloud (CloudKit) under random IDs. App functionality only.
- **Contact info, location, health, browsing, usage data, diagnostics:** Not collected.
- Screen Time data stays on the device inside Apple's framework, so it is not "collected".

## Do before you submit

1. Attach the Plus product(s) to version 1.0 in App Store Connect (an unattached one fails review).
2. Upload the screenshot set (see `swipelater-screenshots`).
3. Paste the fields above. Re-count the keyword field after pasting.
4. Add the 1024px icon. Fill the contact details and age rating.
5. Build `testflight-62` or newer is already in App Store Connect; select it for the version.
