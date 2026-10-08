# #176 screen-media rollout: source evidence

Date: 2026-10-09. Base: 2c510dce. Branch: codex/media-feature-rollout.
Status: source PASS; physical pilot/release/rollback acceptance NOT_RUN.

## Reachable changes

Web has strict independent build switches for descriptor v1, HTTP JPEG,
VP8/H264 capability policy and bounded simulcast. Publisher bindings freeze the
decision across start/republish/repair. Preview sender and reader snapshots stop
HTTP work when disabled, retaining local thumbnails and selected media ownership.
Native has typed compiled descriptor-reader/JPEG switches and explicit desktop
bounded simulcast. Default is one VP8 layer, with backup codec disabled; native
Android/iOS stay one layer. Updates retain active topology and recompute caps.
Capture/factory fixes remain mandatory; there is no unsafe legacy adapter toggle.

Native preference schema v1 stores compatible quality IDs by canonical origin
and account. Actual AppState initialization restores only while idle; explicit
successful start/update saves the confirmed profile. Account/origin/logout
boundaries reject old completions, cleanup resets memory without deleting stored
preferences, and unknown future preference versions are preserved.
Catalog/ADR source defaults now match actual single-layer baseline.
See `docs/runbooks/screen-media-rollout.md` for exact flags and QA rollout steps.

## Observed native checks

- Baseline Web profile/metadata/preview: 17 tests PASS; native baseline: 22 PASS.
- Red preference tests failed for missing source before implementation; new
  Web flag tests initially failed for the missing policy module.
- Focused Web flags/publication snapshot: 7 PASS, including actual adapter
  start/republish/repair snapshot and next binding with changed flags.
- Focused Flutter flags/preferences/actual AppState/mixed parser: 12 PASS.
- Shared mixed descriptor fixture parser: native PASS with default flags and
  with `QA_SCREEN_DISABLED=true`, `BOOHTACORD_SCREEN_DESCRIPTOR_V1=false`,
  `BOOHTACORD_SCREEN_PREVIEWS_V1=false` compiled into the test binary.
- Full Web: 446 files / 1388 tests PASS. Production typing + Vite build PASS
  with explicit test-only `VITE_PUBLIC_ORIGIN=https://app.example.test`.
- Full Flutter: 912 PASS, 1 pre-existing skipped test. Scoped analyze PASS.
- `tools/verify/contracts/verify-contracts.ps1`: 19 parity tests PASS,
  OpenAPI schema PASS, 99 public operations / 3 private exclusions PASS.
- `tools/verify/spec_traceability/verify-spec-traceability.ps1`: 39 requirements PASS.
- `git diff --check` PASS; changed executable files all <=120 lines.

## Unperformed acceptance

No physical mixed-client pilot, moving-content frame measurements, hardware
load/capacity, production rollback, new signed APK/Windows/macOS/iOS releases,
or hosted release workflows were run for this packet. Releases #59/#60/#61
remain NOT_RUN/NO-GO. Pure calibrated slow-supervisor logic remains unapplied;
source flags do not authorize enabling adaptation or experimental profiles.
Fork versions/UPSTREAM SHA inventories/license/patch docs were inspected; no
upstream bump or SDK patch is part of this packet. This evidence closes source
gaps only and must accompany a separate concrete QA acceptance task.
