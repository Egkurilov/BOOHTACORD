package httpmetrics

import (
	"context"
	"errors"
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

var (
	ErrInvalidVoiceMediaSource     = errors.New("invalid voice media metric source")
	ErrVoiceMediaAlreadyRegistered = errors.New("voice media metric source already registered")
)

type VoiceMediaSnapshot struct{ Participants, Streams, ScreenStreams int }

type VoiceMediaSource interface {
	Snapshot(context.Context) (VoiceMediaSnapshot, error)
}

type voiceMediaCollector struct {
	participants, streams, screenStreams, success *prometheus.Desc
	source                                        VoiceMediaSource
}

func newVoiceMediaCollector(source VoiceMediaSource) voiceMediaCollector {
	return voiceMediaCollector{
		participants:  prometheus.NewDesc("voice_platform_voice_participants_active", "Participants connected to active LiveKit voice rooms at snapshot time.", nil, nil),
		streams:       prometheus.NewDesc("voice_platform_voice_streams_active", "Unmuted audio and video tracks in active LiveKit voice rooms at snapshot time.", nil, nil),
		screenStreams: prometheus.NewDesc("voice_platform_voice_screen_streams_active", "Unmuted screen-share video tracks in active LiveKit voice rooms at snapshot time.", nil, nil),
		success:       prometheus.NewDesc("voice_platform_voice_media_snapshot_success", "Whether the current private LiveKit RoomService snapshot succeeded.", nil, nil),
		source:        source,
	}
}

func (collector voiceMediaCollector) Describe(descriptions chan<- *prometheus.Desc) {
	descriptions <- collector.participants
	descriptions <- collector.streams
	descriptions <- collector.screenStreams
	descriptions <- collector.success
}

func (collector voiceMediaCollector) Collect(metrics chan<- prometheus.Metric) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	snapshot, err := collector.source.Snapshot(ctx)
	if err != nil || ctx.Err() != nil || snapshot.Participants < 0 || snapshot.Streams < 0 || snapshot.ScreenStreams < 0 || snapshot.ScreenStreams > snapshot.Streams {
		metrics <- prometheus.MustNewConstMetric(collector.success, prometheus.GaugeValue, 0)
		return
	}
	metrics <- prometheus.MustNewConstMetric(collector.participants, prometheus.GaugeValue, float64(snapshot.Participants))
	metrics <- prometheus.MustNewConstMetric(collector.streams, prometheus.GaugeValue, float64(snapshot.Streams))
	metrics <- prometheus.MustNewConstMetric(collector.screenStreams, prometheus.GaugeValue, float64(snapshot.ScreenStreams))
	metrics <- prometheus.MustNewConstMetric(collector.success, prometheus.GaugeValue, 1)
}

func (recorder *Recorder) RegisterVoiceMedia(source VoiceMediaSource) error {
	if source == nil {
		return ErrInvalidVoiceMediaSource
	}
	if recorder.voiceMediaRegistered {
		return ErrVoiceMediaAlreadyRegistered
	}
	if err := recorder.registry.Register(newVoiceMediaCollector(source)); err != nil {
		return err
	}
	recorder.voiceMediaRegistered = true
	return nil
}
