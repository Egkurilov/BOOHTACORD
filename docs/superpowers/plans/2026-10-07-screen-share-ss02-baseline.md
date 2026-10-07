# Screen sharing stability: SS-02 baseline harness

## Route and packet

- Slavik Gym classification: `split_first`; execute the single leaf `T-032` / GitHub #158.
- Capability: test-only minimal LiveKit publisher/viewer, synthetic moving source and user-initiated display capture, sanitized numeric evidence.
- Route: `clients/web/tests/screen_profile/`, the existing Playwright config/command, `docs/screen-share-baseline.md`, focused evidence only.
- Credentials are caller-provided short-lived tokens held in process/page memory; do not add token endpoints, credentials, media payloads, or production load.
- Reuse the pinned `livekit-client` package and same configured LiveKit server for publisher and viewer.

## Implementation sequence

1. Add an opt-in Playwright test using isolated publisher/viewer credentials and require exactly one synthetic screen publication and one remote viewer.
2. Add a test-only page with synthetic canvas and user-triggered `getDisplayMedia`, using no BOOHTACORD production UI, guard, preview, or profile repair code.
3. Record public SDK sender stats and receiver presentation counters as sanitized numeric values with explicit provenance; never serialize tokens, SDP, IDs, addresses, or captured pixels.
4. Document repeatable launch commands and report fields. Run static/unit checks; SFU/hardware baseline remains `NOT_RUN` without an isolated server and device.

## Stop condition

Stop when the harness is executable with isolated short-lived tokens, returns a bounded numeric report, supports both source modes, and clearly separates a test run from physical/production acceptance.
