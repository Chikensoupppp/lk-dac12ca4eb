# Phone + PC pairing - plan

Status: plan only. Nothing built. Written 2026-11-04.

## Goal
One tap on the iPhone starts the same session on the Windows PC. End or finish on either side and both stop. Later (Milestone 3) the PC opens saved work.

## What exists today
- `apps/windows-companion/Program.cs`: a small web service on `127.0.0.1:47821` (this PC only). Endpoints `/health`, `/session/start`, `/session/stop`. In-memory session. Makes its own session id.
- `packages/protocol/session.schema.json`: session shape (id, state, durationSeconds, startedAt, endsAt, capabilities).
- iPhone app: local session only (`SessionRecord`, UserDefaults). No network code.
- A user must install something on the PC: a small Lock In companion. It does not exist as an installable app yet.

## Design choices (recommended)
1. **Pairing by QR code.** The PC app shows a QR code once. It holds: PC address, port, a one-time secret, and the PC's certificate fingerprint. The phone scans it and keeps the secret in the Keychain. Why: no typing, no guessing which PC, and it carries what is needed to trust the PC.
2. **Encrypted and authenticated.** HTTPS with a self-made certificate on the PC. The phone only trusts that exact certificate (fingerprint from the QR). Every request carries a token derived from the secret. No plain HTTP on the network. (The current README says endpoints are unauthenticated and loopback-only. Keep it that way until this is done.)
3. **Phone is the boss of time.** The phone sends session id, startedAt and endsAt. The PC mirrors them and expires itself at endsAt, even if the phone dies. The PC also reports its own clock so drift can be checked.
4. **Phone works without the PC.** If the PC is off or unreachable, the session still starts on the phone and shows "PC offline". It retries. Never block a session on the network.
5. **Finding the PC when its address changes.** Start with the address in the QR. Add Bonjour (mDNS) later as a fallback. Not verified yet that Windows answers `name.local` reliably.

## Pieces
PC (testable here on Windows):
- Tray app (no big window): start with Windows, status icon, "Pair phone" window with the QR code.
- HTTPS + token auth, `/pair`, `/session` (read), `/session/start` and `/session/stop` accepting phone-supplied id and times.
- Windows Firewall: first run asks to allow private-network access.
- Updated schema and checks in `tests/windows-companion`.

iPhone (builds only in GitHub Actions on a Mac):
- `NSLocalNetworkUsageDescription` and camera permission text.
- QR scanner screen, Keychain storage, `PCClient` (pinned certificate), retry queue.
- Small PC status chip on the main screen: not paired, connected, offline.
- Unit tests with a fake client. UI test for the chip states.

## Phases
1. PC side: tray app, HTTPS, auth, pairing endpoint, session mirroring, checks. Test with curl on this PC. No repo-public step needed.
2. iPhone side: client, pairing screen, chip, wiring into `startSession` / `endSession` / `completeSession`. CI build (repo public briefly), then TestFlight.
3. Real test: this PC plus your iPhone on the same Wi-Fi. Start, end early, finish, PC off, Wi-Fi off, app killed.
4. Polish: auto-start, installer, firewall prompt wording, Bonjour fallback.

## Risks (not verified)
- Home routers with "client isolation" block phone-to-PC traffic.
- Windows marks some networks "Public" and blocks inbound connections.
- The phone's IP/PC's IP can change. Needs the fallback in phase 4.
- iOS shows a Local Network prompt. If denied, pairing fails. The app must say so plainly.
- Away from home there is no sync (no relay server in this plan). The phone still works alone.
- No installer yet. First version is a build you run.

## Out of scope here
Opening apps and sites on the PC, blocking on Windows, and a cloud relay. Those are Milestones 3 and 4.
