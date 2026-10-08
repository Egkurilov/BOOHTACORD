package rosterstreammetrics

import (
	"context"
	"github.com/prometheus/client_golang/prometheus"
	"time"
)

type Metrics struct {
	classes     *failureClasses
	fresh       *freshness
	gate        *gateMetrics
	snapshot    *snapshotExports
	export      *exports
	active      prometheus.Gauge
	initial     *prometheus.CounterVec
	initialTime prometheus.Histogram
	closed      *prometheus.CounterVec
	calls       *prometheus.HistogramVec
}

func New(registry *prometheus.Registry) *Metrics {
	m := &Metrics{classes: newFailureClasses(registry), fresh: newFreshness(registry), gate: newGateMetrics(registry), snapshot: newSnapshotExports(), export: newExports(),
		active:      prometheus.NewGauge(prometheus.GaugeOpts{Name: "voice_platform_voice_roster_streams_active", Help: "Open authorized SSE roster streams."}),
		initial:     prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_voice_roster_initial_total", Help: "Initial roster attempts by bounded result."}, []string{"outcome"}),
		initialTime: prometheus.NewHistogram(prometheus.HistogramOpts{Name: "voice_platform_voice_roster_initial_seconds", Help: "Initial roster latency including ACL and SFU."}),
		closed:      prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_voice_roster_stream_ends_total", Help: "Roster SSE closes by bounded reason."}, []string{"reason"}),
		calls:       prometheus.NewHistogramVec(prometheus.HistogramOpts{Name: "voice_platform_sfu_room_service_seconds", Help: "RoomService transport latency by bounded method/outcome."}, []string{"method", "outcome"}),
	}
	registry.MustRegister(m.active, m.initial, m.initialTime, m.closed, m.calls)
	for _, outcome := range []string{"success", "failure", "canceled"} {
		m.initial.WithLabelValues(outcome).Add(0)
	}
	m.export.active.Add(context.Background(), 0)
	return m
}

func (m *Metrics) Initial(elapsed time.Duration, outcome string) {
	switch outcome {
	case "success", "failure", "canceled":
	default:
		outcome = "failure"
	}
	m.export.initialAttempt(elapsed, outcome)
	m.initial.WithLabelValues(outcome).Inc()
	m.initialTime.Observe(elapsed.Seconds())
}
func (m *Metrics) Open() { m.active.Inc(); m.export.active.Add(context.Background(), 1) }
func (m *Metrics) Close(reason string) {
	switch reason {
	case "canceled", "session_expired", "session_store", "snapshot", "write":
	default:
		reason = "other"
	}
	m.export.close(reason)
	m.active.Dec()
	m.closed.WithLabelValues(reason).Inc()
}
func (m *Metrics) Call(method, outcome string, elapsed time.Duration) {
	if method != "ListRooms" && method != "ListParticipants" {
		method = "other"
	}
	switch outcome {
	case "success", "error", "transport_error", "http_error", "timeout", "canceled", "overload":
	default:
		outcome = "error"
	}
	m.export.call(method, outcome, elapsed)
	m.fresh.call(method, outcome)
	m.calls.WithLabelValues(method, outcome).Observe(elapsed.Seconds())
}
