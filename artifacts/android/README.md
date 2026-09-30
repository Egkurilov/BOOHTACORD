# Android release downloads

APK binaries are not stored in this repository. Existing signed ABI-specific
APKs remain in the historical [BOOHTACORD Android v1.0.3 GitVerse release](https://gitverse.ru/egkurilov/BOOHTACORD/releases/tag/android-v1.0.3). Future releases use GitHub Releases:

- `arm64-v8a` — most modern Android phones and tablets
- `armeabi-v7a` — older 32-bit ARM devices
- `x86_64` — Android emulators and x86-64 devices

The previous universal APK was 107,654,946 bytes. Its build and signing
details remain in [QA-98](../../evidence/flutter/qa98-windows-screen-capture-start-failure-2026-09-29-001.json). The GitHub migration removes historical `artifacts/android/*.apk` blobs from Git history because they exceed GitHub's 100 MiB Git-object limit; the original history remains in GitVerse.
