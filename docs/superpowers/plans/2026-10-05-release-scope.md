# Release scope 2026-10-05

## Operating brief

Owner authorized integration, full checks, repairs, production deployment,
Android/Windows publication, and closure of implemented issues.
Packets: branch_sync, focused implementation, review_gate, delivery,
issue acceptance. Preserve ACL, messages, media ownership and signing identity.
Canonical GitHub sources are authoritative under ADR-011.

## Plan

1. Fetch all remotes and inventory ancestry. Merge the current FPS branch;
   retain retired pre-migration histories locally: GitHub rejects historical
   APK blobs exceeding 100 MB. Every active GitHub branch must be an ancestor
   of integration HEAD; canonical migrated sources remain authoritative.
2. Repair failing checks in the exact audio_diagnostics and shortcuts leaves.
   Baseline: Web receiver union fails typecheck; Flutter object-key const map
   fails compilation. Add a receiver regression; retain existing key tests.
3. Include voice-shortcut Playwright tests in the native web gate. Advance
   client identities and Flutter version to 1.0.30+44 without changing channels.
4. Run focused Web and Flutter checks, full native Flutter tests and analysis,
   and the full GitHub CI dispatch on the committed integration SHA.
   CI supplies disposable PostgreSQL, Docker audio fixtures, native DSP CTest,
   Kotlin and Windows.
   Repair failures and repeat affected checks plus the complete final gate.
5. Merge validated integration into master. Observe Build server and production
   installation for that revision; verify immutable release provenance/health.
6. Publish new android-v1.0.30 and windows-v1.0.30 tags only after quality passes.
   Verify manifests, assets, checksums and signing continuity. Promote catalog
   only after artifacts exist, using the existing delivery entrypoint.
7. Audit issue acceptance against source and check evidence. Close implemented
   issues only; leave partial UI work and unproven physical media acceptance open.

## Native commands

- Web: npm test; npx vue-tsc --noEmit; npm run test:voice-shortcuts.
- Flutter: python -m tools.ci.native.flutter (pinned Flutter on PATH).
- Full gate: GitHub CI workflow_dispatch on committed integration revision.
- Delivery: canonical Build server / Deploy production / native release workflows.

## Completion evidence

Record tested SHA, results, workflow URLs, deployed SHA and published identities
in evidence. No skipped tests or compilation result proves physical media.
Inspect status and candidate sizes before explicitly staging source files.

## APK identity correction after publication

The immutable 1.0.30 APKs expose actual version codes 1044/2044/4044;
Flutter offsets the logical native build 44 by the split ABI. The evaluator
incorrectly reported identity_conflict. Baseline: six failing evaluator cases
and five failing publisher rejection cases. Preserve exact universal/Windows
identity and reject unknown ABI, wrong base and malformed codes.

Publish corrected 1.0.31+45 after the complete gate, retaining 1.0.30 assets.
Inspect actual APK native-code/versionCode before publication. Promote only
r45 after verified artifacts exist; record this correction in final evidence.
