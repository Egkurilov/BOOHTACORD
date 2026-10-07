package observehttprequests

import (
	"github.com/prometheus/client_golang/prometheus"
	"net/http"
	"strconv"
	"time"
)

type Metrics struct {
	export                        exports
	requests, operational         *prometheus.CounterVec
	duration, operationalDuration *prometheus.HistogramVec
}

func New(registry *prometheus.Registry) *Metrics {
	m := &Metrics{export: newExports(),
		requests:            prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_api_requests_total", Help: "Completed requests by bounded method, registered route template and status."}, []string{"method", "route", "status"}),
		duration:            prometheus.NewHistogramVec(prometheus.HistogramOpts{Name: "voice_platform_api_request_duration_seconds", Help: "Completed route latency, including failures.", Buckets: prometheus.DefBuckets}, []string{"method", "route", "status"}),
		operational:         prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_operational_requests_total", Help: "Operational HTTP completions without logs or spans."}, []string{"method", "operation", "status"}),
		operationalDuration: prometheus.NewHistogramVec(prometheus.HistogramOpts{Name: "voice_platform_operational_request_duration_seconds", Help: "Operational HTTP completion duration; streams last until disconnect."}, []string{"method", "operation", "status"}),
	}
	registry.MustRegister(m.requests, m.duration, m.operational, m.operationalDuration)
	return m
}
func (m *Metrics) Observe(r *http.Request, mux *http.ServeMux, status int, elapsed time.Duration) {
	m.ObserveRoute(r, Route(r, mux), status, elapsed)
}
func (m *Metrics) ObserveRoute(r *http.Request, route string, status int, elapsed time.Duration) {
	if status < 100 || status > 599 {
		status = 500
	}
	method, code := Method(r.Method), strconv.Itoa(status)
	m.export.observe(method, route, Operation(r.URL.Path), code, elapsed)
	if operation := Operation(r.URL.Path); operation != "" {
		m.operational.WithLabelValues(method, operation, code).Inc()
		m.operationalDuration.WithLabelValues(method, operation, code).Observe(elapsed.Seconds())
		return
	}
	m.requests.WithLabelValues(method, route, code).Inc()
	m.duration.WithLabelValues(method, route, code).Observe(elapsed.Seconds())
}
