package observabilityroutes

import (
	"context"

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
	snapshot, err := source.client.Snapshot(ctx)
	if err != nil {
		return httpmetrics.VoiceMediaSnapshot{}, err
	}
	return httpmetrics.VoiceMediaSnapshot{Participants: snapshot.Participants, Streams: snapshot.Streams, ScreenStreams: snapshot.ScreenStreams}, nil
}
