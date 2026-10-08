# ADR023: temporary voice timeout

Accepted2026-10-09 for IMP44/#97 by engineering decision within fixed admin
moderation scope. Extends voice kick; account blocking and TEXT/DM remain separate.

## Policy

Only an active ADMINISTRATOR with an active secure-cookie session may set or clear
a voice timeout. Recheck role, account block and session in the same transaction.
GET is limited to the affected account or an administrator; peer state is private.
Use absolute RFC3339 expires_at and one bounded reason_code: DISRUPTION,
HARASSMENT, SPAM, OTHER. No free text. Database clock enforces future expiry and
maximum24h; normalize UTC to PostgreSQL microsecond precision. Repeating identical
expiry/reason is idempotent. An administrator may replace or manually clear it.

## Enforcement and linearization

Acquire the existing account advisory locks in canonical UUID sorted order, then
store timeout, revoke current voice leases using existing KICK semantics and enqueue
the existing durable SFU worker in one transaction. Audit contains actor/target,
bounded reason and expiry only. Existing worker retries and confirmation remain.
The202 response confirms committed intent; revocation_pending reports unconfirmed
outbox items, never physical success. Clear cannot cancel committed removals.

Lease acquisition checks under the same account lock. Credential and signal DB
reads lock the lease owner before a fresh READ COMMITTED authorization statement.
A timeout that commits first denies all three. An authorization that linearizes
first may return after moderation, but its lease is revoked atomically and signal
admission rechecks it; no already issued JWT is treated as unconditional access.
The additive BEFORE INSERT guard protects older API images from admitting new
leases during timeout. Existing rows, contracts and revocation reasons are preserved.

Expired rows are inactive according to clock_timestamp(); no periodic job is needed.
Expiry or clear permits only a new explicit manual Join. Never un-revoke a lease,
auto-connect, enable a microphone, restore screen publishing, or send remote unmute.
Self-moderation affects only voice and cannot demote/block the last administrator.

## Evidence boundaries

Real PostgreSQL races and fault tests prove atomic intent and admission serialization.
They do not establish physical SFU/device disconnect latency. QA10 still requires
active media removal and token replay on production-equivalent SFU and devices.
Client administrator controls are a separate development binding, server enforcement
is the security boundary. No custom roles, permanent mute, Redis or media proxy.
