package observeincidents

import (
	"github.com/prometheus/client_golang/prometheus"
	"time"
)

var Default = New()

type Metrics struct {
	export                   *exports
	now                      func() time.Time
	total                    *prometheus.CounterVec
	duration                 *prometheus.HistogramVec
	attempt, success, result *prometheus.GaugeVec
	enabled                  *prometheus.GaugeVec
}

func New() *Metrics {
	return &Metrics{export: newExports(),
		now:      time.Now,
		enabled:  prometheus.NewGaugeVec(prometheus.GaugeOpts{Name: "voice_platform_incident_enabled", Help: "Whether a fixed exporter is configured; zero is intentionally disabled."}, []string{"operation"}),
		total:    prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_incident_operations_total", Help: "Fixed operational attempts by bounded outcome."}, []string{"operation", "outcome"}),
		duration: prometheus.NewHistogramVec(prometheus.HistogramOpts{Name: "voice_platform_incident_operation_duration_seconds", Help: "Fixed operational attempt latency including failures."}, []string{"operation", "outcome"}),
		attempt:  prometheus.NewGaugeVec(prometheus.GaugeOpts{Name: "voice_platform_incident_last_attempt_timestamp_seconds", Help: "Latest attempt; absent means not observed."}, []string{"operation"}),
		success:  prometheus.NewGaugeVec(prometheus.GaugeOpts{Name: "voice_platform_incident_last_success_timestamp_seconds", Help: "Latest successful attempt; absent means no successful observation."}, []string{"operation"}),
		result:   prometheus.NewGaugeVec(prometheus.GaugeOpts{Name: "voice_platform_incident_last_successful", Help: "Whether latest attempt succeeded; absent means not observed."}, []string{"operation"}),
	}
}
func (m *Metrics) Observe(operation string, elapsed time.Duration, err error) {
	if !allowed(operation) {
		return
	}
	outcome := Outcome(err)
	at := float64(m.now().Unix())
	m.export.observe(operation, outcome, elapsed, at)
	m.total.WithLabelValues(operation, outcome).Inc()
	m.duration.WithLabelValues(operation, outcome).Observe(elapsed.Seconds())
	m.attempt.WithLabelValues(operation).Set(at)
	result := 0.
	if err == nil {
		result = 1
		m.success.WithLabelValues(operation).Set(at)
	}
	m.result.WithLabelValues(operation).Set(result)
}
func (m *Metrics) Describe(c chan<- *prometheus.Desc) {
	m.total.Describe(c)
	m.duration.Describe(c)
	m.attempt.Describe(c)
	m.success.Describe(c)
	m.result.Describe(c)
	m.enabled.Describe(c)
	c <- staleDescription
}
func (m *Metrics) Collect(c chan<- prometheus.Metric) {
	m.total.Collect(c)
	m.duration.Collect(c)
	m.attempt.Collect(c)
	m.success.Collect(c)
	m.result.Collect(c)
	m.enabled.Collect(c)
	m.collectStale(c)
}
