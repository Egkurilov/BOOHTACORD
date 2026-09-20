# Mobile Client Backend Contract

**Status:** integration contract for the current backend. It does not authorize a mobile application implementation, add a bearer-token flow, or change the one-guild product boundary.

## Canonical sources

- HTTP request and response schemas: [`openapi.yaml`](./openapi.yaml) (OpenAPI 3.1 JSON document despite the extension).
- Realtime event schemas: [`realtime.schema.json`](./realtime.schema.json).
- Operational and media behaviour: [`../docs/API_AND_REALTIME.md`](../docs/API_AND_REALTIME.md).

Generate REST models from `openapi.yaml`; this document explains the mobile lifecycle and must not be treated as a duplicate schema authority. All identifiers are UUID strings, timestamps are RFC 3339 `date-time` strings, and request schemas reject additional properties unless their canonical schema says otherwise.

## Transport and versioning

- Base URL: `https://<public-host>`; all documented routes start with `/api/v1`.
- Use HTTPS and validate the public host certificate. Private PostgreSQL, storage, LiveKit management, metrics, and `/internal/*` routes are not mobile APIs.
- Send JSON as `application/json` except attachment upload, whose exact multipart request is defined in the canonical OpenAPI operation `uploadTextAttachment`.
- Treat a missing or changed field as a contract change. Pin generated clients to a reviewed `openapi.yaml` revision and preserve unknown realtime events for forward compatibility.

## Authentication and session ownership

The current API uses opaque server-side sessions issued as secure cookies. There is **no bearer-token, OAuth, device-code, or API-key contract** for mobile clients.

1. Call `POST /api/v1/auth/register` only while registration is admitted, or `POST /api/v1/auth/login` with the canonical request body.
2. Store the returned session cookie only in the platform-managed secure cookie store for the public host. Never persist a password, reset token, LiveKit token, or a token in a WebSocket URL.
3. Bootstrap each app launch with `GET /api/v1/auth/session`; treat `401` as signed out and clear the platform cookie store on `POST /api/v1/auth/logout`.
4. Every state-changing request must satisfy the production secure-cookie, CSRF, and Origin checks. Native-origin/header behaviour is not separately specified by the current backend: do not bypass these checks or invent a header. Mobile implementation is blocked on an explicit backend auth-transport decision if a platform cannot meet them.

`GET /api/v1/auth/session` returns only the current account identity and role. Do not infer another user's role, blocked state, password state, session state, or direct-message membership from errors or absent fields.

## REST operation map

Use the named `operationId` from OpenAPI for generated client methods. All protected routes enforce server-side ACL; an identifier or a cached screen never grants access.

| Area | Operations for a mobile client | Notes |
| --- | --- | --- |
| Bootstrap | `getHealth`, `getMaintenanceAdmission`, `getCurrentSession` | `maintenance.active` controls new admissions only; it is metadata, not a deployment schedule. |
| Authentication | `register`, `login`, `logout`, `completePasswordReset` | Password-reset links are administrator-operated; clients never create a reset link for themselves. |
| Channels | `getChannelTopology` | The deployment is exactly one guild. Use `revision` when performing administrator topology mutations. |
| Text messages | `listTextMessages`, `createTextMessage`, `searchTextMessages`, `editTextMessage`, `deleteTextMessage` | History and search are newest-first cursor pages. Deleted rows retain identity and marker but not former text. |
| Attachments | `uploadTextAttachment`, `downloadTextAttachment`, `previewTextAttachment` | Use only the caller-authorized channel paths; attachment IDs do not bypass ACL. Bind uploaded attachment IDs in `createTextMessage` as specified by OpenAPI. |
| Direct messages | `listDirectMessageCandidates`, `openDirectMessage`, `listDirectMessages`, `listDirectMessageHistory`, `searchDirectMessageHistory`, `sendDirectMessage`, `editDirectMessage`, `deleteDirectMessage`, `advanceDirectMessageReadCursor` | A direct message belongs only to its two participants. Administrator role gives no access to a third party’s history. |
| Voice and media | `acquireVoiceLease`, `releaseVoiceLease`, `issueLiveKitCredential` | Use the ordered lifecycle below; these are not generic LiveKit management APIs. |
| Administration | `createCategory`, `createChannel`, `reorderCategories`, `renameCategory`, `deleteEmptyCategory`, `moveChannel`, `reorderChannels`, `archiveTextChannel`, `closeVoiceChannelAdmission`, `updateAdminAccountState`, `kickVoiceParticipant`, `createPasswordResetLink` | Render or call only after `getCurrentSession` reports `ADMINISTRATOR`; still handle an authorization failure. |

For every endpoint, use the exact request/response schemas and documented status codes in `openapi.yaml`. Do not create mobile-only routes or fields.

## Message, cursor, and conflict rules

- Generate a UUID `client_message_id` once for each new text or direct message. Reuse it for retries of that same logical send; do not generate another value after an uncertain network outcome.
- Send text bodies within the canonical `1…8000` bounds. A reply ID must stay in the same text channel or the same direct-message pair.
- Use `before` and `next_cursor` for history/search paging. `limit` is bounded to `1…100` with default `50` where defined.
- Edit with the latest `expected_revision`. On `409`, refresh the affected history row/page before offering retry; never overwrite a newer revision locally.
- Delete is a soft deletion. Clear local display text when the server returns a deletion marker; do not retain a deleted remote body in persistent mobile caches.
- Advance a DM read cursor only for a message visibly rendered in the selected, foreground conversation. The server moves it monotonically; a retry cannot move the cursor backwards.

## Realtime contract

Open a same-origin WebSocket at `GET /api/v1/realtime` only after the cookie session is established. The cookie authenticates the upgrade; never add an authentication token to its URL, query, log, or event payload.

The supported `kind` values are defined by `realtime.schema.json`:

| Event kind | Mobile action |
| --- | --- |
| `connection.ready` | Mark the realtime transport ready after validating the event schema. |
| `connection.resync_required` | Refresh protected topology and the actively visible history through REST; do not claim replay succeeded. |
| `voice.lease_revoked` | Stop the related voice lifecycle locally and require an explicit user action to join again. |
| `channel.updated` | Refresh the caller-authorized topology. |
| `message.created` | Refresh or merge only if the event’s authorized conversation is currently cached. |

Deduplicate by `event_id`, order using `occurred_at` only as server event time, and accept future event kinds without treating them as authorization. A realtime reconnect does not establish a new session, a new voice lease, or a new LiveKit credential. A healthy WebRTC call must not be closed solely because this WebSocket reconnects.

## Voice lease and LiveKit credential lifecycle

1. Call `POST /api/v1/voice/channels/{channelID}/leases` with `{"transfer": false}` for a user-selected, readable `VOICE` channel.
2. If the server returns `409 ACTIVE_VOICE_LEASE`, display that another logical voice connection exists. Transfer only after explicit user intent by retrying with `{"transfer": true}`.
3. With the returned lease ID, call `POST /api/v1/voice/leases/{leaseID}/credential` immediately before joining LiveKit.
4. Use the returned `url`, short-lived `token`, and `expires_at` only in the in-memory LiveKit client. The **LiveKit credential** must never be logged, persisted, embedded in a deep link, or sent to analytics.
5. Join only the room authorized by that credential. The backend, not the mobile client, owns channel admission, ban/logout checks, credential signing, and SFU revocation.
6. On explicit leave, call `DELETE /api/v1/voice/leases/{leaseID}`; this operation is idempotent. On kick, logout, session invalidation, or a terminal SDK disconnect, stop local media and obtain a new lease only after explicit user action.

The mobile client may publish microphone and screen-share media only if the issued credential permits it. Camera, recording, custom SFU, group DM, cross-guild voice, and public LiveKit management are unsupported.

## Error and retry policy

- Parse the canonical `Error` response without exposing its content to analytics or logs when it could reveal user-controlled data.
- `400`: correct the local request; do not blind-retry.
- `401`: clear protected local state and begin the normal sign-in flow.
- `403`/`404`: remove or refresh the inaccessible resource; do not distinguish hidden ACL conditions to the user beyond the server-safe message.
- `409`: follow the resource-specific flow above (`ACTIVE_VOICE_LEASE`, stale revision, or topology revision) and refresh before retrying.
- `429`: honor `Retry-After` when present; do not fan out retries.
- `5xx` or transport loss: retry only idempotent reads and requests carrying the original message idempotency key; apply exponential backoff with cancellation on logout/background.

## Unsupported or intentionally absent contracts

- No native bearer/mobile auth transport is currently specified.
- No push-notification, presence, typing, user-profile, global user search, server discovery, federation, or cross-deployment API exists.
- No camera, recording, group-DM, mobile UI, backup, snapshot, or custom-SFU capability is implied by this document.
- No mobile telemetry may include passwords, sessions, reset/media tokens, message bodies, attachment contents, or high-cardinality account/DM identifiers.

## Change policy

Mobile implementation must consume a reviewed OpenAPI/JSON Schema revision. Any change to endpoint method/path, required field, enum, authentication transport, ACL outcome, websocket event, LiveKit credential claim, or error semantics requires a matching change to the canonical contracts, this guide, the contract verifier, and release notes.
