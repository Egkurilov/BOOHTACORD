package httpmetrics

import (
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

type clientUpdateMetrics struct {
	checks      *prometheus.CounterVec
	reloads     *prometheus.CounterVec
	valid       prometheus.Gauge
	lastSuccess prometheus.Gauge
	revision    prometheus.Gauge
}

func newClientUpdateMetrics() *clientUpdateMetrics {
	return &clientUpdateMetrics{
		checks:      prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_client_update_checks_total", Help: "Public client update policy checks by bounded platform and result."}, []string{"platform", "result"}),
		reloads:     prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_client_release_catalog_reload_total", Help: "Client release catalog reload outcomes."}, []string{"result"}),
		valid:       prometheus.NewGauge(prometheus.GaugeOpts{Name: "voice_platform_client_release_catalog_valid", Help: "Whether the last catalog reload was valid."}),
		lastSuccess: prometheus.NewGauge(prometheus.GaugeOpts{Name: "voice_platform_client_release_catalog_last_load_success_timestamp_seconds", Help: "Unix timestamp of the last successful catalog reload."}),
		revision:    prometheus.NewGauge(prometheus.GaugeOpts{Name: "voice_platform_client_release_catalog_revision", Help: "Last accepted client release catalog revision."}),
	}
}

func (recorder *Recorder) ObserveClientUpdateCheck(platform, result string) {
	if platform != "web" && platform != "android" && platform != "ios" && platform != "windows" && platform != "macos" {
		platform = "unknown"
	}
	switch result {
	case "published", "unconfigured", "disabled", "unavailable", "invalid":
	default:
		result = "unknown"
	}
	recorder.clientUpdates.checks.WithLabelValues(platform, result).Inc()
}

func (recorder *Recorder) ObserveClientUpdateCatalogReload(result string, revision int) {
	if result != "success" {
		result = "failure"
	}
	recorder.clientUpdates.reloads.WithLabelValues(result).Inc()
	if result == "success" {
		recorder.clientUpdates.valid.Set(1)
		recorder.clientUpdates.lastSuccess.Set(float64(time.Now().Unix()))
		recorder.clientUpdates.revision.Set(float64(revision))
	} else {
		recorder.clientUpdates.valid.Set(0)
	}
}
