package main

import (
	"context"
	"log/slog"
	"os"

	snapshotlivekitpresence "voice-platform/backend/internal/media/snapshot_livekit_presence"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
)

type voiceMediaMetricsSource struct {
	client snapshotlivekitpresence.Client
}

func registerVoiceMediaMetrics(metrics *httpmetrics.Recorder, client snapshotlivekitpresence.Client) {
	if err := metrics.RegisterVoiceMedia(voiceMediaMetricsSource{client: client}); err != nil {
		slog.Error("register livekit media metrics", "error", err)
		os.Exit(1)
	}
}

func (source voiceMediaMetricsSource) Snapshot(ctx context.Context) (httpmetrics.VoiceMediaSnapshot, error) {
	snapshot, err := source.client.Snapshot(ctx)
	if err != nil {
		return httpmetrics.VoiceMediaSnapshot{}, err
	}
	return httpmetrics.VoiceMediaSnapshot{Participants: snapshot.Participants, Streams: snapshot.Streams, ScreenStreams: snapshot.ScreenStreams}, nil
}
