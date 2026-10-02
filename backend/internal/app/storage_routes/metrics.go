package storageroutes

import (
	"context"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	reserve "voice-platform/backend/internal/storage/reserve_upload_space"
)

type attachmentFilesystemMetricSource struct {
	space   reserve.Space
	manager *reserve.Manager
}

func (source attachmentFilesystemMetricSource) Snapshot(context context.Context) (httpmetrics.AttachmentFilesystemSnapshot, error) {
	snapshot, err := source.space.Snapshot(context)
	return httpmetrics.AttachmentFilesystemSnapshot{AvailableBytes: snapshot.AvailableBytes, TotalBytes: snapshot.TotalBytes}, err
}

func (source attachmentFilesystemMetricSource) ReservedBytes() int64 {
	return source.manager.ReservedBytes()
}
