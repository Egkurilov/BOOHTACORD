# Voice and stream experience

## Goal

Implement the six requested voice and screen sharing behaviors in the web client and the shared Flutter client used by Android and iOS.

## Route and boundaries

- Slavik Gym: `split_first`; packets T-022 voice admission/roster and T-030 screen publication/viewing.
- Preserve voice ACL, single selected remote stream subscription, and existing audio behavior.
- Work through native entrypoints in `frontend/src/voice`, `frontend/src/channel`, `frontend/src/workspace`, `desktop/lib/src/app_state.dart`, and `desktop/lib/src/screens/workspace_screen.dart`.
- Target files <=100 lines, hard <=120 lines for new leaf files; avoid adding mixed responsibilities to existing large files.

## Steps

1. Add focused failing tests for empty counts, immediate transfer, live participant presentation, stream lifecycle, and mutable screen profile.
2. Implement web roster and voice behavior, using LiveKit events for the connected room and a bounded realtime mechanism for other rooms.
3. Implement Flutter voice behavior in the shared app, then stream lifecycle, thumbnail, and live profile update.
4. Run focused and full native tests, web build, Flutter analyzer and available platform builds. Record device limitations accurately.
5. Inspect changed files, status, and diff before commit; commit on `codex/voice-stream-experience`.

## Stop condition

All six behaviors have code and relevant tests on web and the shared Android/iOS Flutter path; any native platform verification gap is documented.
