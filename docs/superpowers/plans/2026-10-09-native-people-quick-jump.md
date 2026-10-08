# Native guild people quick jump (#78) — 2026-10-09

Route: small_direct; source ownership = workspace/quick_jump child load, selection and rendering leaves, existing direct candidate API, and converted native search toolbar.

Approved: keep BOOHTACORD identity, show configured one-guild name, separate channels/people from message search, avoid VoiceJoin. Preserve current Ctrl/Cmd+K field protection, search state, focus restoration and ACL boundaries.

- Add failing focused candidate page, dedup/selection/session and actual-widget tests.
- Expose a paged candidate request without changing the existing drain-all facade.
- Load only existing server-authorized candidate pages on explicit navigation mode; retain pagination failure/retry and account/disposal guards.
- Revalidate topology and existing DM access before navigation; candidate selection uses existing authenticated DM POST then authoritative refresh; never join voice.
- Connect bounded real widgets to the existing search header; preserve message mode and IME composition.
- Verify narrow tests, all79 workspace preservation cases, native notifications, analyzer and source sizes; commit locally only.

Limits:100 target/120 hard source lines, leaf8 target/16 hard. Stop: source/component evidence PASS; hardware accessibility and production revocation remain explicit QA.
