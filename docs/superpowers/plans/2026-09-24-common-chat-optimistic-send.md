# Common chat optimistic send and retry

## Scope

Implement the unfinished common-channel send slice of T-040. Show a message while its POST is pending, make failure visible and recoverable, and reuse one `client_message_id` when retrying the same logical send after an uncertain response. Preserve a confirmed send if its history request completes later. A changed draft or attachment set is a new send. Preserve server ACL, replies, attachments, and the current composer contract. Do not expand into edit/delete realtime, DM, backend changes, or PostgreSQL integration.

Status: implemented; 7 focused tests and all frontend tests pass, production build passes.

## Route brief

- Route: `split_first`; leaf: common chat message send in `frontend/src/conversation`.
- Requirements: REQ-CHAT-01/02; server already scopes idempotency by author and channel.
- Files: `message_store.ts`, `message_store.spec.ts`, `message_client.ts`, `MessageItem.vue`, `TextConversation.vue`, `conversation.css`, `TODO.md`.
- Checks: focused `message_store.spec.ts`, full `npm test`, `npm run build`.
- Ratchet: keep changed production files below 120 lines; no new production files unless tests show an isolated capability is needed.
- Stop when pending/failed/success transitions, stable retry ID, and native frontend checks pass.

## Implementation sequence

1. Add failing store tests for immediate optimistic visibility, failed-send recovery, stable ID on retry, a new ID for changed payload, history reconciliation, and late history responses.
2. Implement pending/failed state and message replacement without duplicate local or server rows.
3. Render pending/error state accessibly; expose a retry action that retries the original payload, not any later composer draft.
4. Update T-040 progress without marking the whole task complete.
5. Run focused tests, full frontend tests, TypeScript/Vite build, then inspect diff, file sizes, and git status.

## Exclusions

No production deployment or live voice/media test in this slice. Physical Windows/macOS POC checks remain owner-run manual tasks.
