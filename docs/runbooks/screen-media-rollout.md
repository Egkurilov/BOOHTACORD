# Screen-media feature rollout (#176)

These switches are compiled client configuration, not server or remotely polled
values. Server secure-cookie/CSRF/ACL and preview contracts must ship first.
Existing clients continue with their compiled settings. A changed Web build takes
effect in a new client/Room binding; native settings require a new signed build.
An active publication keeps its topology through profile changes and repair.
Nothing starts capture or rejoins voice solely because configuration changes.

| Capability | Web build variable | Flutter `--dart-define` | Default |
|---|---|---|---|
| Descriptor v1 | `VITE_SCREEN_SHARE_DESCRIPTOR_V1` | `BOOHTACORD_SCREEN_DESCRIPTOR_V1` (reader controls) | true |
| HTTP JPEG preview | `VITE_SCREEN_PREVIEWS_V1` | `BOOHTACORD_SCREEN_PREVIEWS_V1` | true |
| VP8 / supported H264 selection | `VITE_SCREEN_SHARE_CODEC_POLICY` | Native VP8 mandatory | true |
| Bounded simulcast | `VITE_SCREEN_SHARE_BOUNDED_SIMULCAST` | `BOOHTACORD_SCREEN_BOUNDED_SIMULCAST` | false |

Use literal `true` or `false`. Invalid Web opt-in values remain disabled. Native
defines are typed Dart compile-time booleans. Native desktop opt-in has one
primary and one half-size, 15-FPS lower layer. Android/iOS remain single-layer.
Native backup codec is disabled so rollback cannot create a second codec encoder.
Web codec-policy disable keeps VP8 capability validation; unsupported VP8 fails
before capture rather than trying an unknown codec. Mandatory capture fixes and
native factory readiness have no switch back to their defective implementations.

Preview disable stops JPEG generation/upload/hint-driven fetch at the existing
authenticated HTTP edges. Local chooser/thumbnail sampling remains available.
Absent JPEG produces the ordinary share card; it never enables RTP previews.
Only an explicitly selected viewer subscribes remote screen media. Unknown
descriptor versions/enums, wrong scope and stale revisions disable v1 controls;
legacy publication names and media remain readable. Server preview revocation
and terminal cleanup retain their existing contracts.

Native quality uses `screen-quality:v1:<origin>:<account>` preferences, containing
only schema version and existing `P{720|1080|1440}_{15|30|60}` IDs. Restore happens
while idle, never applying an encoder setting. Successful explicit start/update
persists the confirmed profile. Logout/server/account boundaries reject stale
work and reset memory; stored preferences/cookies/identity are not deleted.
Unknown future preference schemas are preserved during rollback to older clients.

## Pilot and rollback procedure

1. Record exact commit, Web image digest, signed native artifact SHA, flag values,
   app/SFU versions, OS/device pair and original profile before pilot admission.
2. Enable one flag per pilot cohort and compare the ADR-018 measurement protocol:
   voice continuity, p05 presented FPS, first frame/profile latency, freezes,
   failure/restart counts and CPU/memory. Existing typed observations may be
   evaluated in shadow; no extra capture, encoder or frame/log upload is allowed.
3. Stop on voice loss, consent/ACL regression, duplicate encoder, subscription
   leak, foreground freezes or inconclusive hardware thresholds. Applied slow
   adaptation and experimental profiles remain disabled without calibration.
4. Disable the relevant flag in a compatible signed forward-fix build or roll
   Web back to its recorded immutable digest. Preserve server/schema/secure
   origin. Do not reinstall/wipe client data or downgrade signing/version IDs.
5. Stop the user's screen explicitly before changing client/Room. Start again
   only by user intent; confirm retained profile, one video subscription, voice
   continuity, JPEG on/off and mixed old/new metadata. Never roll back to RTP
   preview or remove mandatory native fixes.

## Native fork upgrade checklist

Pinned forks remain `livekit_client 2.13.0` (Apache-2.0),
`flutter_webrtc 1.6.2+hotfix.3` (MIT), `flutter_background 1.3.1` (MIT).
Each package's `UPSTREAM.json` pins archive SHA and exact patch inventory;
`LICENSE` and `BOOHTACORD_PATCHES.md` remain distributed with the fork. No SDK
version is changed by this rollout. Upgrade only after comparing the locked
archive/patch inventory, preserving registration/manifest identities, running
fork regression tests + Android Kotlin verification, native signed builds and
affected physical media acceptance. An untested upstream replacement is NO-GO.

Source tests are not a mixed-device pilot or deployment rollback. Releases
#59/#60/#61, physical voice/frames, pilot/load and signed rollback remain NOT_RUN
until their own evidence passes. This runbook authorizes no production mutation.
