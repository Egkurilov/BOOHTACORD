# Architecture and data boundaries

## Components

The Vue client uses HTTPS REST for commands and a single authenticated WebSocket for state updates. The Go API is a modular monolith owning authentication, authorization, channels, messages, attachments, voice leases and LiveKit credential issuance. LiveKit transports WebRTC media only. PostgreSQL owns relational state; a private local volume owns attachment bytes; a reverse proxy terminates TLS. TURN is added only after an ADR and network measurement.

`cmd/migrate` is a separate deployment step and runs before `cmd/api`; the API never applies schema changes during start-up. The current versioned migrations create `users`, digest-only `sessions`, their active-session index, digest-only `password_resets`, immutable `bootstrap_state`, metadata-only `audit_events`, revisioned channel topology state, categories, channels, revocable `voice_leases` with active-user/channel indexes, and a singleton `maintenance_admission` state, with one DDL statement per migration file. Future non-idempotent schema changes require a versioned migration receipt and rollback-compatibility review; automatic down migrations remain prohibited.

## Isolation and access

There is one logical guild per deployment. `users`, `sessions`, `categories`, `channels`, `messages`, `direct_messages`, `direct_message_messages`, `direct_message_read_cursors`, `attachments`, `voice_leases`, `password_resets` and `audit_events` belong to it without a guild selector. Every command must derive its actor from a current server-side session and enforce active/not-banned status and resource ACL in its transaction; concurrency acceptance remains separate verification work.

Common channels are available to every active user. `direct_messages` stores exactly two ordered UUID participants (`participant_one_id`, `participant_two_id`) with a unique-pair constraint; no administrator bypass is permitted. Text-channel archive preserves data. Soft delete hides body/attachment links immediately; physical collection without live references is still pending BE-12 in `backlog/BACKEND_TODO.md`.

## Critical state machines

`session`: active → revoked. The raw opaque cookie token is returned once; only its SHA-256 digest is persisted. Logout, reset-password, administrator recovery and ban revoke relevant sessions; every API and WebSocket command rechecks state.

`voice_lease`: absent → active → revoked. A user has at most one active lease, and every lease retains its issuing server-side session digest. A transfer revokes the former lease before issuing the new credential; voluntary leave may revoke only the lease of its issuing session. Kick revokes the current lease but does not ban future join; ban, logout, channel deletion and session revocation prevent re-admission.

`maintenance_admission`: open ↔ active. A server-local operator command changes only this singleton boolean. When active, the API rejects registration, login, new logical voice leases and private LiveKit signal admission, while health, logout, protected reads, existing media and private SFU-removal work continue. No actor, password, session or media credential is stored in this state.

`attachment`: uploading → unattached → attached → hidden → collected. Upload bytes are streamed to a random temporary name after atomic space reservation. Only incomplete uploads older than one hour and unattached items older than 24 hours may be cleaned automatically; published history has no TTL.

The `write_upload` leaf creates a random private `.part` file, streams at most
25,000,000 bytes, fsyncs accepted bytes and removes it after read/write/limit/context
failure. The connected pipeline performs reservation, ACL and metadata finalization
before a later message can link the attachment.

`reserve_upload_space` is the current in-process admission ledger: before a
stream starts, it reserves the full 25,000,000-byte maximum against a supplied
filesystem snapshot while preserving the larger of 2 GiB and 10% of that
filesystem. Reservations are serialised and released after finalisation or
cleanup; they do not trust `Content-Length`, evict history or coordinate across
processes. The Linux `Filesystem` adapter samples the configured private path
with `statfs`, using `Bavail` rather than `Bfree` so blocks unavailable to the
API user are not admitted. `cmd/api/storage_routes.go` connects this adapter,
ledger and writer to the TEXT upload endpoint; real storage/DB acceptance remains QA-03.

`stage_upload` now composes the private writer and reservation ledger: it takes
the maximum reservation before accepting a source, confirms current capacity
before every source read, deletes a temporary file on a failed confirmation and
releases the reservation on every result path. The snapshot is still not a
cross-process lock, and the staging leaf itself does not create metadata, grant
ACL, attach a message or expose an upload route.

The `attachments` schema records owner, measured byte count, original filename
and random private `storage_key`. Each row targets exactly one channel or DM;
states are `UNATTACHED`, `ATTACHED` and `HIDDEN`. A row does not grant access
and never supplies a public URL.

Before accepting bytes for a text-channel target, `authorize_text_attachment`
checks in PostgreSQL that the caller remains non-blocked and the target remains
an unarchived `TEXT` channel. This preflight has no role bypass and does not
replace the same server-side predicate in the later metadata insert, which is
required after staging completes.

`finalize_staged_text_attachment` accepts only a regular file physically below
the configured private staging directory and moves it with `os.Rename` to the
same private-volume unattached directory under a newly generated UUID key. It
then inserts an `UNATTACHED` metadata row through a CTE that repeats the
active-owner, `TEXT`, and non-archived predicate. If the insert returns an
error, the final object is removed. A process crash may leave an unreferenced
private candidate, but it is neither downloadable nor visible in history and
is eligible only for the permitted 24-hour unattached-object cleanup.

`message_attachments` is the text-message-only relation used by the
text-message create command. Its unique attachment key prevents the same object
from being linked to another message, and its per-message ordinal is constrained
to zero through nine. For a new message, one CTE locks and validates every
requested attachment as owned by the author, targeted to that channel, and
`UNATTACHED`, then creates all links and updates all of their states to
`ATTACHED`. A missing, duplicated, wrong-channel, unowned, or already-attached
ID rejects the entire new-message path without a partial link. Idempotent retry
returns the existing message without changing its links. The relation does not
grant download rights or bypass the later download ACL.

`POST /api/v1/channels/{channelID}/attachments` is the current text-channel
ingress: it accepts one streamed multipart `file`, applies a dedicated rate
limit, reserves and rechecks private-volume capacity, and returns only the
unattached attachment metadata. The API creates `staging` and `unattached`
siblings under `ATTACHMENTS_DIRECTORY`; neither directory nor a storage key is
published. There is intentionally no DM upload path in this stage.

`GET /api/v1/channels/{channelID}/attachments/{attachmentID}` re-authorizes
each text attachment read with one PostgreSQL predicate: its caller remains
active, the channel remains unarchived `TEXT`, the attachment remains
`ATTACHED`, and it is linked to a non-deleted message in that same channel.
Only then does the server open the UUID-keyed private object and verify its
stored byte count. The response is `application/octet-stream` with
`Content-Disposition: attachment` and `X-Content-Type-Options: nosniff`; it
does not expose an inline active format, filesystem path, storage key, or
public URL. A separate protected TEXT preview route already normalizes bounded
raster images into PNG. DM access and physical collection remain BE-10/12.

Text-message history aggregates only the attached files of each non-deleted
message, in their stored message position order. Its metadata projection is
limited to attachment ID, original filename and measured byte size; it never
contains a storage key, local path, content type or public URL. A client must
still invoke the protected download endpoint, which repeats the current ACL;
the history projection is not a capability. Deleted messages always project an
empty attachment list even before the later physical collection leaf runs.

## Media admission

The API issues a one-minute, room-scoped credential only for an active voice lease and rechecks lease, issuing session, channel state and user state before signing. The token identity is the lease rather than a room-admin capability; browser clients receive no LiveKit room-admin credential. Every lease-revocation transaction inserts lease and channel IDs into the metadata-only `voice_sfu_revocations` outbox. The API worker uses a private RoomService credential to remove that lease identity from its room, and retries a durable pending row after an unavailable SFU result.

Caddy calls a private API admission endpoint before forwarding every `/rtc` signal connection or reconnect. The endpoint verifies the LiveKit JWT and a current lease/session/channel/account predicate in PostgreSQL, so a revoked API or refreshed SDK token cannot regain admission merely by reconnecting. The proxy retains RoomService on the private network; Go never proxies RTP, RTCP or media payloads. Revocation must still be proven against already-issued API and SDK tokens by POC-03; a successful HTTP command, outbox row or fresh credential lookup alone is not evidence.

`/metrics` remains private: the durable SFU-revocation counter has only `confirmed`, `pending` and `failed` outcomes and excludes lease, account, channel, error and media-token values.

The private realtime collectors expose only active connections, total accepted connections and time from WebSocket acceptance to the ready response. They have no labels and exclude account IDs, cookies, events, message data and channel IDs.

The private attachment-filesystem collector reads the same Linux `Bavail` snapshot used by upload admission and exposes available bytes, total bytes and a no-label snapshot-success gauge. A `0` success value makes both byte values unavailable; it does not prove free space, trigger cleanup, expose a filesystem path, or establish a capacity claim.

Compose rotates each long-running runtime container's JSON log after 10 MiB and retains at most three files; this bounds operational logs only, never deletes product data or changes its retention, and excludes one-shot migrations and explicit operator commands.

## Security and transaction rules

Mutations use strict CSRF/Origin protection, server-generated request IDs and safe cookies. SQL uses parameterized statements. The storage root stays private and all downloads authorize current conversation access. Passwords use Argon2id with the baseline documented in `docs/adr/ADR-001-password-hashing.md`; passwords, tokens, DM/message text and file content never enter logs. Transactions enforce unique normalized login, a single DM pair, monotonic read cursors, last-active-admin protection and revision-controlled channel ordering.
