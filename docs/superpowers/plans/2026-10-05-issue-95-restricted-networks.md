# Issue 95 restricted networks implementation plan

> Execute inline in this session; no agent delegation. User requested implementation.

**Goal:** Measure signal, SDK join, ICE and actual RTP under isolated transport
restrictions, and provide the same private diagnostic projection for real networks.

**Architecture:** Bind a read-only observer to the existing LiveKit room factory.
Keep authentication, cookie admission, leases, subscriptions and media ownership.
Run real Chromium peers against a disposable pinned LiveKit server. Publish only
the loopback transports allowed by each profile, never alter host firewall rules.

**Tech Stack:** Vue/TypeScript, LiveKit 2.22.3/1.13.7, Playwright, Python, Docker.

## Operating brief

- workflow_class=split_first; task_size=medium; structure_mode=structure_no_rg.
- Packet A leaf: `clients/web/src/voice/network_diagnostics` (one report trigger).
- Packet B leaf: `tools/network/restricted` (one controlled matrix trigger).
- Native bindings: `livekit_room_factory.ts`, `livekit_gateway.ts`, web CI runner.
- Baseline: signal behind HTTPS, media UDP 50000–50100 / TCP 7882, no TURN.
- Ratchet: source target 100/hard 120 lines; leaf target 8/hard 16 files/tests.
- Validation: focused Web/native harness tests (previous user test authorization),
  real browser matrix, Web build, contracts, traceability, links, GitHub CI.
- Stop: concrete source/report reviewed and integrated; never close #95 while
  home/hotspot or applicable physical/load/revocation gates lack evidence.
- Open: hotspot requires operator access; Docker daemon unavailable locally.

## A. Private real-room diagnostics

- [ ] Add `model.ts`, `stats.ts`, `attempt.ts`, `bind.ts`, `export.ts` and
  `operator.ts` under `clients/web/src/voice/network_diagnostics`.
- [ ] Add focused `stats.spec.ts`, `attempt.spec.ts`, `bind.spec.ts` and
  `export.spec.ts`. Use nominated-but-not-selected and poisoned-address fixtures:
  ```ts
  expect(JSON.stringify(projectTransport(stats))).not.toContain('private-address')
  expect(projectTransport(stats).protocol).toBe('udp')
  ```
- [ ] Hook `bindNetworkDiagnostics(room, liveKitRoom)` in
  `clients/web/src/voice/livekit_room_factory.ts` and an optional
  `readNetworkDiagnostics` method in `livekit_gateway.ts`.
- [ ] Preserve errors/rejection, timeouts and cleanup. No logging raw errors,
  candidates, URLs, SDP, tokens, account/room/track IDs or PCM. Keep null for
  unsupported observations. First observed ICE/RTP times are not exact wire times.
- [ ] Export through an explicit operator console function, with a closed field
  projection. No automatic upload and no new product UI flow.
- [ ] Run `npm test -- src/voice/network_diagnostics` and `npm run build`.

## B. Isolated restricted-network matrix

- [ ] Create `sfu.py`, `run.py`, `browser.mjs` under `tools/network/restricted`;
  ports 17880 signal, 17881 ICE/TCP, 7882 UDP, loopback only, UUID container owner.
- [ ] Create `fixture.html`, `fixture.ts`, `matrix.browser.spec.ts` and
  `playwright.config.ts` under `clients/web/tests/restricted_networks`.
- [ ] Validate real selected UDP baseline, selected TCP after removing UDP
  publication, signal success but ICE failure after removing both media mappings,
  signal failure when connecting to an unbound loopback endpoint, and restored
  baseline. Assert RTP counter growth in two real browser contexts.
- [ ] Store numeric/enum reports under `.out/restricted-networks`, source SHA,
  browser/server versions, exact fault mechanism, recovery and gate status.
  Connectivity FAIL in the restricted profile is an expected measured result,
  never a claim that the network is supported. Local dev grants do not prove ACL.
- [ ] Add `test:restricted-networks` to `clients/web/package.json`, integrate
  `python -m tools.network.restricted.run` in `tools/ci/native/web.py`.
- [ ] Run Docker/browser measurements on the isolated Linux CI runner. Ensure
  context and container cleanup even on failure. No production network mutation.

## C. Operations and decision

- [ ] Add `docs/runbooks/restricted-networks.md` with repeatable home/hotspot
  protocol, muted listener join, two safe reports around controlled speech,
  restricted-network and restore conditions, and explicit NOT_RUN states.
- [ ] If the matrix confirms signal-only connectivity failure, write
  `docs/adr/ADR-017-restricted-network-turn-tls.md`: conditional proposal,
  separate TURN hostname/certificate and dedicated IP:443 or separately reviewed
  L4 SNI topology; Caddy HTTP `/rtc` cannot forward raw TURN. Cover bandwidth,
  costs, private management, admission, revocation, expiry and QA-06/09/10 gates.
- [ ] Update the exact IMP-31 section of `backlog/improvements/OPS_TODO.md` and
  add `evidence/issue-95-restricted-networks-2026-10-05.md` with observed data.
- [ ] Run traceability/contracts/link checks; inspect diff and file sizes before
  explicit staging; push semantic branch, create/attach PR, await source CI and
  integrate using existing user merge authorization. No native release rebuild.
