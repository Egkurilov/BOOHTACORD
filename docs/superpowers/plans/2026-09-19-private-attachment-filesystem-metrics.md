# Private Attachment Filesystem Metrics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose current private attachment-filesystem byte capacity to the existing internal Prometheus handler without paths, identifiers, content, or a public route.

**Architecture:** The existing Linux storage adapter remains the source of `Bavail` and total bytes. An observability-specific source interface maps that snapshot at the API storage composition edge. A no-label custom Prometheus collector reads the source at each private `/metrics` scrape and emits available bytes, total bytes, and an explicit success gauge; errors and invalid values emit zero values plus success `0` and never enter logs or metric labels.

**Tech Stack:** Go 1.26, Prometheus client, existing private `/metrics` handler, Linux `statfs` storage adapter.

---

### Task 1: Scrape-time storage collector

**Files:**
- Create: `backend/internal/observability/http_metrics/attachment_filesystem.go`
- Modify: `backend/internal/observability/http_metrics/recorder.go`
- Create: `backend/internal/observability/http_metrics/attachment_filesystem_test.go`

- [x] **Step 1: Write failing collector tests**

Add a fake source and verify that a scrape after registration contains all three no-label values and contains neither a path nor a source error.

```go
recorder := New()
if err := recorder.RegisterAttachmentFilesystem(fakeAttachmentFilesystem{snapshot: AttachmentFilesystemSnapshot{AvailableBytes: 7, TotalBytes: 11}}); err != nil { t.Fatal(err) }
metrics := scrapeMetrics(t, recorder)
for _, line := range []string{
    "voice_platform_attachment_filesystem_available_bytes 7",
    "voice_platform_attachment_filesystem_total_bytes 11",
    "voice_platform_attachment_filesystem_snapshot_success 1",
} { if !strings.Contains(metrics, line) { t.Fatal(line) } }
```

Add a failing source case and assert `available=0`, `total=0`, `success=0`. Also assert registration rejects `nil` and a second registration.

- [x] **Step 2: Run the focused test in the red state**

Run: `go test ./internal/observability/http_metrics -run 'TestRecorderPublishesAttachmentFilesystemMetrics|TestRecorderReportsAttachmentFilesystemSnapshotFailure' -count=1`

Expected: FAIL because `RegisterAttachmentFilesystem` and the filesystem source types do not exist.

- [x] **Step 3: Implement the collector and one-time registration**

Create these source types and error values in `attachment_filesystem.go`:

```go
type AttachmentFilesystemSnapshot struct { AvailableBytes, TotalBytes int64 }
type AttachmentFilesystemSource interface { Snapshot(context.Context) (AttachmentFilesystemSnapshot, error) }
var ErrInvalidAttachmentFilesystemSource = errors.New("invalid attachment filesystem metric source")
var ErrAttachmentFilesystemAlreadyRegistered = errors.New("attachment filesystem metric source already registered")
```

The collector emits exactly `voice_platform_attachment_filesystem_available_bytes`, `voice_platform_attachment_filesystem_total_bytes`, and `voice_platform_attachment_filesystem_snapshot_success`, all with no labels. It calls `source.Snapshot(context.Background())` only during collection. A non-nil error, negative value, or `available > total` returns zero byte values and success `0`; no error text, filesystem path, attachment name, account, channel, or label is emitted.

Extend `Recorder` with its private registry and a boolean registration guard:

```go
func (recorder *Recorder) RegisterAttachmentFilesystem(source AttachmentFilesystemSource) error {
    if source == nil { return ErrInvalidAttachmentFilesystemSource }
    if recorder.attachmentFilesystemRegistered { return ErrAttachmentFilesystemAlreadyRegistered }
    recorder.registry.MustRegister(newAttachmentFilesystemCollector(source))
    recorder.attachmentFilesystemRegistered = true
    return nil
}
```

- [x] **Step 4: Run the focused collector tests**

Run: `go test ./internal/observability/http_metrics -count=1`

Expected: PASS, including existing request, realtime, and SFU tests.

### Task 2: Bind the existing Linux snapshot at storage composition

**Files:**
- Modify: `backend/cmd/api/storage_routes.go`
- Modify: `backend/cmd/api/main.go`
- Create: `backend/cmd/api/storage_metrics_test.go`

- [x] **Step 1: Write an adapter test**

Create a fake `reserve.Space`, pass it through an `attachmentFilesystemMetricSource`, and prove the metric snapshot preserves only available and total byte counts while forwarding context and source errors.

```go
snapshot, err := attachmentFilesystemMetricSource{space: fakeAttachmentSpace{snapshot: reserve.Snapshot{AvailableBytes: 7, TotalBytes: 11}}}.Snapshot(context.Background())
if err != nil || snapshot != (httpmetrics.AttachmentFilesystemSnapshot{AvailableBytes: 7, TotalBytes: 11}) { t.Fatal(snapshot, err) }
```

- [x] **Step 2: Run the adapter test in the red state**

Run: `go test ./cmd/api -run TestAttachmentFilesystemMetricSource -count=1`

Expected: FAIL because `attachmentFilesystemMetricSource` does not exist.

- [x] **Step 3: Wire exactly one source during storage setup**

Change `configureStorageRoutes` to receive `metrics *httpmetrics.Recorder`. After `reserve.NewFilesystem(root)` succeeds and before the manager is created, register:

```go
if err := metrics.RegisterAttachmentFilesystem(attachmentFilesystemMetricSource{space: space}); err != nil { return err }
```

Define the adapter in `storage_routes.go`:

```go
type attachmentFilesystemMetricSource struct{ space reserve.Space }
func (source attachmentFilesystemMetricSource) Snapshot(ctx context.Context) (httpmetrics.AttachmentFilesystemSnapshot, error) {
    snapshot, err := source.space.Snapshot(ctx)
    return httpmetrics.AttachmentFilesystemSnapshot{AvailableBytes: snapshot.AvailableBytes, TotalBytes: snapshot.TotalBytes}, err
}
```

Pass the already-created `metrics` from `main.go`. Do not add a route, port, scheduler, storage write, or database query.

- [x] **Step 4: Run package tests**

Run: `go test ./cmd/api ./internal/observability/http_metrics -count=1`

Expected: PASS.

### Task 3: Documentation, verification, and controlled delivery

**Files:**
- Modify: `docs/ARCHITECTURE_AND_DATA.md`
- Create: `evidence/observability-attachment-filesystem-2026-09-19-001.json`
- Modify: `docs/superpowers/plans/2026-09-19-private-attachment-filesystem-metrics.md`

- [x] **Step 1: Document privacy and semantics**

State that the internal scrape reports the filesystem containing private attachments using `Bavail`; it has no path or identity labels. Explain that success `0` makes byte values unavailable rather than proving disk state, and that the metric is not a storage cleanup trigger or capacity claim.

- [x] **Step 2: Run local verification**

Run: `go test ./... -count=1; go vet ./...; powershell -ExecutionPolicy Bypass -File scripts/verify-contracts.ps1; gofmt -d backend/internal/observability/http_metrics/attachment_filesystem.go backend/internal/observability/http_metrics/recorder.go backend/cmd/api/storage_routes.go backend/cmd/api/storage_metrics_test.go`

Expected: all commands exit 0 and `gofmt -d` is empty.

- [x] **Step 3: Deploy the private capability only**

Copy only the reviewed API source, Dockerfile, Compose file, and architecture document to an explicit fresh server staging directory. Build `voice-platform-api:release-20260919-attachment-filesystem-metrics`, update only `API_IMAGE`, recreate only API, and verify health `200`, public `/metrics` `404`, plus a private scrape contains the three no-label metric family names. Do not include metric values or paths in evidence.

- [x] **Step 4: Record evidence and update this plan**

Record static tests, private scrape success, public-route denial, and deployment health. Mark physical storage capacity, load, POC, file cleanup execution, and media quality as unproven. Mark completed checklist items `[x]`; confirm no placeholder language remains and do not stage or commit the shared worktree.

## Self-review

- **Spec coverage:** Advances the T-053 disk-state metric using the already-approved Linux storage snapshot and private scrape boundary.
- **Privacy:** The collector has no labels, paths, object names, account IDs, channel IDs, tokens, messages, or attachment contents; it is unavailable via Caddy's public endpoint.
- **Intentional limits:** This is observation only. It does not reserve space, create a backup/snapshot, delete objects, trigger cleanup, establish capacity, or replace POC/load evidence.
