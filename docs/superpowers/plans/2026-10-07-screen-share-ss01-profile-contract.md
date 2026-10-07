# Screen sharing stability: SS-01 profile contract

## Route and packet

- Slavik Gym classification: `split_first`; execute the single leaf `T-031` / GitHub #157.
- Capability: versioned screen-share descriptor, quality catalog, geometry fixtures, and Web/Flutter parity tests.
- Route: `contracts/`, `docs/adr/ADR-018-*`, `clients/web/src/voice/screen_profile/`, `clients/flutter/lib/src/features/screen/profile/`, `clients/flutter/lib/src/features/screen/capture/`, and focused tests.
- Preserve user-visible profile IDs, bitrates, track naming, capture lifetime, selected-stream behavior, and SDK-owned congestion control.
- Keep a small Flutter compatibility export for older screen setup and test imports while native screen feature edges point at the leaf capability.
- Do not implement the independent SFU baseline (#158), telemetry collection (#159), publisher lifecycle adapters (#160/#161), or production QA in this packet.

## Implementation sequence

1. Add focused contract tests in TypeScript and Dart that read the same catalog/fixtures and exercise the existing bitrate and geometry policies.
2. Define schema v1, compatibility catalog, geometry/lifecycle fixtures, and ADR-018 with proposed SLOs clearly marked as unvalidated experiments.
3. Fix only geometry behavior required for shared aspect-ratio/even-dimension invariants; preserve profile and publishing behavior.
4. Run focused Web and Flutter tests, contract/traceability verification, format/lint/build checks that are available. Record unavailable environment-backed checks as NOT_RUN.

## Stop condition and evidence

Stop when contract semantics are versioned, both clients pass identical fixtures, current legacy bitrate behavior remains unchanged, and the narrow verification set is recorded. Physical SFU/FPS acceptance is outside this packet and stays NOT_RUN.
