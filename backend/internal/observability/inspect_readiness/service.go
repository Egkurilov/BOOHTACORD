package inspectreadiness

import (
	"context"
	"time"
	reserve "voice-platform/backend/internal/storage/reserve_upload_space"
)

func (s *Service) Inspect(ctx context.Context) Result {
	database := s.databaseProbe.run(ctx, func(ctx context.Context) Probe {
		pending, err := s.database.Inspect(ctx)
		if err != nil || pending < 0 {
			return Probe{Status: "failed", Reason: "database_unavailable"}
		}
		return Probe{Status: "ready", PendingRevocations: &pending}
	})
	sfu := s.sfuProbe.run(ctx, func(ctx context.Context) Probe {
		if s.sfu.Ping(ctx) != nil {
			return Probe{Status: "failed", Reason: "sfu_unavailable"}
		}
		return Probe{Status: "ready"}
	})
	storage := s.storageProbe.run(ctx, s.inspectStorage)
	status := "ready"
	if database.Status != "ready" || sfu.Status != "ready" || storage.Status != "ready" {
		status = "degraded"
	}
	return Result{Status: status, CheckedAt: time.Now().UTC(), Database: database, SFU: sfu, Storage: storage}
}
func (s *Service) inspectStorage(ctx context.Context) Probe {
	snapshot, err := s.space.Snapshot(ctx)
	if err != nil {
		return Probe{Status: "failed", Reason: "statfs_unavailable"}
	}
	reserved := s.reserved()
	if snapshot.TotalBytes <= 0 || snapshot.AvailableBytes < 0 || snapshot.AvailableBytes > snapshot.TotalBytes || reserved < 0 {
		return Probe{Status: "unknown", Reason: "invalid_measurement"}
	}
	protected := snapshot.TotalBytes / 10
	if snapshot.TotalBytes%10 != 0 {
		protected++
	}
	if protected < reserve.MinimumFreeBytes {
		protected = reserve.MinimumFreeBytes
	}
	if reserved > 1<<63-1-protected {
		return Probe{Status: "unknown", Reason: "invalid_measurement"}
	}
	headroom := snapshot.AvailableBytes - protected - reserved
	result := Probe{Status: "ready", AvailableBytes: &snapshot.AvailableBytes, TotalBytes: &snapshot.TotalBytes, ReservedBytes: &reserved, ProtectedBytes: &protected, HeadroomBytes: &headroom}
	if headroom < reserve.MaxAttachmentBytes {
		result.Status = "failed"
		result.Reason = "insufficient_space"
	}
	return result
}
