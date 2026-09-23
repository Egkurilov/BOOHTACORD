# Voice Platform — local operating rules

## Source of truth

`C:\Users\egkur\Downloads\TZ_Voice_Platform_v1.0.md` is the approved product brief. Its `[U]` and `[S]` statements take precedence over implementation choices. `[D]` decisions are binding until a documented ADR changes them. `[V]` items remain unproven until an evidence record says `PASS`.

## Product invariants

- A deployment is exactly one guild. Do not add global users, federation, server discovery or cross-deployment communication.
- The browser client is Vue 3/TypeScript/Vite/Pinia with LiveKit Client. The API is Go with PostgreSQL and WebSocket. LiveKit transports media; Go must not proxy RTP/RTCP or media payloads.
- Every resource operation has server-side ACL. IDs, unguessable paths and a client-side view do not grant access.
- A DM belongs only to its two participants; administrator status never grants DM reading rights.
- Never add a backup job, snapshot flow, `pg_dump`, public object store, Redis by default, `latest` production image, camera feature, recording, group DM or custom SFU. The approved Android client must follow ADR-006 and reuse the existing server-side ACL and secure-cookie contract.
- Do not claim a media capability or capacity profile without hardware/load evidence in `evidence/`.

## Engineering workflow

1. Select one leaf task in `backlog/tasks.yaml`, read its dependencies and tests, and preserve existing behavior.
2. Write or update focused tests before the implementation. Keep files responsibility-focused and do not place executable behavior under an aggregate directory.
3. Run the nearest native test plus `scripts/verify-spec-traceability.ps1` when requirements or backlog change, and `scripts/verify-contracts.ps1` when contracts change.
4. Add an evidence record for POC, integration, load and release-gate work. `NOT_RUN` and `BLOCKED` are valid outcomes, but cannot close a gate.
5. Before staging, inspect `git status --short` and the changed file sizes. Never stage generated media, secrets, `.env`, database volumes or the entire root blindly.

## Security

Do not log passwords, session/reset/media tokens, DM bodies, message text, attachment contents or high-cardinality usernames/DM IDs. Production mutations require secure session cookies and CSRF/Origin validation. Keep PostgreSQL, storage and LiveKit management interfaces private.
