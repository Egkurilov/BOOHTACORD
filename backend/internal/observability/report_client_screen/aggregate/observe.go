package aggregate

import (
	"context"
	"math"

	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
)

func labels(s Sample) []attribute.KeyValue {
	return []attribute.KeyValue{attribute.String("platform", s.Platform), attribute.String("direction", s.Direction), attribute.String("source", "client_report")}
}

func (m *Metrics) Observe(ctx context.Context, s Sample) {
	if !s.bounded() {
		return
	}
	age := s.ageClass()
	base := append(labels(s), attribute.String("state", state(s.State)))
	m.reports.Add(ctx, 1, metric.WithAttributes(append(base, attribute.String("freshness", age))...))
	m.remember(s)
	if number(s.Age, 15000) {
		m.hist["sample_age_milliseconds"].Record(ctx, *s.Age, metric.WithAttributes(base...))
	}
	attrs := append(base, attribute.String("age_provenance", "known"))
	if age == "legacy" {
		attrs[len(attrs)-1] = attribute.String("age_provenance", "legacy")
	}
	observe := func(name string, value *float64, max float64, extra ...attribute.KeyValue) {
		status := "missing"
		if number(value, max) {
			status = "present"
		}
		if age == "stale" && status == "present" {
			status = "stale"
		}
		fieldAttrs := append(labels(s), attribute.String("field", name), attribute.String("availability", status))
		m.fields.Add(ctx, 1, metric.WithAttributes(append(fieldAttrs, extra...)...))
		if status == "present" {
			m.hist[name].Record(ctx, *value, metric.WithAttributes(append(attrs, extra...)...))
		}
	}
	for stage, value := range map[string]*float64{"encoded": s.Encoded, "decoded": s.Decoded, "presented": s.Presented} {
		if (s.Direction == "sender") != (stage == "encoded") {
			continue
		}
		a := attribute.String("stage", stage)
		observe("fps", value, 240, a)
		if number(value, 240) && number(s.TargetFPS, 60) && *s.TargetFPS > 0 {
			ratio := *value / *s.TargetFPS
			observe("fps_target_ratio", &ratio, 16, a)
		} else {
			observe("fps_target_ratio", nil, 16, a)
		}
	}
	observe("target_fps", s.TargetFPS, 60)
	observe("bitrate_kbps", s.Bitrate, 100000)
	observe("rtt_milliseconds", s.RTT, 60000)
	observe("jitter_milliseconds", s.Jitter, 60000)
	loss := s.Loss
	window := s.LossWindow
	if !number(s.LossWindow, 12000) || *s.LossWindow < 9000 {
		loss = nil
		window = nil
	}
	observe("packet_loss_percent", loss, 100)
	observe("packet_loss_window_milliseconds", window, 12000)
	if s.Dropped != nil && *s.Dropped >= 0 && *s.Dropped <= 1000000000 {
		v := float64(*s.Dropped)
		observe("dropped_frames", &v, 1000000000)
	} else {
		observe("dropped_frames", nil, 1000000000)
	}
	observe("resolution_pixels", s.TargetResolution, 1440, attribute.String("role", "target"))
	if s.Width != nil && s.Height != nil && *s.Width > 0 && *s.Height > 0 && *s.Width <= 8192 && *s.Height <= 8192 {
		v := math.Min(float64(*s.Width), float64(*s.Height))
		observe("resolution_pixels", &v, 8192, attribute.String("role", "actual_short_edge"))
		if number(s.TargetResolution, 1440) && *s.TargetResolution > 0 {
			ratio := v / *s.TargetResolution
			observe("resolution_target_ratio", &ratio, 12)
		} else {
			observe("resolution_target_ratio", nil, 12)
		}
	} else {
		observe("resolution_pixels", nil, 8192, attribute.String("role", "actual_short_edge"))
		observe("resolution_target_ratio", nil, 12)
	}
	if age != "stale" {
		m.quality.Add(ctx, 1, metric.WithAttributes(append(attrs, attribute.String("quality", quality(s.Quality)))...))
		m.adaptation.Add(ctx, 1, metric.WithAttributes(append(attrs, attribute.String("reason", adaptation(s.Adaptation)))...))
	}
}
