package observedependencies

import (
	"context"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"sync"
	presence "voice-platform/backend/internal/media/snapshot_livekit_presence"
)

var snapshotMu sync.Mutex
var lastSnapshot *presence.Snapshot

func init() {
	meter := otel.Meter("boohtacord/dependencies")
	gauge, _ := meter.Int64ObservableGauge("boohtacord.incident.livekit.snapshot", metric.WithDescription("Last good on-demand LiveKit snapshot; gate with livekit_snapshot freshness and result."))
	_, _ = meter.RegisterCallback(func(ctx context.Context, o metric.Observer) error {
		snapshotMu.Lock()
		defer snapshotMu.Unlock()
		if lastSnapshot != nil {
			for stat, value := range map[string]int{"participants": lastSnapshot.Participants, "streams": lastSnapshot.Streams, "screen_streams": lastSnapshot.ScreenStreams} {
				o.ObserveInt64(gauge, int64(value), metric.WithAttributes(attribute.String("stat", stat)))
			}
		}
		return nil
	}, gauge)
}
func ExportSnapshot(snapshot presence.Snapshot) {
	snapshotMu.Lock()
	defer snapshotMu.Unlock()
	lastSnapshot = &snapshot
}
