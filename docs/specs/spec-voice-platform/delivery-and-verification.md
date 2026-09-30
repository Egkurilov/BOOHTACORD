# Поставка, доказательства и release gates

## Current delivery baseline

The source tree contains Go API, Vue client, Docker Compose topology, contracts, tests, operator documentation and evidence records. GitHub `master` is the selected source and delivery route under ADR-011; its first trusted deployment is not yet evidenced. This status is not a declaration that all product acceptance gates are closed.

## Validation commands

Run from the repository root when the respective runtime is available:

```powershell
Push-Location backend; go test ./...; go vet ./...; go build -o $env:TEMP\voice-platform-api.exe ./cmd/api; Pop-Location
Push-Location frontend; npm test; npm run build; Pop-Location
& .\scripts\verify-contracts.ps1
& .\scripts\verify-spec-traceability.ps1
docker compose --env-file .env.example -f compose.yaml config --quiet
```

The expected automated scope is contract shape/traceability, Go unit and package checks, Vue unit tests/build, Compose interpolation and deployment-guard tests. It cannot prove physical game capture, acoustic loop absence, final network capacity or a full authenticated visual acceptance.

## Evidence classification

| Evidence record | Recorded result | What it establishes | What it does not establish |
| --- | --- | --- | --- |
| `deployment-remote-176108242211-002.json` | `PASS` | Public health/landing routing, HTTP→HTTPS redirect, private service isolation, no public metrics, composed services healthy. | WebRTC, screen sharing, two-machine media acceptance, automatic CI/CD. |
| `voice-connection-smoke-production-2026-09-18-001.json` | `PASS` | One Windows Chrome connection, room-scoped credential and rendered voice controls. | Game capture/audio, separate observer, macOS and no digital loop. |
| `integration-runtime-trace-2026-09-19-001.json` | `PASS_RUNTIME` | Owner-reported Windows/macOS voice and screen usage with sanitised server counters. | POC-01 observer criteria, game audio, loop absence, capacity or error-free media. |
| `release-guildchat-reference-parity-2026-09-19-003.json` | `PASS_RUNTIME` with visual sub-gate blocked | Frontend test/build, contract traceability, served bundle and public health. | Authenticated pixel-level visual acceptance. |
| `poc-01-preflight-production-2026-09-19-002.json` | `BLOCKED` | Production preflight only. | Any POC-01 result. Physical Windows/macOS presenters and observers were absent. |
| `capacity-preflight-production-2026-09-19-001.json` | `BLOCKED` | A static VM observation and healthy services. | 100-participant/20-room/screen-publisher capacity. |

Other evidence records must be read individually with their stated scope. `PASS_STATIC`, `PASS_RUNTIME`, `BLOCKED` and `NOT_RUN` are not interchangeable with a full release acceptance result.

## Release gates and delivery status

1. **POC-01:** two independent physical runs: Windows presenter and Apple-Silicon macOS presenter, each with a distinct physical observer. Each observer must verify moving real-game video, game audio and presenter voice, while the presenter verifies no sustained digital loop.
2. **POC-02:** measure 720p/30, 720p/60, 1080p/30 and 1080p/60 with moving game content; record measured resolution, decoded FPS, bitrate, RTT, loss and recovery.
3. **POC-03:** with real connected media, verify kick, ban, logout, session revocation and voice-channel close against reconnection plus previously issued API/SDK credentials.
4. **Capacity:** run the approved load profile on selected infrastructure for 100 guild voice participants, up to 20 per room and the specified stream-publisher profile. Network quota and CPU scheduling must be measured, not inferred.
5. **Security and UX:** finish negative ACL/privacy regression coverage, authenticated browser E2E and accessibility/screenshot acceptance at required desktop zooms.
6. **CI/CD · GitHub CI и deploy PASS:** ADR-011 определяет GitHub `master` production writer. [GitHub migration evidence](../../../evidence/release/github-migration-2026-09-30-001.json) фиксирует успешные contracts, backend, frontend, GHCR publish, Windows CI и guarded production deploy на GitHub runners. [GitVerse run #1653749](../../../evidence/release/qa11-gitverse-oci-2026-09-26-001.json) остаётся историческим подтверждением прежнего маршрута. Production release всё ещё использует локальную OCI-сборку. Android signing и macOS runner ожидают настройки; QA-11 на новом маршруте не закрыт одним migration record, live rollback QA-12 и общий release verdict QA-14 открыты.

## Release decision rule

Release is allowed only when required automated checks pass, hardware POC evidence is current and `PASS`, capacity evidence matches the chosen infrastructure, CI/CD deploy/smoke is confirmed and no open security or agreed user-scenario blocker remains. A green health endpoint, unit-test suite, mock UI, single browser smoke or trace of one successful call cannot close a media/capacity/security gate.

## Operations and owner actions

- Owner bootstrap/recovery uses the documented Compose operator profiles and stdin password input. Do not place the secret in source, shell history, command arguments, evidence or issue text.
- During trusted release, maintenance admission blocks new registration/login/lease/signal admission while preserving existing protected reads and established media; it is disabled only after proxy validation and public health.
- Storage pressure is handled by admission control and explicitly authorised stale-staging cleanup. It never authorises deleting published messages or attachments to free disk.
- Before release operations, verify pinned image references, compatible migrations and persistent volumes. Do not create backups or automatic down migrations as part of this product.

## Specification maintenance

Update this specification whenever a capability, security boundary, contract, release gate or verified evidence status changes. Change OpenAPI/JSON Schema first for interface changes, keep `mobile-client-contract.md` aligned, run the relevant validators, then append the decision and validation verdict to `.memlog.md` before re-deriving `SPEC.md` and its companions.
