package httpmetrics

import (
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

type voiceRosterMetrics struct {
	snapshots *prometheus.CounterVec
	failures  *prometheus.CounterVec
	duration  prometheus.Histogram
	rooms     prometheus.Histogram
}

func newVoiceRosterMetrics() *voiceRosterMetrics {
	return &voiceRosterMetrics{
		snapshots: prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_voice_roster_snapshots_total", Help: "SFU roster snapshot attempts by outcome."}, []string{"outcome"}),
		failures:  prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_voice_roster_failures_total", Help: "Voice roster load failures by bounded processing stage; no IDs or error text are recorded."}, []string{"stage"}),
		duration:  prometheus.NewHistogram(prometheus.HistogramOpts{Name: "voice_platform_voice_roster_snapshot_seconds", Help: "SFU roster snapshot latency, excluding database ACL checks."}),
		rooms:     prometheus.NewHistogram(prometheus.HistogramOpts{Name: "voice_platform_voice_roster_requested_rooms", Help: "Visible room count requested from SFU per roster snapshot."}),
	}
}

func (recorder *Recorder) ObserveVoiceRosterFailure(stage string) {
	switch stage {
	case "visibility_initial", "presence_snapshot", "visibility_recheck":
	default:
		stage = "unknown"
	}
	recorder.roster.failures.WithLabelValues(stage).Inc()
}

func (recorder *Recorder) ObserveVoiceRosterSnapshot(duration time.Duration, requestedRooms int, failed bool) {
	outcome := "success"
	if failed {
		outcome = "failure"
	}
	recorder.roster.snapshots.WithLabelValues(outcome).Inc()
	recorder.roster.duration.Observe(duration.Seconds())
	recorder.roster.rooms.Observe(float64(requestedRooms))
}
