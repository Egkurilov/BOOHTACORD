# Web screen-share publisher lifecycle (#160)

- Date: 2026-10-07
- Branch: `codex/ss-publisher-web-160`
- Base commit: `222e3e6755d3433166514c7bf5428517595ab222` (#157)
- Leaf: `clients/web/src/voice/screen_publisher`
- Environment: Windows, Node `v24.18.0`, npm `11.16.0`

## Source/API review

- The existing Web adapter routes initial capture through `LocalParticipant.setScreenShareEnabled`, profile changes through capture constraints plus public `unpublishTrack(track, false)` / `publishTrack(track, options)`, and cleanup through public unpublish APIs. The retained `MediaStreamTrack` is preserved during profile update; screen audio is independent, and microphone publication is not addressed by the video update.
- SDK reconnect calls `republishAllTracks`, which unpublishes with capture retained and republishes the existing track. The Web adapter now listens for its matching publish event to refresh publication generation. Room reconnect suspends profile diagnostics; `Reconnected` rebinds them to the republished sender. A still-live retained track is no longer classified as OS-ended.
- Web screen-share app-owned sender writes: none. Sender parameter writes in the microphone-processing path remain outside this screen publisher. No `any` cast or private LiveKit member was added.
- Pinned package: `livekit-client@2.22.3`; npm lock integrity `sha512-jw9zBKXY5Gtr5MZ7vEON3QhMNccuDvYHck1PFSyG1aaateQPqgKZFBMgZkFZaXHIf9RV4MDW5xpTK2b/+qbwOg==`.
- Installed SDK ESM SHA-256: `23E6B0966C20CCABA8D39343035FCC49E64AA46C93E772CA0A3F1B5A6D30B573`.
- `LocalParticipant.d.ts` SHA-256: `D9D9A61F27A0252DD3E03E56879E304588974089A00A37A90BE823F59D09C468`.
- The pinned `TrackPublishOptions` has no v1 per-publication descriptor field. `LocalParticipant.setAttributes` is participant-level and permission-gated by `canUpdateOwnMetadata`, which the current room contract does not guarantee. No metadata transport is claimed; descriptor visibility/parity on another client remains an explicit API/integration gap.

## Checks

| Check | Result |
|---|---|
| Focused lifecycle/profile tests | PASS — 3 files, 15 tests |
| Web Vitest suite | PASS — 387 files, 1,200 tests (`npm test`) |
| Web typecheck + production build | PASS (`npm run build`); Vite emitted chunk-size and ineffective dynamic-import warnings |
| Contract boundary check | PASS (`tools/verify/contracts/verify-contracts.ps1`) |
| Requirement traceability | PASS — 39 requirements (`tools/verify/spec_traceability/verify-spec-traceability.ps1`) |
| `git diff --check` | PASS |

## Runtime acceptance

`NOT_RUN`: isolated LiveKit/SFU with a second viewer, cross-client descriptor observation, reconnect and Dynacast races on a real session, OS picker/capture behavior, and physical capture FPS/audio continuity. Unit tests and build do not establish these runtime properties. Keep issue #160 open until these gates have evidence and descriptor transport is resolved.
