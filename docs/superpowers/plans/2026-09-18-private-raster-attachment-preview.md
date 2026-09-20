# Private Raster Attachment Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render a bounded, ACL-protected PNG preview for attached PNG/JPEG/GIF files in a text channel while all other source files remain forced downloads.

**Architecture:** A new preview service calls the existing authorized `download_text_attachment.Service.Open` first, then reads its already size-checked private stream, validates `DecodeConfig`, rejects non-raster and over-large pixel sources, and re-encodes the first image frame as a bounded PNG. A new authenticated route never discloses storage metadata and returns `404` for unavailable/unsupported previews. The Vue component requests the same-origin preview only for raster-looking names and hides it when the protected route says no.

**Tech Stack:** Go standard-library image/jpeg/png/gif codecs, Go HTTP, Vue 3, TypeScript, Vitest, OpenAPI.

---

### Task 1: Bounded private preview renderer

**Files:**
- Create: `backend/internal/storage/preview_text_attachment/service.go`
- Create: `backend/internal/storage/preview_text_attachment/service_test.go`

- [x] **Step 1: Write failing renderer tests**

```go
rendered, err := New(downloader).Render(context.Background(), downloadtextattachment.Input{ActorID: actorID, ChannelID: channelID, AttachmentID: attachmentID})
config, format, err := image.DecodeConfig(bytes.NewReader(rendered))
if err != nil || format != "png" || config.Width != 1024 || config.Height != 512 { t.Fatal(...) }

_, err = New(svgDownloader).Render(context.Background(), input)
if !errors.Is(err, ErrPreviewUnavailable) { t.Fatal(err) }
```

Use a generated 2048×1024 PNG fixture and a fake downloader returning `downloadtextattachment.Opened`; assert that the caller’s actor/channel/attachment input is passed to the downloader.

- [x] **Step 2: Run the new test and verify it fails before the package exists**

Run: `go test ./internal/storage/preview_text_attachment`

Expected: FAIL because `preview_text_attachment` is absent.

- [x] **Step 3: Implement raster-only, bounded PNG normalization**

```go
const MaxPreviewDimension = 1024
const MaxSourcePixels = 16_777_216

func (service Service) Render(ctx context.Context, input downloadtextattachment.Input) ([]byte, error) {
    opened, err := service.downloader.Open(ctx, input)
    if err != nil { return nil, err }
    defer opened.Reader.Close()
    source, err := io.ReadAll(io.LimitReader(opened.Reader, downloadtextattachment.MaxAttachmentBytes+1))
    // Require source length to equal authorized SizeBytes, DecodeConfig before Decode,
    // accept only png/jpeg/gif, cap dimensions/pixels, scale to 1024px longest edge,
    // then png.Encode an image.NRGBA.
}
```

Import `_ "image/gif"`, `_ "image/jpeg"`, and `_ "image/png"`; do not trust file extensions or MIME claims. Unsupported, corrupt, length-mismatched, or oversized images return `ErrPreviewUnavailable`; unexpected read/encode failures remain internal errors. The scaler must use source bounds and never allocate from unvalidated width/height.

- [x] **Step 4: Run the focused renderer test**

Run: `go test ./internal/storage/preview_text_attachment`

Expected: PASS.

### Task 2: ACL-gated HTTP route and contract

**Files:**
- Create: `backend/internal/storage/preview_text_attachment/api/http_handler.go`
- Create: `backend/internal/storage/preview_text_attachment/api/http_handler_test.go`
- Modify: `backend/cmd/api/storage_routes.go:14-55`
- Modify: `contracts/openapi.yaml:278-308`

- [x] **Step 1: Write failing HTTP tests for normalized PNG and hidden unavailable content**

```go
NewHandler(renderer).ServeHTTP(recorder, authenticatedRequest())
if recorder.Code != http.StatusOK || recorder.Header().Get("Content-Type") != "image/png" || recorder.Header().Get("Cache-Control") != "no-store" { t.Fatal(...) }

renderer.err = previewtextattachment.ErrPreviewUnavailable
NewHandler(renderer).ServeHTTP(recorder, authenticatedRequest())
if recorder.Code != http.StatusNotFound || strings.Contains(recorder.Body.String(), "storage-key") { t.Fatal(...) }
```

- [x] **Step 2: Run the handler test and verify it fails before the API package exists**

Run: `go test ./internal/storage/preview_text_attachment/api`

Expected: FAIL because the handler package is absent.

- [x] **Step 3: Add the protected preview route and its precise contract**

```go
mux.Handle("GET /api/v1/channels/{channelID}/attachments/{attachmentID}/preview", sessionapi.Require(sessions)(previewapi.NewHandler(previewer)))
```

The handler builds `downloadtextattachment.Input` only from the session principal and path IDs, maps invalid ID to 400, unavailable attachment/preview to 404, and unknown errors to 500. A 200 response sets `Content-Type: image/png`, exact `Content-Length`, `Cache-Control: no-store`, and `X-Content-Type-Options: nosniff`; it emits no filename, storage key, source MIME, or source bytes. Document the route as a normalized private image preview; 404 covers absent, unauthorized, deleted, unsupported, corrupt, and oversized sources.

- [x] **Step 4: Run API, full Go test, vet, contracts and traceability checks**

Run: `go test ./internal/storage/preview_text_attachment/api; go test ./...; go vet ./...; powershell -ExecutionPolicy Bypass -File ../scripts/verify-contracts.ps1; powershell -ExecutionPolicy Bypass -File ../scripts/verify-spec-traceability.ps1`

Expected: all commands exit 0.

### Task 3: Safe browser rendering

**Files:**
- Create: `frontend/src/conversation/text_message_attachment_preview_url.ts`
- Create: `frontend/src/conversation/text_message_attachment_preview_url.spec.ts`
- Modify: `frontend/src/conversation/TextMessageAttachments.vue:1-24`

- [x] **Step 1: Write failing same-origin preview URL tests**

```ts
expect(textMessageAttachmentPreviewUrl('channel/a', 'file ?#')).toBe('/api/v1/channels/channel%2Fa/attachments/file%20%3F%23/preview')
expect(() => textMessageAttachmentPreviewUrl('', 'file-1')).toThrow('Некорректное вложение')
```

- [x] **Step 2: Run the test and verify it fails before the helper exists**

Run: `npm test -- --run src/conversation/text_message_attachment_preview_url.spec.ts`

Expected: FAIL with a module-resolution error.

- [x] **Step 3: Add only safe preview affordances**

```vue
<img
  v-if="isRasterName(attachment.originalName) && !failedPreviews.has(attachment.id)"
  :src="textMessageAttachmentPreviewUrl(props.channelId, attachment.id)"
  :alt="`Предпросмотр: ${attachment.originalName}`"
  @error="hidePreview(attachment.id)"
>
```

The helper creates only encoded same-origin paths. `isRasterName` is a client hint for `png`, `jpg`, `jpeg`, and `gif`; the server is authoritative and normalizes every successful response to PNG. Keep the download anchor for every file. Do not use `v-html`, `object`/`iframe`, direct source links, Blob/object URLs, inline SVG, or any client MIME sniffing.

- [x] **Step 4: Run frontend tests and production build**

Run: `npm test -- --run && npm run build`

Expected: all tests and `vue-tsc --noEmit && vite build` pass.

### Task 4: Evidence and shared-worktree review

**Files:**
- Modify: `TODO.md: T-045`
- Modify: `docs/superpowers/plans/2026-09-18-private-raster-attachment-preview.md`

- [x] **Step 1: Record the new text-channel preview boundary in TODO**

State that only server-normalized raster previews are available; all active/non-raster source files remain forced downloads. Keep DM preview, authenticated browser e2e, unlink/collection and audit as open work.

- [x] **Step 2: Inspect exact packet diffs and record results**

Run: `git diff --check -- backend/internal/storage/preview_text_attachment backend/cmd/api/storage_routes.go contracts/openapi.yaml frontend/src/conversation/text_message_attachment_preview_url.ts frontend/src/conversation/TextMessageAttachments.vue TODO.md; git status --short`

Mark executed steps `[x]`, append exact passing command outcomes, and do not stage or commit from the shared dirty worktree.

## Self-review

- **Spec coverage:** Implements the REQ-STORAGE-02 raster-preview requirement without making source objects public or executable. ACL remains the existing server-side attachment/message/channel/session predicate.
- **Bounds:** The private input is capped by the pre-existing 25,000,000-byte attachment limit, config dimensions must be positive and at most 16,777,216 pixels, output never exceeds 1024px on its longest side, and output is server-encoded `image/png`.
- **Intentional gaps:** DM attachments, source-image preview beyond PNG/JPEG/GIF, real authenticated browser E2E, physical cleanup, and all POC/media gates are outside this leaf.
- **Type consistency:** Both handler and renderer use `downloadtextattachment.Input`; the browser helper mirrors existing encoded attachment URL construction and accepts the same two IDs.

## Execution evidence

- Failing-first checks: the renderer package and the frontend preview URL module were absent; focused tests failed at module/symbol resolution before implementation.
- Focused Go checks: `go test ./internal/storage/preview_text_attachment ./internal/storage/preview_text_attachment/api` passed. The renderer test also rejects a valid PNG header whose declared dimensions exceed the 16,777,216-pixel limit before image decode.
- Full verification: `go test ./...`, `go vet ./...`, `scripts/verify-contracts.ps1`, and `scripts/verify-spec-traceability.ps1` passed. Frontend `npm test -- --run && npm run build` passed: 49 test files and 117 tests.
- `git diff --check` reported no patch whitespace errors. Existing shared-worktree changes remain unstaged and uncommitted.
