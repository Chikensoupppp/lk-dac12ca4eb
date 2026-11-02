# Lock In

Lock In is a premium iPhone + Windows focus system: one tap starts a synchronized focus session, prepares the Windows workspace, and applies the strongest platform-supported distraction controls.

## Repository layout

- `apps/ios` — SwiftUI iPhone app and future Screen Time integration.
- `apps/windows-companion` — Windows companion service and workspace automation.
- `packages/protocol` — shared session contract and interoperability notes.
- `docs` — architecture and platform research.

## Current milestone

The initial vertical slice defines a safe session lifecycle and a local Windows companion API. Platform restrictions are capability-gated; Lock In never claims an unsupported iOS restriction is active.

## Development

`dotnet run --project apps/windows-companion/LockIn.Companion.csproj`

Session checks: `dotnet run --project tests/windows-companion/LockIn.Companion.Checks.csproj`

The companion binds to loopback only and its endpoints are currently unauthenticated. Do not expose it to a network. Session state is in memory, is lost on restart, and expiration is evaluated when the store is read or a new session is started; no background restriction cleanup is implemented. LAN pairing will be added only with an explicit pairing flow and authenticated transport.
