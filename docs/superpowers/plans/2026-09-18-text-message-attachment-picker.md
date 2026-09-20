# Text-message attachment picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an authenticated user upload up to ten private files to a TEXT channel and attach the successful uploads to a non-empty text message.

**Architecture:** The browser sends each file to the already-existing same-origin multipart upload endpoint and retains only its safe `{id, originalName, sizeBytes}` response. The composer passes that metadata to the message store; on a successful create response the store uses it for the local message projection, while the server remains the authority that validates and links the attachment IDs. The UI never receives a storage key or preview URL, and downloading continues through the existing ACL-protected endpoint.

**Tech Stack:** Vue 3 Composition API, TypeScript, Pinia, Vitest, existing Go/OpenAPI upload and message contracts.

---

### Task 1: Protected browser upload client

**Files:**
- Create: `frontend/src/conversation/text_attachment_upload_client.ts`
- Test: `frontend/src/conversation/text_attachment_upload_client.spec.ts`

- [x] **Step 1: Write failing tests for a valid multipart request and malformed response**

```ts
await expect(uploadTextAttachment('text-1', file, request)).resolves.toEqual({
  id: 'attachment-1', originalName: 'notes.txt', sizeBytes: 4,
})
expect(request).toHaveBeenCalledWith(
  '/api/v1/channels/text-1/attachments',
  expect.objectContaining({ method: 'POST', credentials: 'same-origin' }),
)
expect((request.mock.calls[0][1]!.body as FormData).get('file')).toBe(file)

await expect(uploadTextAttachment('text-1', file, malformedRequest)).rejects.toThrow('некорректные данные')
```

- [x] **Step 2: Run the focused test and verify it fails because the module does not exist**

Run: `npm test -- --run src/conversation/text_attachment_upload_client.spec.ts`

Expected: FAIL with a module-resolution error for `text_attachment_upload_client`.

- [x] **Step 3: Add the minimal typed same-origin upload client**

```ts
export interface TextAttachmentUpload { id: string; originalName: string; sizeBytes: number }

export async function uploadTextAttachment(channelId: string, file: File, request: MessageRequest = fetch): Promise<TextAttachmentUpload> {
  if (!channelId || !file.name || file.size < 0 || file.size > 25_000_000) throw new Error('Файл не соответствует ограничению вложения.')
  const body = new FormData()
  body.append('file', file)
  const response = await request(`${apiBaseUrl}/channels/${encodeURIComponent(channelId)}/attachments`, {
    method: 'POST', credentials: 'same-origin', headers: { accept: 'application/json' }, body,
  })
  // Parse only id, original_name and byte_size; throw MessageRequestError for non-2xx responses.
}
```

The implementation must not manually set `Content-Type`, must not construct a storage URL, and must reject empty IDs/names, non-integer byte sizes, and sizes outside `0..25_000_000`.

- [x] **Step 4: Run the focused test and verify it passes**

Run: `npm test -- --run src/conversation/text_attachment_upload_client.spec.ts`

Expected: PASS.

### Task 2: Message create transport and optimistic safe projection

**Files:**
- Modify: `frontend/src/conversation/message_client.ts:76-79`
- Modify: `frontend/src/conversation/message_store.ts:43-62`
- Modify: `frontend/src/conversation/message_client.spec.ts:25-39`
- Modify: `frontend/src/conversation/message_store.spec.ts:10-19`

- [x] **Step 1: Write failing tests for `attachment_ids` and the attached message display model**

```ts
await createTextMessage('text-1', 'client-1', 'Привет', request, 'message-0', ['attachment-1'])
expect(request).toHaveBeenCalledWith(
  '/api/v1/channels/text-1/messages',
  expect.objectContaining({ body: '{"client_message_id":"client-1","body":"Привет","reply_to_id":"message-0","attachment_ids":["attachment-1"]}' }),
)

await store.send('Привет', request, () => 'client-1', undefined, [{ id: 'attachment-1', originalName: 'notes.txt', sizeBytes: 4 }])
expect(store.messages[0]?.attachments).toEqual([{ id: 'attachment-1', originalName: 'notes.txt', sizeBytes: 4 }])
```

- [x] **Step 2: Run the two focused tests and verify they fail**

Run: `npm test -- --run src/conversation/message_client.spec.ts src/conversation/message_store.spec.ts`

Expected: FAIL because neither method accepts the attachment argument and no `attachment_ids` field is sent.

- [x] **Step 3: Extend the two exact method signatures without changing existing callers**

```ts
export async function createTextMessage(
  channelId: string, clientMessageId: string, body: string, request: MessageRequest = fetch,
  replyToId?: string, attachmentIds: string[] = [],
): Promise<TextMessage> {
  const payload = { client_message_id: clientMessageId, body,
    ...(replyToId ? { reply_to_id: replyToId } : {}),
    ...(attachmentIds.length ? { attachment_ids: attachmentIds } : {}),
  }
  // Existing checked/message parsing remains unchanged.
}

async function send(
  body: string, request?: MessageRequest, createId: () => string = () => crypto.randomUUID(),
  replyToId?: string, attachments: TextMessageAttachment[] = [],
): Promise<boolean> {
  const created = await createTextMessage(targetChannelId, createId(), body, request, replyToId, attachments.map(({ id }) => id))
  messages.value = [{ ...created, attachments }, ...messages.value.filter((message) => message.id !== created.id)]
  return true
}
```

The server has already accepted `attachment_ids` and confirms linkage before returning success; do not trust a client-selected file name or status as authorization. Do not add a history refresh or alter edit/delete behaviour in this packet.

- [x] **Step 4: Run the focused tests and verify they pass**

Run: `npm test -- --run src/conversation/message_client.spec.ts src/conversation/message_store.spec.ts`

Expected: PASS.

### Task 3: Composer picker and submission integration

**Files:**
- Create: `frontend/src/conversation/TextMessageAttachmentPicker.vue`
- Modify: `frontend/src/conversation/TextConversation.vue:1-78`
- Test: `frontend/src/conversation/text_attachment_upload_client.spec.ts`

- [x] **Step 1: Define the picker boundary around the upload client**

```ts
const props = defineProps<{ channelId: string; disabled: boolean; clearToken: number }>()
const emit = defineEmits<{ change: [attachments: TextAttachmentUpload[]]; pending: [value: boolean] }>()
const attachments = ref<TextAttachmentUpload[]>([])
const pending = ref(false)
const error = ref<string | null>(null)

async function addFiles(event: Event): Promise<void> {
  const files = Array.from((event.target as HTMLInputElement).files ?? [])
  if (attachments.value.length + files.length > 10) { error.value = 'К сообщению можно прикрепить не более 10 файлов.'; return }
  pending.value = true; emit('pending', true)
  // Upload serially with uploadTextAttachment(props.channelId, file), retain already successful files, emit change after each success.
}
```

Render an accessible labelled multiple file input, a text list of selected safe names and byte sizes, and a bounded error message. Reset the input value after processing so the same file can be re-selected. Watch `clearToken` to clear the local list only after message creation succeeds. Do not implement file previews, object URLs, client-side download links, or a delete call for staged uploads because no safe server delete endpoint exists.

- [x] **Step 2: Integrate picker values in the exact text-channel composer**

```ts
const attachments = ref<TextAttachmentUpload[]>([])
const attachmentPending = ref(false)
const attachmentClearToken = ref(0)

async function send(): Promise<void> {
  if (await store.send(draft.value, undefined, undefined, replyTarget.value?.id, attachments.value)) {
    draft.value = ''
    replyTarget.value = null
    attachmentClearToken.value += 1
  }
}
```

```vue
<TextMessageAttachmentPicker
  :channel-id="props.channelId"
  :disabled="store.sending"
  :clear-token="attachmentClearToken"
  @change="attachments = $event"
  @pending="attachmentPending = $event"
/>
<button class="voice-join" type="submit" :disabled="store.sending || attachmentPending || !draft">
  {{ store.sending ? 'Отправляем…' : 'Отправить' }}
</button>
```

Keep the non-empty text requirement: attachment-only messages remain invalid per `TextMessageCreateRequest.body.minLength`. The picker must not render for DMs because `TextConversation.vue` is only the text-channel composer.

- [x] **Step 3: Type-check and run all frontend tests**

Run: `npm test -- --run && npm run build`

Expected: all Vitest files pass and `vue-tsc --noEmit && vite build` exits 0.

### Task 4: Review the safe product boundary and preserve the shared worktree

**Files:**
- Modify: `docs/superpowers/plans/2026-09-18-text-message-attachment-picker.md`

- [x] **Step 1: Inspect the exact diff and file lengths**

Run: `git diff --check -- frontend/src/conversation/text_attachment_upload_client.ts frontend/src/conversation/text_attachment_upload_client.spec.ts frontend/src/conversation/TextMessageAttachmentPicker.vue frontend/src/conversation/TextConversation.vue frontend/src/conversation/message_client.ts frontend/src/conversation/message_client.spec.ts frontend/src/conversation/message_store.ts frontend/src/conversation/message_store.spec.ts; git status --short`

Expected: no whitespace errors; only the listed packet files are attributed to this packet, while unrelated pre-existing changes remain untouched.

- [x] **Step 2: Record the execution results**

Replace each completed checkbox with `[x]` and record the exact test/build commands and outcomes in a short `## Execution evidence` section.

- [x] **Step 3: Do not stage or commit from this shared dirty worktree**

The repository has user-owned uncommitted changes. Leave staging and commit selection to the owner after review; do not use a root-wide `git add`.

## Self-review

- **Spec coverage:** T-044 is covered for the user-facing upload-to-text-message path. Upload remains private, server-side channel ACL continues to decide access, at most ten IDs are sent, and the existing forced-download path remains the only read path.
- **Intentional gap:** This packet does not provide deletion of unlinked staged attachments because the server has no ACL-safe delete endpoint. It also does not permit attachment-only messages because the approved contract requires text.
- **Placeholder scan:** No deferred implementation step is required; each change has an exact file, code shape, and validation command.
- **Type consistency:** `TextAttachmentUpload` has the same safe fields as `TextMessageAttachment`; it flows picker → composer → `send` → `createTextMessage(…, attachmentIds)`.

## Execution evidence

- Failing-first run: the new upload client was absent and the existing client/store tests showed that `attachment_ids` and local metadata were ignored.
- Focused verification: `npm test -- --run src/conversation/text_attachment_upload_client.spec.ts src/conversation/message_client.spec.ts src/conversation/message_store.spec.ts` — 3 files, 7 tests passed.
- Full frontend verification: `npm test -- --run && npm run build` — 48 files, 115 tests passed; `vue-tsc --noEmit && vite build` passed.
- `git diff --check` for the packet emitted no whitespace errors. The shared worktree was inspected and nothing was staged or committed.
- `TODO.md` now records the completed text-channel picker/download UI boundaries; `scripts/verify-spec-traceability.ps1` passed with 39 referenced requirements.
