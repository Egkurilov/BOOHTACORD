# Screen sharing stability: SS-02 baseline harness

## Route and packet

- Slavik Gym classification: `split_first`; execute the single leaf `T-032` / GitHub #158.
- Capability: test-only minimal LiveKit publisher/viewer, catalog-derived `motion-1080p60-v1` source/bitrate values, synthetic moving source and user-initiated display capture, sanitized numeric evidence.
- Route: `clients/web/tests/screen_profile/`, the existing Playwright config/command, `docs/screen-share-baseline.md`, focused evidence only.
- Credentials are caller-provided short-lived tokens held in process/page memory; do not add token endpoints, credentials, media payloads, or production load.
- Reuse the pinned `livekit-client` package and same configured LiveKit server for publisher and viewer.

## Implementation sequence

1. Add tests first for counter resets, controlled FPS deltas, presentation gaps, frame markers, credential target policy, and sanitized stats.
2. Add an opt-in Playwright run using isolated publisher/viewer credentials, a single-layer minimal LiveKit publication, and a remote viewer. Keep the timing aligned with SS-01: 30-second warm-up, 180-second run, 1-second windows, five repeats.
3. Add a test-only page with synthetic canvas and user-triggered `getDisplayMedia`, using no BOOHTACORD production UI, guard, preview, or profile repair code.
4. Record source, encode, network, decode, and presentation observations separately. Export only allowlisted numeric stats and bounded codec/protocol labels; omit tokens, SDP, IDs, addresses, and captured pixels.
5. Document launch and report fields. Run the focused browser suite and typecheck; live SFU, shaped-network, and physical-device acceptance remain `NOT_RUN` without an isolated server and device.

## Stop condition

Stop when the harness is executable with isolated short-lived tokens, returns a bounded numeric report, supports both source modes, and clearly separates a test run from physical/production acceptance.
