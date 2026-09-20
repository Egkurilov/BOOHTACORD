# Render Text Message Attachments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render safe metadata for an attached text-message file and let an authenticated browser invoke the protected same-origin download route without ever constructing a public or inline-media URL.

**Architecture:** `message_client` treats the required history `attachments` array as a typed safe projection (`id`, original filename, byte size). A tiny URL helper encodes only the channel and attachment IDs under `apiBaseUrl`; it neither fetches bytes nor uses `blob:`, query tokens, storage keys or cross-origin URLs. `TextMessageAttachments.vue` renders semantic download links below a non-deleted message, while the server remains the final ACL authority for every click.

**Tech Stack:** Vue 3, TypeScript, Vitest, existing same-origin Go download endpoint.

---

### Task 1: Make safe history attachment metadata typed at the client boundary

**Files:**
- Modify: `frontend/src/conversation/message_client.ts`
- Modify: `frontend/src/conversation/message_client.spec.ts`

- [x] **Step 1: Add a failing page-parse test for valid metadata and missing arrays.**

```ts
const page = { messages: [{ ...body, attachments: [{ id: 'attachment-1', original_name: 'notes.svg', byte_size: 10 }] }] }
await expect(loadMessagePage('text-1', undefined, request)).resolves.toMatchObject({ messages: [{ attachments: [{ originalName: 'notes.svg', sizeBytes: 10 }] }] })
await expect(loadMessagePage('text-1', undefined, malformedRequest)).rejects.toThrow('некорректное сообщение')
```

Use only response fixtures; do not read file contents or perform a real request.

- [x] **Step 2: Run the focused test before client implementation.**

Run: `npm test -- src/conversation/message_client.spec.ts`

Expected: FAIL because `TextMessage` has no attachment projection and the parser accepts a missing `attachments` array.

- [x] **Step 3: Implement strict safe metadata parsing.**

```ts
export interface TextMessageAttachment { id: string; originalName: string; sizeBytes: number }
const attachments = parseAttachments(source.attachments)
return { /* existing message fields */, attachments }
```

Require an array; every item must have non-empty string `id` and `original_name`, and integer `byte_size` from `0` through `25_000_000`. Do not admit `storage_key`, URL, MIME type or content into the type.

- [x] **Step 4: Re-run the focused client test.**

Run: `npm test -- src/conversation/message_client.spec.ts`

Expected: PASS.

### Task 2: Construct only an encoded same-origin download path

**Files:**
- Create: `frontend/src/conversation/text_message_attachment_url.ts`
- Create: `frontend/src/conversation/text_message_attachment_url.spec.ts`

- [x] **Step 1: Write the focused encoded-path test.**

```ts
expect(textMessageAttachmentDownloadUrl('channel/a', 'file ?#')).toBe('/api/v1/channels/channel%2Fa/attachments/file%20%3F%23')
```

The test must also reject empty IDs, proving a template cannot turn absent data into a broad route.

- [x] **Step 2: Run the test before the helper exists.**

Run: `npm test -- src/conversation/text_message_attachment_url.spec.ts`

Expected: FAIL because the module is absent.

- [x] **Step 3: Implement the pure path helper.**

```ts
export function textMessageAttachmentDownloadUrl(channelId: string, attachmentId: string): string {
  if (!channelId || !attachmentId) throw new Error('Некорректное вложение.')
  return `${apiBaseUrl}/channels/${encodeURIComponent(channelId)}/attachments/${encodeURIComponent(attachmentId)}`
}
```

It must return a path only—no `fetch`, `window.open`, credentials in a URL, `blob:` URL or public host.

- [x] **Step 4: Re-run the helper test.**

Run: `npm test -- src/conversation/text_message_attachment_url.spec.ts`

Expected: PASS.

### Task 3: Render accessible download controls without previewing active content

**Files:**
- Create: `frontend/src/conversation/TextMessageAttachments.vue`
- Modify: `frontend/src/conversation/MessageItem.vue`
- Modify: `frontend/src/style.css`

- [x] **Step 1: Implement the attachment-list component.**

```vue
<ul v-if="attachments.length" class="text-message-attachments" aria-label="Вложения сообщения">
  <li v-for="attachment in attachments" :key="attachment.id">
    <a :href="textMessageAttachmentDownloadUrl(channelId, attachment.id)" download>Скачать {{ attachment.originalName }} · {{ byteLabel(attachment.sizeBytes) }}</a>
  </li>
</ul>
```

Use Vue interpolation only; there is no `v-html`, `<img>`, `<iframe>`, media element, target window or automatic download. The component should render nothing for an empty list and format bytes with `Intl.NumberFormat('ru-RU')` plus `Б`/`КБ`/`МБ`.

- [x] **Step 2: Mount only beneath a non-deleted text message body while preserving DM reuse.**

`MessageItem` is also the existing DM renderer. Its structural message prop must therefore make text-only `channelId` and `attachments` optional while retaining all shared message fields. Derive `textChannelId = message.channelId ?? ''` and `textAttachments = message.attachments ?? []`; mount the component only when the message is non-deleted and both values are present. A DM and a deleted message must not render links even if a stale client object had attachment-shaped data.

- [x] **Step 3: Add narrow dark-theme download-link styling.**

Add `.text-message-attachments` styles for a compact list, visible focus outline, readable contrast and overflow-safe filename wrapping. Do not change global text-search or voice styles.

- [x] **Step 4: Run frontend regression checks.**

Run: `npm test`; `npm run build`; `git diff --check`.

Expected: PASS. Inspect scoped file sizes/status without staging or deploying. A real owner login, real byte transfer, upload composer, previews and DM support remain separate work.

**Coverage review:** This leaf provides safe text-history attachment display and a protected same-origin download action. It deliberately excludes upload selection, `attachment_ids` mutation, blob/object URLs, public URLs, raster previews, active-content rendering, DM attachments and authenticated browser evidence.
