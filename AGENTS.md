# Lock In engineering instructions

- Read `PROJECT_STATUS.md`, `HANDOFF.md`, and `git status` before starting work.
- Preserve existing work; make small, reviewable changes.
- Never commit secrets, API keys, pairing tokens, or user workspace contents.
- Treat iOS Screen Time and Windows restriction capabilities as runtime-dependent. Do not present a mock or unavailable capability as active.
- Keep session state transitions explicit and recoverable: `idle -> starting -> active -> ending -> idle`, with `failed` available from any non-idle state.
- Validate changed code with the narrowest relevant build or test command before widening scope.
- Update `PROJECT_STATUS.md` and `HANDOFF.md` when a milestone changes.
