package httpmetrics

import (
	"sort"
	"sync"
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

type ClientScreenSample struct {
	Report       ClientScreenReport `json:"report"`
	SampledAtUTC string             `json:"sampled_at_utc"`
}

type clientScreenMetrics struct {
	mu      sync.Mutex
	latest  map[string]ClientScreenSample
	now     func() time.Time
	total   *prometheus.CounterVec
	fps     *prometheus.HistogramVec
	bitrate *prometheus.HistogramVec
}

func newClientScreenMetrics() *clientScreenMetrics {
	return &clientScreenMetrics{
		latest: make(map[string]ClientScreenSample), now: time.Now,
		total:   prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_client_screen_reports_total", Help: "Authenticated anonymous client screen reports by fixed platform, direction and state."}, []string{"platform", "direction", "state"}),
		fps:     prometheus.NewHistogramVec(prometheus.HistogramOpts{Name: "voice_platform_client_screen_fps", Help: "Client-reported screen FPS; not a hardware capability claim.", Buckets: []float64{0, 1, 5, 10, 15, 24, 30, 45, 60, 90, 120, 240}}, []string{"platform", "direction", "kind"}),
		bitrate: prometheus.NewHistogramVec(prometheus.HistogramOpts{Name: "voice_platform_client_screen_bitrate_kbps", Help: "Client-reported screen bitrate in kilobits per second.", Buckets: []float64{0, 100, 300, 600, 1000, 2000, 4000, 8000, 16000, 32000}}, []string{"platform", "direction"}),
	}
}

func (recorder *Recorder) ObserveClientScreen(report ClientScreenReport) error {
	if err := report.validate(); err != nil {
		return err
	}
	metrics := recorder.clientScreen
	metrics.mu.Lock()
	metrics.latest[report.Platform+":"+report.Direction] = ClientScreenSample{Report: report, SampledAtUTC: metrics.now().UTC().Format(time.RFC3339)}
	metrics.mu.Unlock()
	metrics.total.WithLabelValues(report.Platform, report.Direction, report.State).Inc()
	for kind, value := range map[string]*float64{"encoded": report.EncodedFPS, "decoded": report.DecodedFPS, "presented": report.PresentedFPS} {
		if value != nil {
			metrics.fps.WithLabelValues(report.Platform, report.Direction, kind).Observe(*value)
		}
	}
	if report.BitrateKbps != nil {
		metrics.bitrate.WithLabelValues(report.Platform, report.Direction).Observe(*report.BitrateKbps)
	}
	return nil
}

// ClientScreenSnapshot contains only fresh anonymous samples with fixed-size keys.
func (recorder *Recorder) ClientScreenSnapshot() []ClientScreenSample {
	metrics := recorder.clientScreen
	metrics.mu.Lock()
	defer metrics.mu.Unlock()
	now := metrics.now()
	keys := make([]string, 0, len(metrics.latest))
	for key, sample := range metrics.latest {
		at, err := time.Parse(time.RFC3339, sample.SampledAtUTC)
		if err != nil || now.Sub(at) > time.Minute {
			delete(metrics.latest, key)
			continue
		}
		keys = append(keys, key)
	}
	sort.Strings(keys)
	samples := make([]ClientScreenSample, 0, len(keys))
	for _, key := range keys {
		samples = append(samples, metrics.latest[key])
	}
	return samples
}
