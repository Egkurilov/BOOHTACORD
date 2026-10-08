# Screen media rollout source completion (#176)

Route: split_first, then bounded implementation packets in screen_rollout,
screen_preview, native screen/rollout and screen/preferences.
Source base2c510dce; preserve existing user capture consent, one selected RTP
video, independent voice/screen audio and authenticated preview HTTP ACL.
No SDK/SFU bump, old RTP-preview branch, second capture/encoder or remote config.
Hard120lines; leaves hard16 production/tests; exact native imports only.

## A: session-bound feature switches

- [x] Baseline Web plan/metadata/preview and Flutter profile/preview tests.
- [x] Add failing typed Web flags/default/independence/session-boundary tests.
  Preserve descriptor/JPEG default enabled, simulcast disabled. Codec policy may
  disable H264 fallback while retaining VP8 capability guard. Unknown flags use
  conservative declared defaults. Capture and sender use immutable adapter
  snapshot; changing build config requires new client/room, never auto-capture.
- [x] Gate sender JPEG HTTP and reader hints/GET without disabling local thumbnail
  sampling or changing selected media subscriptions. Preserve terminal cleanup.
- [x] Add native compiled immutable preview and bounded-simulcast flags. Default
  one layer for all platforms; Android remains one layer even opted in. Native
  desktop opt-in at most one lower layer, no backup encoder. Preserve active
  lastPublishOptions on quality update. Native capture fixes are mandatory,
  cannot safely toggle back to known defective native/legacy implementations.
- [x] Run focused native tests, Web typing/build, Flutter scoped analyze.

## B: typed native quality preferences

- [x] Red tests for invalid/unknown schema, origin/account isolation and delayed
  completion across logout/server changes; no credential/account data clearing.
- [x] Store only compatible profile IDs in existing SharedPreferences, separate
  namespace by HTTPS origin/account. Load at account initialization while idle;
  save only successful explicit start/update through tiny application edges.
- [x] Retain requested quality through rollback/restart; no active screen restart
  or profile application solely due preference/config changes.
- [x] Run focused persistence and screen lifecycle regressions.

## C: compatible delivery evidence

- [x] Probe mixed metadata versions/unknown enums/revisions and missing preview
  with real typed client parsers; old track labels remain readable, no RTP preview.
- [x] Review native UPSTREAM.json/licenses/patch manifests and existing delivery
  rollback paths; document exact enable/disable/default/apply boundaries.
- [x] Record source PASS separately from pilot/physical/load/hosted release
  acceptance NOT_RUN; gates59/60/61 are not closed by source tests.
- [x] Inspect status/sizes, commit locally only. Root owns push/integration/QA.

Slow adaptation application remains disabled without accepted calibration. A
shadow evaluation uses only existing typed observations and cannot create media;
no flag will claim an unimplemented or unvalidated applied mode is available.
Stop: reachable source gaps and available native checks completed; runtime pilot,
deployment rollback, mixed physical clients and load remain explicit QA gates.
