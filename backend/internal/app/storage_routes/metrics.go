package storageroutes

import (
	"context"
	"errors"
	"time"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	incident "voice-platform/backend/internal/observability/observe_incidents"
	reserve "voice-platform/backend/internal/storage/reserve_upload_space"
)

type attachmentFilesystemMetricSource struct {
	space   reserve.Space
	manager *reserve.Manager
}

func (source attachmentFilesystemMetricSource) Snapshot(context context.Context) (httpmetrics.AttachmentFilesystemSnapshot, error) {
	started := time.Now()
	snapshot, err := source.space.Snapshot(context)
	observedErr := err
	if observedErr == nil {
		observedErr = context.Err()
	}
	if observedErr == nil && (snapshot.AvailableBytes < 0 || snapshot.TotalBytes < 0 || snapshot.AvailableBytes > snapshot.TotalBytes) {
		observedErr = errors.New("invalid snapshot")
	}
	incident.Observe("storage_snapshot", started, observedErr)
	return httpmetrics.AttachmentFilesystemSnapshot{AvailableBytes: snapshot.AvailableBytes, TotalBytes: snapshot.TotalBytes}, err
}

func (source attachmentFilesystemMetricSource) ReservedBytes() int64 {
	return source.manager.ReservedBytes()
}
