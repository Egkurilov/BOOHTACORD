# First DM Notification Implementation Plan

> **For agentic workers:** This bounded leaf is executed inline with a red-green regression check and native frontend validation.

**Goal:** Notify a permitted, hidden recipient browser when the first incoming message creates a DM navigation row.

**Architecture:** Capture zero unread when a DM create hint names a conversation absent from the pre-refresh list. After the protected navigation refresh, keep the existing addressed-unread check: only a row that appears with a larger unread count can produce a generic notification. Preserve the null result for unrelated TEXT events and non-create DM hints.

**Tech Stack:** Vue 3, Pinia, TypeScript, Vitest, Vite.

---

### Task 1: First-message notification

**Files:**
- Modify: `frontend/src/notification/notification_store.spec.ts`
- Modify: `frontend/src/notification/notification_store.ts`
- Add evidence: `evidence/qa/qa03-first-dm-notification-2026-09-25-001.json`

- [x] **Step 1: Write the failing test.** Start with an empty DM navigation list, capture a `direct_message.message_created` hint, then insert the newly visible DM with unread count 1 and deliver. Assert one generic notification. Also deliver a hint whose DM remains absent and assert no additional notification.

```ts
const before = store.capture(event)
expect(before).toBe(0)
directMessages.directMessages = [{ id: 'dm-a', otherParticipantId: 'peer', otherParticipantDisplayName: 'Участник', createdAt: event.occurredAt, unreadCount: 1, mentionCount: 0 }]
await store.deliver(event, before)
expect(value.show).toHaveBeenCalledWith('Voice Platform', { body: 'Новое личное сообщение.', tag: 'event-a' })
```

- [x] **Step 2: Confirm red.** Run `npm test -- src/notification/notification_store.spec.ts` from `frontend`; expect the new test to fail because `capture()` returns null.

- [x] **Step 3: Add the minimal capture fallback.** In `notification_store.ts`, return zero only for a DM create hint absent from the pre-refresh list. Leave `notificationCandidate()` unchanged so an absent post-refresh DM cannot alert.

```ts
const previous = addressedUnread(event, topology.topology, directMessages.directMessages)
return previous ?? (event.kind === 'direct_message.message_created' ? 0 : null)
```

- [x] **Step 4: Validate green and build.** Run focused notification tests, `npm run build`, and `scripts/verify-spec-traceability.ps1` only if requirements/backlog change. Record actual results and remaining browser permission limitation in the evidence JSON.
