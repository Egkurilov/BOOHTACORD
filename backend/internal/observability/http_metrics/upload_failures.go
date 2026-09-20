package httpmetrics

import "github.com/prometheus/client_golang/prometheus"

var uploadFailureReasons = map[string]struct{}{
	"invalid_multipart":    {},
	"too_large":            {},
	"insufficient_storage": {},
	"target_unavailable":   {},
	"internal":             {},
}

type uploadFailureMetrics struct {
	total *prometheus.CounterVec
}

func newUploadFailureMetrics() *uploadFailureMetrics {
	return &uploadFailureMetrics{total: prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "voice_platform_upload_failures_total",
		Help: "Attachment upload failures by bounded outcome.",
	}, []string{"reason"})}
}

func (metrics *uploadFailureMetrics) Observe(reason string) {
	if _, ok := uploadFailureReasons[reason]; !ok {
		reason = "internal"
	}
	metrics.total.WithLabelValues(reason).Inc()
}

func (recorder *Recorder) UploadFailed(reason string) { recorder.uploadFailures.Observe(reason) }
