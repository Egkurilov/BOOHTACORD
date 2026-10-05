# Android APK download size

Published signed 1.0.33+66 verification PASS: arm64 19,831,683 bytes (-51.84% from
published 1.0.32), armv7 17,644,771 bytes and x64 21,188,113 bytes. All three actual
downloads pass checksum, unchanged signer, version, ABI, ZIP compression and
64-bit ELF alignment checks. See [release evidence](critical-five-release-2026-10-05.md).
Device installation/loading remains NOT_RUN; the table below records the earlier
local measurement and must not be confused with the signed published binaries.

Status: PASS for packaging/build/size checks; device loading NOT_RUN.
Base: dcef7fe4, published Android 1.0.32+46. Application/signing identity and
ABI versionCode rules are unchanged. Measurement binaries were release-mode
with the public Android debug signer; they were not published or installed.

## Before and after (actual bytes)

| Architecture | Published 1.0.32 | Compressed measurement |
| --- | ---: | ---: |
| armv7 | 32,649,222 | 17,563,222 |
| arm64 | 41,176,490 | 19,754,622 |
| x64 | 47,012,640 | 21,105,312 |

Arm64 download reduction: 52.02%. Actual ZIP native payloads are DEFLATED.
The same 14 arm64 library names are retained; ten binary hashes are identical
to the published package. Remaining host-built binaries are not claimed identical.
All native PT_LOAD alignments are at least 16 KB for arm64/x64. Armv7 retains
its existing 4 KB alignment; no physical 16 KB device acceptance is claimed.
The local debug universal APK was 221,587,648 bytes, not a release distribution.

## Source behavior and checks

Gradle jniLibs.useLegacyPackaging compresses native libraries. ABI splits,
codecs, LiveKit, RNNoise, Flutter assets and account/media behavior are retained.
Android extracts these libraries on installation: download size decreases,
while installation footprint can increase. Installed disk usage is NOT_RUN.
[Android packaging guidance](https://developer.android.com/guide/practices/page-sizes)
documents this extraction tradeoff; no unsupported runtime-loader replacement.

The publisher inventories actual APK and native bytes, rejects debug kernel
assets/mixed ABI/raw native payloads, and enforces release budgets of 25/30/35 MB
for armv7/arm64/x64. Manifest signing metadata retains the inventory. Actual
production signer verification still runs independently and rejects debug signers.

Behavior baseline: six failing packaging/budget subcases, three passing checks.
After implementation: fourteen packaging/signature unit tests PASS.
Pinned Flutter 3.47.5 release build produced all three APKs: PASS.
Actual ZIP inventories, hashes and structural alignment checks: PASS.
No Android device or emulator image was available; device loading remains NOT_RUN.

Commands: python -m unittest tools.build.android.apk_size.test_inspect
tools.build.android.test_signature -q; Flutter release/split-per-abi measurement.
Machine before/after proof: .out/checks/next-five-intake/apk-size-comparison.json.
Signed publication will use a new immutable release after integrated native gates.
