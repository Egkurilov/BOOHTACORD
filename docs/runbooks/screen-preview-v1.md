# Private screen-preview delivery v1

The API keeps one transient JPEG per active screen publication in process memory. It is a hint/thumbnail path and never replaces LiveKit's media stream. Web and Flutter upload from their existing local JPEG samplers with one in-flight request and one latest-frame slot; Web and Flutter readers use the private HTTP route after receiving a targeted realtime metadata hint.

## Contract

- `POST /api/v1/voice/leases/{leaseID}/screen-previews/v1` mints a server UUID generation only after the session-bound lease is active and the private LiveKit RoomService confirms that exact `voice-lease:{leaseID}` participant has one active, unmuted `VIDEO/SCREEN_SHARE` publication. The generation is bound to that publication's LiveKit track SID.
- `PUT /api/v1/voice/leases/{leaseID}/screen-previews/v1/{generationID}` accepts raw `image/jpeg` and a positive `X-Screen-Preview-Revision` header. The server rechecks current lease/session and the same LiveKit track SID before accepting the frame.
- `GET /api/v1/voice/screen-previews/v1/leases/{leaseID}/{generationID}?after_revision=N` requires the viewer's own active lease in the same open voice channel, checks the owner and the exact current SFU publication again, and returns only a newer revision. An administrator has no extra access.
- `DELETE /api/v1/voice/leases/{leaseID}/screen-previews/v1/{generationID}` clears only the matching generation. A delayed deletion cannot clear a newer generation.
- `screen_preview.updated` carries only `lease_id`, `generation_id`, and `revision`; `screen_preview.invalidated` carries only lease and generation IDs. The realtime hub targets active voice leases in the same open channel and gates both events behind `screen_previews_v1`. Hints are transient; readers coalesce revisions and poll a known generation every 5 seconds to notice expiration or missed updates.

All methods require the session cookie. Mutations also pass the existing trusted-Origin middleware. Responses use `private, no-store`; image bytes use `image/jpeg` and `X-Content-Type-Options: nosniff`. No URL is signed or public.

## Limits and lifecycle

- At most 14 KiB per JPEG; maximum 160x320 pixels and 51,200 decoded pixels; the full JPEG container and decoded image are validated before storage.
- At most one accepted upload every 4 seconds per publication generation; at most 32 in-flight preview API operations.
- One current generation per voice lease; at most 256 cached generations, bounding image bytes to 3.5 MiB before map/timer overhead.
- Preview bytes expire 15 seconds after generation creation or the last accepted upload. New generations replace old ones. Process shutdown zeroes and clears the cache; restart begins empty.
- Flutter sender generation is tied to the current voice lease. Screen stop/unpublish and lease changes clear queued bytes and invalidate the exact old generation; an upload already in flight cannot publish after server invalidation.
- A revoked lease is denied by the database check immediately. The corresponding bytes are removed on explicit invalidation, a subsequent failed publisher/read check, or when the 15-second timer expires. Readers clear cards when access expires. Pixels already captured by the operating system or copied by a viewer cannot be remotely erased.
- If the database or private RoomService is unavailable, access fails closed. Clients should show their existing fallback and must not retry continuously.

The current in-memory store assumes the repository's single API process deployment. A multi-process API rollout needs a separately reviewed ephemeral store that preserves per-request database ACL, exact publication-generation binding, and bounded TTL; do not substitute Redis or object storage by default.

## Evidence status

- Unit, authorization query, JPEG parser, cache, HTTP, Web latest-wins and realtime capability tests: recorded in `evidence/screen-preview-v1.md`.
- Real PostgreSQL plus LiveKit end-to-end integration: NOT_RUN.
- Browser/Flutter device-level capture, visible-card QA, late callback cleanup and RTP subscription-count acceptance: NOT_RUN. Code sends no preview video subscription; automated device/network proof remains uncollected.
- 20-publisher load, Android/desktop devices, multi-process behavior and production revoke timing: NOT_RUN.

Do not attach real user frames, track identifiers, session tokens or DM content to diagnostics. Exercise test paths only with synthetic JPEG fixtures and aggregate status counts.
