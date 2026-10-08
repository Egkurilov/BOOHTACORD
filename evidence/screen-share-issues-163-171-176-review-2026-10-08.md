# Screen-share issue review: #163, #171, #176

- Reviewed: 2026-10-08
- Source revision: `0b1d09193e7deb54bbc7d62c5a2623efe1cc29bc`
- Scope: existing repository implementation and acceptance gaps. No production changes or deployment performed.

## #163 — private JPEG preview delivery

The bounded v1 vertical slice is present in this revision: server begin/upload/read/invalidate API; session, active publisher lease and LiveKit track verification; same-room viewer authorization; targeted metadata-only realtime hints; in-memory TTL store; JPEG container and decoded dimension validation; Web and Flutter sampling/readers with lifecycle invalidation. Detailed contract and known bounds are in `docs/runbooks/screen-preview-v1.md`.

| Check | Result |
|---|---|
| `go test ./internal/media/screen_preview/... ./internal/app/media_routes/screen_preview` (from `backend/`) | PASS — 6 packages |
| `npm run test -- --run src/voice/screen_preview` (from `clients/web/`) | PASS — 5 files, 17 tests |
| Flutter/Dart preview suite | NOT_RUN — Flutter/Dart SDK is not installed on this host |
| Real PostgreSQL + LiveKit authorization/publication round-trip | NOT_RUN |
| Device capture, late callback cleanup and RTP subscription count | NOT_RUN |
| 20-publisher load, multi-process deployment and revoke timing | NOT_RUN |

## #171 — LiveKit network and resource acceptance

The read-only repository topology validator, fixed-label metric allowlist/private scrape checks, scrape alert, runbook, and evidence record exist in `tools/verify/livekit_network_config` and `evidence/media/livekit-network-config-2026-10-07.json`.

| Check | Result |
|---|---|
| `python -m unittest tools.verify.livekit_network_config.test_model` | PASS — 15 tests |
| `python -m tools.verify.livekit_network_config.check` | PASS — checked-in topology, peers, labels, allowlist and alert |
| `docker compose --env-file .env.example -f deploy/compose.yaml config --quiet` | PASS |
| `docker compose -f docker/observability/compose.yaml config --quiet` | PASS |
| Effective deployment digest, NAT/firewall/TURN inventory | NOT_RUN |
| Publisher/subscriber selected ICE paths and paired playback | NOT_RUN |
| SFU/network resource baseline, capacity and test deployment rollback | NOT_RUN |

The deployment evidence makes no claim about production TURN, advertised IPs, physical paths, or capacity.

## #176 — staged rollout and rollback

Independent web rollout switches and conservative bounded-simulcast default are already present from the #157 work. Targeted publisher/metadata/registry tests pass: 3 files, 8 tests. This establishes source-level switch behavior only.

| Gate | Result |
|---|---|
| Independent rollout switch behavior in targeted Web tests | PASS — 8 tests |
| Mixed-version Web/Flutter client compatibility in a deployed candidate | NOT_RUN |
| Enable/disable boundaries during active share, preserving voice/audio and permissions | NOT_RUN |
| Physical/load gates #173/#174, integrated SFU gate #172, release gates #59/#60/#61 | NOT_RUN |
| Test deployment pilot, rollback, cache cleanup and installed-native forward-fix path | NOT_RUN |

**Decision: NO-GO for a rollout/closure claim.** Repository flags are groundwork; #176 remains open until dependent gates pass on a versioned test candidate and rollback evidence is attached. Use per-scenario `PASS|FAIL|NOT_RUN` with repository SHA, Web/API/SFU image digests, installed native versions, feature-switch values, test environment and sanitized aggregate artifact reference. Do not attach frames, SDP, credentials, addresses or participant IDs.
