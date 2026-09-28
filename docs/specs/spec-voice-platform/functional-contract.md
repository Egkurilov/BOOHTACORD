# Функциональный контракт и границы реализации

## Канонические интерфейсы

| Interface | Authority | Consumer rule |
| --- | --- | --- |
| HTTP | [`contracts/openapi.yaml`](../../../contracts/openapi.yaml) | Generate and validate request/response models from OpenAPI 3.1. Do not copy field schemas into UI documentation. |
| Realtime | [`contracts/realtime.schema.json`](../../../contracts/realtime.schema.json) | Validate event envelope and tolerate future event kinds. |
| Behaviour | [`docs/API_AND_REALTIME.md`](../../API_AND_REALTIME.md) | Apply session, ACL, retry, media and error semantics that schemas cannot express alone. |
| Mobile integration | [`contracts/mobile-client-contract.md`](../../../contracts/mobile-client-contract.md) | Android product scope is approved by ADR-006; the contract grants no bearer flow. |

All public REST routes are under `/api/v1`; JSON errors use `{ error: { code, message, request_id } }`. User-facing messages are Russian; error codes are stable ASCII. IDs are UUIDs and timestamps are RFC 3339 values where schemas declare them.

## Capability matrix

| Domain | Current contractual behaviour | Explicit limit / evidence boundary |
| --- | --- | --- |
| Account and session | Registration, login, logout, current-session bootstrap, reset completion, administrator reset-link creation, caller-only profile/avatar/password updates and secure opaque sessions are specified. | Registration remains unavailable before first owner bootstrap; profile reads and avatar bytes require a current session, and password change revokes other sessions while retaining the caller's current session. |
| Owner and administration | Owner-operated bootstrap/recovery avoids password CLI arguments. Administrators manage account state, password-reset links, topology, archive/close-admission and voice kick. | Account roster/full management UI and production concurrency/e2e proof remain separate work. |
| Channel topology | Categories and `TEXT`/`VOICE` channels are ordered under one revision; creation, rename, move, reorder, text archive and close voice admission are distinct operations. | A channel kind cannot change. Archiving a text channel does not claim media disconnection; closing voice admission requires POC-03 for SFU enforcement. |
| Text chat | Text history, create, edit, soft delete, replies, cursor pages and current-channel search are server-scoped and idempotent/conflict-aware. Topology includes caller-local unread counts and optional first live unread message ID. | Realtime publication/replay and complete browser integration remain gated by focused tests/evidence. |
| Direct messages | Exactly one canonical pair for two active accounts; pair-only history/search/edit/delete and monotonic caller-local read cursor/unread count with optional first live unread message ID. | No group DM, no administrator bypass and no leakage through navigation/counters/notifications. Full privacy regression coverage remains release work. |
| Attachments | TEXT and DM multipart uploads share the 25,000,000-byte cap, private staging, scoped owner/conversation binding, protected download and safe PNG image preview. A message may contain attachments with an empty body; an empty message without an attachment is rejected. | DM access is restricted to its two active participants without administrator bypass. Bounded physical collection exists, while operator scheduling and live capacity acceptance remain separate work. Published history is never TTL-cleaned. |
| Realtime | Same-origin authenticated WebSocket supports `connection.ready`, `connection.resync_required`, private DM hints, `voice.lease_revoked`, `channel.updated`, `message.created` and authorized durable replay with `after=<event_id>`. | The journal retains seven days and returns at most 512 events per reconnect; each replayed event is rechecked against current ACL. Invalid, expired, cross-epoch or unavailable replay requires REST resync. WebSocket health is independent from a healthy WebRTC call. |
| Voice | Lease → short-lived room credential → LiveKit connection; explicit transfer, leave, mute/deafen, device/audio preferences and bounded reconnect policy are defined. | POC-03 must prove live media disconnect and old-token replay denial; UI state does not prove SFU enforcement. |
| Screen sharing | Explicit browser picker, screen and optional screen-audio tracks, selected-stream-only subscription, remote participant cards and diagnostic state are defined. | POC-01/02 must prove real game audio, two operating systems, FPS/quality and lack of digital loop. |
| Desktop interface | Russian one-guild shell includes auth, navigation, chats/DM, voice dock, participant cards, viewer and audio settings with empty/loading/error/reconnect states. | Authenticated screenshot parity, full accessibility sweep and real device/browser E2E evidence remain required. |
| Operations | Compose has separate migration, maintenance admission, private metrics, network separation and log rotation. ADR-010 designates GitVerse `master` as the sole production delivery route. | Trusted GitVerse run #1653749 proved digest-pinned API/web deployment with retained SBOM/provenance and health; live rollback QA-12 and overall release gate QA-14 remain open. |

## Required user flows

### Visitor and member

1. A visitor sees a landing/auth surface. `GET /health` and `GET /maintenance` are public metadata; protected resources remain `401` without a session.
2. Registration and login are accepted only while maintenance and bootstrap rules allow them. Login returns no token JSON; it sets a secure HTTP-only cookie.
3. The client calls `GET /auth/session`, then reads the authorised topology and history. It cannot infer rights from stale client data.
4. To send a message, the client creates one UUID `client_message_id` and reuses it only for an uncertain retry. To edit, it uses the latest message revision; `409` means refresh before a new explicit edit.
5. To start a DM, the client selects a candidate then calls the canonical open-DM command. It advances a read cursor only for a visibly selected foreground message.

### Administrator

1. The first administrator is created only by the protected bootstrap command. Later bootstrap calls do not change a password or role.
2. Admin changes submit the full desired account state and must preserve at least one active administrator.
3. Topology mutations carry the current revision. A conflict causes refresh, never a client-side blind overwrite.
4. Text channel archival requires explicit confirmation. A voice channel uses close-admission instead; its API response counts logical leases, not asserted physical disconnects.

### Voice and screen participant

1. On an explicit join action, the client acquires a voice lease. A second active lease results in a visible transfer decision.
2. The client obtains a credential immediately before LiveKit join and keeps token/url only in memory.
3. Microphone and screen permissions are requested only from user actions. Permission denial can leave a listener connected where the SDK allows it.
4. The viewer subscribes to only one chosen remote screen source; remote room voice remains separately attached. Deafen mutes local playout and local microphone without stopping a local screen share.
5. On explicit leave, terminal disconnect, kick or session loss, client media stops and a new join requires explicit action.

## Compatibility, error and retry rules

- A client does not create a duplicate side effect after transport loss. It retries reads safely and creation only with the same documented idempotency key.
- `401` clears protected client state; `403`/`404` do not disclose hidden ACL conditions; `409` requires resource-specific refresh; `429` honours `Retry-After`.
- A valid same-epoch WebSocket cursor may replay only currently authorized durable hints. A malformed, expired or cross-epoch cursor leads to authorised REST refresh; `event_id` is the deduplication key.
- API, logging, UI and telemetry never expose passwords, opaque sessions, reset secrets, LiveKit credentials, message/DM bodies or attachment contents.

## Desktop acceptance contract

The product targets a desktop-first dark Russian UI at 1024 CSS px minimum and 1440 CSS px primary, both at 125% and 150% zoom. Keyboard focus, accessible labels, readable contrast and non-colour state indicators are required. Visual review evaluates documented layout and states, not a promise of Discord pixel identity.

## Mobile integration boundary

The Android Flutter app is part of this release under ADR-006. It persists the opaque cookie in encrypted platform storage and sends the deployment Origin required by the existing cookie/CSRF boundary. It must not invent bearer/OAuth/device authentication. iOS and push notifications remain outside this release.
