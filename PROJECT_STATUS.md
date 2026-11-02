# Project status

Updated: 2026-11-01

## Implemented

- Private GitHub repository and permanent local checkout.
- Shared project instructions and product documents.
- Versioned session protocol with explicit lifecycle and capability reporting.
- Windows companion service with loopback health, session start, and session stop endpoints.
- SwiftUI iPhone shell for selecting duration and starting/stopping a local session model.

## Verified

- `dotnet build apps/windows-companion/LockIn.Companion.csproj`
- Live HTTP check: `/health`, `/session/start`, and `/session/stop` on `127.0.0.1:47821`

## Not yet verified

- iOS compilation and Screen Time authorization (requires macOS/Xcode and a signed device target; the current SwiftUI source is not yet inside an Xcode project).
- iPhone/Windows network pairing (Milestone 2).
- Actual Windows application/site restriction enforcement.
