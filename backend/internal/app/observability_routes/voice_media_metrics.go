package observabilityroutes

import (
	"context"
	"errors"
	"time"
	dependencies "voice-platform/backend/internal/observability/observe_dependencies"
	incident "voice-platform/backend/internal/observability/observe_incidents"

	snapshotlivekitpresence "voice-platform/backend/internal/media/snapshot_livekit_presence"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
)

type voiceMediaMetricsSource struct {
	client snapshotlivekitpresence.Client
}

func RegisterVoiceMediaMetrics(metrics *httpmetrics.Recorder, client snapshotlivekitpresence.Client) error {
	return metrics.RegisterVoiceMedia(voiceMediaMetricsSource{client: client})
}

func (source voiceMediaMetricsSource) Snapshot(ctx context.Context) (httpmetrics.VoiceMediaSnapshot, error) {
	started := time.Now()
	snapshot, err := source.client.Snapshot(ctx)
	observedErr := err
	if observedErr == nil {
		observedErr = ctx.Err()
	}
	if observedErr == nil && (snapshot.Participants < 0 || snapshot.Streams < 0 || snapshot.ScreenStreams < 0 || snapshot.ScreenStreams > snapshot.Streams) {
		observedErr = errors.New("invalid snapshot")
	}
	incident.Observe("livekit_snapshot", started, observedErr)
	if err != nil {
		if observedErr == nil {
			dependencies.ExportSnapshot(snapshot)
		}
		return httpmetrics.VoiceMediaSnapshot{}, err
	}
	if observedErr == nil {
		dependencies.ExportSnapshot(snapshot)
	}
	return httpmetrics.VoiceMediaSnapshot{Participants: snapshot.Participants, Streams: snapshot.Streams, ScreenStreams: snapshot.ScreenStreams}, nil
}
