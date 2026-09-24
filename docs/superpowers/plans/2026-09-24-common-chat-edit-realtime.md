# Common Chat Edit Realtime Implementation Plan

> **For agentic workers:** Inline execution is authorized by the ongoing user request. Follow the steps in order and use the focused failing tests before implementation.

**Goal:** Keep every connected client’s authorized text-channel history current after a successful message edit without broadcasting content.

**Architecture:** Wrap the existing text-message editor in a route-level composition adapter. Publish a best-effort `message.updated` event only after the edit transaction succeeds; clients validate its exact two-ID payload and reload only the matching active text channel through REST. Direct messages remain outside this event path.

Status: implemented; all backend/frontend tests, contract checks, traceability, and production build pass.

**Tech Stack:** Go 1.26, Vue 3/TypeScript, Pinia, WebSocket, JSON Schema, PostgreSQL-backed existing edit service.

---

## Route brief

- Classification: `split_first`; medium packet; T-040 common-channel edit hint leaf.
- Requirements: REQ-CHAT-01/REQ-SECURITY-02; preserve `expected_revision` conflicts and do not expose message bodies through realtime.
- Exact edges: `chat_routes.go` wires PATCH to the edit handler; the edit service returns authoritative `ID` and `ChannelID`; `event_hub.Hub.Publish` broadcasts bounded hints; realtime parser/store validates; `active_message_resync.ts` routes only the matching selected text-channel event.
- Files: new `backend/internal/chat/edit_text_message/realtime/event_publisher.go` and focused test; `backend/cmd/api/chat_routes.go`; `contracts/realtime.schema.json`; `frontend/src/realtime/realtime_client.ts`, `realtime_store.ts`, `realtime_store.spec.ts`; `frontend/src/workspace/active_message_resync.ts`, its spec, and `WorkspaceApp.vue`; `docs/API_AND_REALTIME.md`, `contracts/mobile-client-contract.md`, `TODO.md`.
- Ratchet: production files below hard 120 lines; no new executable behavior in route aggregates; no DM event, replay, DB migration, or ACL relaxation.
- Native checks: targeted and full `go test` from `backend`; focused and full Vitest plus Vite build from `frontend`; root `verify-contracts.ps1`, `verify-spec-traceability.ps1`, and `git diff --check`.
- Stop when failed/conflicting PATCHes publish nothing, successful PATCH publishes exactly the two IDs, invalid payloads are rejected, only the active matching text history refreshes, and checks pass.

## Execution steps

1. Add a focused Go test around the editor decorator: a successful result emits `message.updated` with payload exactly `{channel_id, message_id}`; an error emits nothing. Add valid, missing-ID, and extra-`body` frontend event cases. Run both focused suites and observe the new valid cases fail before implementation.
2. Implement the leaf `EventPublishingEditor`, which returns the editor’s result/error unchanged and publishes only when `err == nil`; wire it only to the authenticated text-channel PATCH route.
3. Extend the schema kind/payload rule, runtime event union/whitelist, and realtime-store exact payload validation for `message.updated`; retain the same opaque event boundary as creation/deletion.
4. Extend the tested text-history routing predicate so `message.updated` refreshes only the matching active text channel; a selected DM or another channel must remain untouched.
5. Update API/mobile event documentation and T-003/T-040 progress without closing all of T-040.
6. Run the native checks above, inspect changed files, line counts, worktree status, and the final behavior diff.

## Boundaries

This slice does not add edit events for DMs, durable replay, server schema changes, a production deploy, or POC evidence. Physical Windows/macOS tests remain owner-run manual work.
