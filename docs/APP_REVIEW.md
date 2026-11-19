# App Review notes and App Privacy answers

Two things App Store Connect asks for before the first submission. `scripts/asc-review.py` copies
the notes block below into the version's App Review Information (run with an `asc-review-N` tag).
The App Privacy answers are not in Apple's API, so they are entered by hand on the App Privacy page.

## App Review notes

<!-- notes:start -->
SwipeLater is a focus timer. During a focus session it blocks the apps the user picked, using Apple's Screen Time API (Family Controls, individual authorization). There are no accounts and no login.

HOW TO TEST
1. Open the app. The first-run intro starts (13 short slides). "Skip intro" on the first slide goes straight to the app.
2. On the "Allow Screen Time" slide, tap SHOW MY TIME and allow Screen Time. The next slide shows the user's own average screen time. It is drawn by our DeviceActivityReport extension; the app itself never reads or sends the numbers.
3. Pick apps to lock (the system app picker), then finish the intro. The last slide is the SwipeLater Plus offer; "Not now" closes it.
4. A short coach then helps pick a task, minutes and apps; hold the button to start. Later sessions start with LOCK IN. The picked apps show the Screen Time shield until the timer ends. END SESSION opens a short quit screen, then ends the session.

SCREEN TIME (FAMILY CONTROLS)
Used only to (a) shield the apps the user chooses during a session they start, and (b) show the user their own screen time in the intro. Nothing from Screen Time leaves the device.

SWIPELATER PLUS (auto-renewable subscription)
Yearly (with a free trial) and monthly. Plus adds:
- Locked mode: a session with no quit button.
- An accountability partner can end a Locked session early.
- The full weekly history (free users see the last 3 weeks).
To test Locked mode: buy Plus in the sandbox, tap "Locked mode" under the minutes on the Focus screen, start a short session. To leave early, END SESSION > Emergency exit (once a week, with a 15-minute wait). The session also ends by itself when the timer runs out, so please use the shortest length. Restore Purchases is on the offer screen.

OPTIONAL FEATURES (not needed for review)
- Accountability partner: two phones pair in person (Nearby Interaction + local network). Status and unlock requests go through the CloudKit public database, encrypted for the partner's phone.
- SwipeLater for Windows (free, swipelater.app/pc): pairs over the local network with a QR code.

Privacy policy: https://swipelater.app/privacy/
Contact: help@swipelater.app
<!-- notes:end -->

## App Privacy answers (App Store Connect > App Privacy)

Tracking: **No.** No data is used to track people across apps or websites. No ads, no analytics SDKs.

Data collected (each: used for App Functionality only, not linked to the user's identity, not used
for tracking):

| Category | Type | Why it leaves the phone |
| --- | --- | --- |
| Purchases | Purchase History | RevenueCat checks that a Plus purchase is active (random app user ID, no name). |
| Identifiers | User ID | The random RevenueCat app user ID, and the random partner IDs in iCloud. |
| User Content | Other User Content | The session status sent to a paired partner (locked/break/free, end time, the PC app in front), encrypted for the partner's phone. |
Not collected: name or other contact info, location, contacts, health, browsing history, search
history, usage data, diagnostics, Screen Time numbers (Apple keeps them on the device; the app
cannot read them). Remote unlock requests carry no name since build 99: the partner's phone shows
the name it saved when the phones paired.
