# ADR-024 — Six reactions and administrator TEXT pins

Status: accepted engineering design for owner-confirmed IMP-43 / #96, 2026-10-09.

The owner approved 👍 ❤️ 😂 🎉 👀 ✅ in TEXT and two-party DMs, with explicit idempotent PUT/DELETE, and administrator-managed pins only in common TEXT channels. This is an additive feature and does not introduce DM groups, an activity feed or a release blocker.

Reactions are unique by live message, actor and exact emoji. PUT makes the actor's reaction present; DELETE makes it absent. Writes lock and recheck the active account and live scoped message. A DM participant may react/read aggregates; administrator status never grants foreign DM access. Reads batch at most100 message IDs, expose count and caller's `mine` flag, and expose no reactor identities. Deleted, archived, wrong-conversation and VOICE targets reject writes/reads. One actor can use several approved emojis on a message.

Only a current unblocked administrator can pin/unpin an active common TEXT message. Pins use the original message ID and stable timestamp/ID cursor paging (maximum50 per page). Members can read pins and open the original message through existing authorized message context. HTTP previews are capped at240 characters, and the data query rechecks current account/channel/message ACL. There are no DM pin routes. Pin/unpin changes are audited with metadata only.

Foreign-key cascades cover hard deletion. PostgreSQL soft-delete triggers atomically remove TEXT reactions/pins and DM reactions in the existing message delete transaction. Message row locking prevents reaction/pin resurrection during concurrent deletion. Archive state does not silently delete metadata; live routes stop exposing it until an explicit restore.

Changed desired states publish post-commit ID-only hints: `message.reactions_updated`, `direct_message.reactions_updated`, `message.pins_updated`. Replays recheck current resource/account ACL; DM delivery is targeted only to the two participants and never broadcasts. `message_social_v1` capability negotiation gates live and replay delivery to compatible clients. Hints contain only conversation/message IDs, never emoji, counts, identities, previews or message content. Existing epoch/resync policy recovers a hint gap; the authoritative HTTP state and idempotent desired-state API survive publication failure. No generic outbox or exactly-once promise is added.

Browser controls bind real message components. Reads are coalesced per conversation; stale asynchronous responses are ignored on target change/disposal. Explicit errors and retry precede showing counts as current. Pins use the existing context navigation, with admin removal in the pin list. Server ACL remains authoritative when a stale UI role is displayed. Native bindings and deployed/device acceptance are recorded separately from browser/source verification.
