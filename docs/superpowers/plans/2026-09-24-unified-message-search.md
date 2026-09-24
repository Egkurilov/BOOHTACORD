# Unified message search implementation plan

**Goal:** Complete `REQ-SEARCH-01` with cursor-paginated search across readable text-channel messages and only the caller's own DMs, with an optional current-conversation filter, then expose it through the GuildChat SearchPanel.

**Security boundary:** Session middleware supplies the actor. Common channels must be active text channels; DM rows must be selected only when the actor is one of the two participants. Deleted messages, attachments, and content of third-party DMs are never returned. Search text and result bodies are never logged.

## Packet A — backend contract and operation

1. Add a `search_messages` domain leaf with validation, mixed-conversation cursor encoding, and lookahead pagination. Test invalid IDs, ambiguous filters, malformed cursors, query bounds, and next-page cursors before implementation.
2. Add a PostgreSQL repository using indexed `search_vector` columns and a `UNION ALL` of active text channels plus participant-owned DMs. Test SQL access predicates, soft-delete exclusion, deterministic ordering, and cursor predicate.
3. Add the session-protected `GET /api/v1/search/messages` handler. Optional `channel_id` and `direct_message_id` filters are mutually exclusive. Update OpenAPI, operator/mobile API docs, and traceability checks.
4. Run focused and full Go checks, API build, OpenAPI/traceability verification, and `git diff --check`. Do not deploy or claim production/browser/POC acceptance in this packet.

## Packet B — SearchPanel

1. Add a typed same-origin client for the unified search endpoint with response validation and pagination tests.
2. Add an accessible SearchPanel with query, all/current-conversation filter, loading/empty/error states, safe message rendering, and cursor pagination. Results navigate only to the returned channel or caller-owned DM.
3. Mount it in the existing right area or responsive drawer without adding a fourth column; keep the conversation, channel navigation, and persistent VoiceDock visible. Add design contract and component tests.
4. Run frontend tests/build and update the design TODO/status. Authenticated visual screenshot acceptance remains a separate manual gate.

## Stop conditions

- Never read or expose another participant's DM, even for administrator callers.
- Never use offset pagination or load complete histories.
- Never search deleted messages, attachment contents, audio, or screen data.
- Do not mark visual parity, real PostgreSQL search, production release, or physical POC as complete without its corresponding evidence.

## Execution status — 2026-09-24

- [x] Packet A — session-protected unified API, ACL-constrained PostgreSQL query, OpenAPI and Russian mobile/operator contracts.
- [x] Packet B — typed client, accessible right-area/drawer SearchPanel, current-conversation filter, safe rendering, and channel/DM navigation.
- [x] Local Go/TypeScript tests, builds, contract and requirement-traceability validation.
- [ ] Production deployment and real PostgreSQL data verification.
- [ ] Authenticated browser visual review; separate physical POC-01/02/03 checks remain with the operator.
