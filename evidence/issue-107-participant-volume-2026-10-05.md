# Issue #107 — participant volume persistence

Status: NOT_RUN. Owner requested code-only merging; native tests, builds,
artifacts, deployment and device acceptance are deferred to the grouped run.

## Implemented contract

- Remote microphone 0–200%, default 100%, independent screen audio level.
- Stable remote account ID and signed-in owner; SID/lease/display name never
  form persistence keys. Web uses same-origin localStorage; native includes
  normalized deployment origin (scheme/host/port, API path excluded).
- Gain/cache update immediately; writes coalesce for 250ms. Native slider end,
  channel leave, logout and dispose flush the captured old owner's document.
  Web account unbind/pagehide/dispose flush synchronously.
- Channel rejoin reloads preferences. Existing reconnect/track-subscription
  handlers apply saved levels to the newly attached account-bound tracks.
- Explicit audio-settings reset replaces the current owner's whole document;
  inactive peers and screen levels return to 100%; transient screen mute remains.
- Storage failures use 100% on restoration, allow current-call gain changes,
  and show a nonblocking warning. Successful persistence can recover normally.
- Browser v1 same-origin levels are retained until reset. Native originless v1
  values remain untouched but are not assigned to an unproven server; users
  set their level once under the new origin-scoped document.
- Slider accessible name includes the participant; value is spoken in percent.
- OTLP sends only volume_preference_apply=success|fallback|error and bounded
  client.platform. Server drops percentages, identifiers, names and other attrs.

## Focused tests added/updated (NOT_RUN)

Web: persistence coalescing/flush, normalization/corrupt storage, account
isolation/reset, rejoin/new SID/rename, logout/relogin, delayed reset/account
lookup races, telemetry whitelist/throttle.
Flutter: account/origin isolation, reopen/reset, 0/100/200 and invalid levels,
corrupt storage, originless legacy exclusion, coalescing/flush, stable account
binding across changed identity/name, logout flush, slider semantics/end/reset UI.
Go: relay acceptance for all requested platforms and closed outcome privacy.

## Deferred native commands

- Web: npm test -- participant_volume voice_volume
- Flutter: flutter test test/voice_volume_preferences_test.dart test/participant_volume_test.dart test/participant_volume_lifecycle_test.dart test/participant_volume_ui_test.dart
- Go: go test ./internal/observability/ingest_client_traces/...
- Client type analysis/lint and grouped builds after focused tests.

## Physical acceptance (all NOT_RUN)

Run two authenticated clients on one deployment for Web, Android, Windows and
physical iOS runner/device. With a speaking peer, check audible 0/100/200 and
visible percent; leave/rejoin, reconnect, replace remote SID, rename peer,
restart client, logout/login as same owner. Confirm level restores each time.
Switch local account and deployment: defaults 100 with no other owner's levels.
Reset with active and inactive peers: 100 on live tracks and later rejoin.
Deny/corrupt local preference storage: call/gain controls still work, warning
visible, restoration defaults 100. Screen mute/deafen remain independent.
Check keyboard/screen-reader name and percentage. Inspect sanitized telemetry
for absence of IDs/names/selected levels. Record device/build versions and
PASS/FAIL per scenario without tokens, identifiers or audio recordings.

Do not close #107 or claim audible/device PASS until this protocol is run.
