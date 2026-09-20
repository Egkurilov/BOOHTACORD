# ADR-005: self-hosted LiveKit revocation

## Context

The deployment uses a self-hosted LiveKit node. Removing a connected participant
is necessary to stop current media, but self-hosted LiveKit does not provide the
Cloud token-revocation service for a previously issued participant JWT. A
one-minute credential is defence in depth only and cannot by itself prove that a
revoked client will not reconnect.

## Decision

Every transaction that revokes a `voice_lease` inserts its lease and channel IDs
into `voice_sfu_revocations` in the same SQL statement. The API worker claims
those metadata-only rows, calls private `RoomService.RemoveParticipant` for
`voice-lease:<lease-id>` in `voice:<channel-id>`, and records completion or a
stable retry code. RoomService credentials are generated only inside the API
container and sent only to `http://livekit:7880` on the private Docker network.

Before Caddy forwards every `/rtc` signal connection or reconnect, it calls the
private API admission endpoint. That endpoint verifies the signed LiveKit token
and checks the current lease, issuing session, channel and account state in
PostgreSQL. It returns no token detail and Caddy skips access logging for the
token-bearing signal URI.

Go does not proxy RTP, RTCP, or audio/video payloads. LiveKit remains the media
transport; Go owns only authoritative admission and the private RoomService
command.

## Consequences

An SFU outage cannot restore admission: the lease transaction and signal guard
deny new or reconnecting media sessions immediately, while the durable outbox
retries participant removal. A response that only reports revoked logical leases
does not claim that the SFU disconnect has completed. POC-03 must separately
replay an old API credential and a refreshed SDK credential on the pinned image
with a second observer before the security gate can pass.

## Verification

Focused Go tests cover signed signal admission, expired/overprivileged token
denial, RoomService request scope, durable outbox claiming and retry. POC-03 is
the only evidence for real connected-media termination and replay behaviour.
