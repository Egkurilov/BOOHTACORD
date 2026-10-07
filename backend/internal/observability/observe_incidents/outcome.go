package observeincidents

import (
	"context"
	"errors"
	"net"
	"time"
)

func Outcome(err error) string {
	if err == nil {
		return "success"
	}
	if errors.Is(err, context.DeadlineExceeded) {
		return "timeout"
	}
	if errors.Is(err, context.Canceled) {
		return "canceled"
	}
	var timeout net.Error
	if errors.As(err, &timeout) && timeout.Timeout() {
		return "timeout"
	}
	return "failure"
}
func allowed(operation string) bool {
	switch operation {
	case "livekit_probe", "storage_probe", "livekit_snapshot", "storage_snapshot", "livekit_list_rooms", "livekit_list_participants", "livekit_other", "livekit_remove", "trace_export", "metric_export", "relay_export", "lease_notification_worker", "channel_finalization_worker", "sfu_revocation_worker", "realtime_journal":
		return true
	default:
		return false
	}
}
func Observe(operation string, started time.Time, err error) {
	Default.Observe(operation, time.Since(started), err)
}

func staleAfter(operation string) time.Duration {
	switch operation {
	case "livekit_probe", "storage_probe", "lease_notification_worker", "channel_finalization_worker", "sfu_revocation_worker":
		return 45 * time.Second
	case "trace_export", "metric_export":
		return 180 * time.Second
	default:
		return 5 * time.Minute
	}
}
