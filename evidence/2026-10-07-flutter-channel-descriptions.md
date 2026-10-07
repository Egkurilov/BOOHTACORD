# Flutter channel descriptions — 2026-10-07

## Scope

Implemented parity with the web channel-description feature in the Flutter
client. The existing server/API contract remains the source of truth:
`PATCH /api/v1/admin/channels/{channelID}/description` with an expected
topology revision and a 200 Unicode-code-point limit.

## Evidence

- `GuildChannel` parses and preserves the optional `description` field,
  including through unread-count updates, and rejects malformed or oversized
  topology values.
- The Flutter admin inspector loads the selected description, edits it in a
  two-line field, and saves it with the current topology revision.
- Text-channel headers show the server-authored description and retain the
  existing “Текстовый канал” fallback when it is empty.
- API, model, admin-widget, and workspace tests passed.
- `flutter analyze --no-pub` completed without errors; existing informational
  lint notices remain outside this change.
- Android release APK built successfully: `clients/flutter/build/app/outputs/flutter-apk/app-release.apk` (53.8 MB).
- macOS release app built successfully: `clients/flutter/build/macos/Build/Products/Release/BOOHTACORD.app` (98.9 MB).

## Not run

Physical Android/macOS acceptance of editing a description against the live
server was not run in this change; the implementation is covered by contract
and widget tests.
