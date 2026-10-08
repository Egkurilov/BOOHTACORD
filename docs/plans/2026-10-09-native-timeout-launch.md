# Native timeout launch integration

Packet: small_direct. Route: actual AdminScreen member actions -> admin_ui/voice_timeout -> admin_voice_timeout/dialog -> existing authorized ApiClient.

Baseline: API, dialog and session-boundary tests pass; actual compact/desktop AdminScreen launch tests are red because member actions have no timeout entry. Existing admin preservation tests remain the behavior baseline.

1. Add compact and desktop member actions calling the existing timeout dialog with the current AppState scope notifier. Do not join voice or change microphone/media ownership.
2. Reuse the shared explicit confirmation route for Escape, focus return, closed-loop traversal and reduced motion; preserve reactive timeout confirmation privacy and mutation guards.
3. Verify actual AdminScreen launches at 390/1440, ordinary Escape/focus return, cancellation without mutation, existing timeout/privacy checks and nearest admin regressions. Keep new production files within 120 lines.

Stop: green actual launch and native regression checks, explicit source/evidence commit. Physical screen readers, deployed revocation and released-client acceptance remain QA.
