# ADR-015: Long-lived voice roster SSE with session revalidation

- **Status:** Accepted
- **Date:** 2026-10-02
- **Decision owners:** Voice Platform maintainers

## Context

The roster endpoint previously closed each Server-Sent Events response after
10 seconds so the browser would reauthenticate on every reconnect. This made
the browser open a new HTTP request roughly every 13 seconds even when the
workspace and network were healthy. Those requests were valid SSE connections,
but the repeated churn was unnecessary and obscured actual reconnects.

Keeping a stream open without rechecking its session would leave a revoked
session attached to an authenticated stream. Roster snapshots must also keep
applying the caller's current channel visibility and active voice leases.

## Decision

Keep one SSE response open for the lifetime of the client connection. Send
comment heartbeats every 15 seconds so idle connections remain active through
the reverse proxy. Revalidate the original session cookie every 10 seconds
using the existing session authenticator. Continue rebuilding each roster
snapshot through the existing ACL and LiveKit presence service.

If the session is revoked or no longer resolves to the original account and
session digest, send an `event: session-expired` frame and close the response.
Web and Flutter clients close the stream and use their existing session expiry
handling. A session-store error closes the response without emitting roster
data; the clients may retry through their normal connection recovery paths.

## Consequences

- A healthy workspace uses one roster HTTP request until the browser or client
  disconnects or the session expires.
- Session revocation is detected within the 10-second revalidation interval.
- The server performs a bounded session lookup per open roster stream every 10
  seconds. Active participant/channel ACL checks still run for every snapshot.
- Network failures still cause normal SSE or client-stream reconnects.
