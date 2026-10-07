package aggregate

import (
	"sync"
	"time"

	"go.opentelemetry.io/otel/metric"
)

type Metrics struct {
	hist                                 map[string]metric.Float64Histogram
	reports, fields, quality, adaptation metric.Int64Counter
	mu                                   sync.Mutex
	latest                               map[string]receipt
	now                                  func() time.Time
}

func New(meter metric.Meter) *Metrics {
	m := &Metrics{hist: map[string]metric.Float64Histogram{}, latest: map[string]receipt{}, now: time.Now}
	definitions := map[string][]float64{
		"fps":        {0, 1, 5, 15, 24, 30, 45, 55, 60, 90, 120, 240},
		"target_fps": {15, 30, 60}, "fps_target_ratio": {0, .25, .5, .75, .9, 1, 1.25, 2},
		"resolution_pixels":               {360, 480, 720, 1080, 1440, 2160, 4320, 8192},
		"resolution_target_ratio":         {0, .25, .5, .75, .9, 1, 1.25, 2},
		"bitrate_kbps":                    {0, 100, 300, 1000, 2000, 4000, 8000, 16000, 32000, 100000},
		"rtt_milliseconds":                {0, 10, 25, 50, 100, 200, 500, 1000, 5000, 60000},
		"jitter_milliseconds":             {0, 1, 5, 10, 20, 50, 100, 500, 1000, 60000},
		"packet_loss_percent":             {0, .1, .5, 1, 2, 5, 10, 25, 50, 100},
		"packet_loss_window_milliseconds": {9000, 10000, 11000, 12000},
		"dropped_frames":                  {0, 1, 5, 10, 100, 1000, 10000, 100000, 1000000000},
		"sample_age_milliseconds":         {0, 100, 500, 1000, 2500, 5000, 10000, 15000},
	}
	for name, buckets := range definitions {
		m.hist[name], _ = meter.Float64Histogram("boohtacord_media_"+name,
			metric.WithDescription("Anonymous client report distribution; not SFU or hardware truth."),
			metric.WithExplicitBucketBoundaries(buckets...))
	}
	m.reports, _ = meter.Int64Counter("boohtacord_media_reports")
	m.fields, _ = meter.Int64Counter("boohtacord_media_field_reports")
	m.quality, _ = meter.Int64Counter("boohtacord_media_connection_quality_reports")
	m.adaptation, _ = meter.Int64Counter("boohtacord_media_adaptation_reports")
	m.registerFreshness(meter)
	return m
}
