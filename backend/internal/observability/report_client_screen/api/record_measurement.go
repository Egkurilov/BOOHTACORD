package reportscreenapi

import (
	"go.opentelemetry.io/otel/attribute"
	"voice-platform/backend/internal/observability/report_client_screen/measurement"
)

func measurementAttributes(r measurement.Report) []attribute.KeyValue {
	attrs := []attribute.KeyValue{}
	for key, value := range r.Numbers() {
		if value != nil {
			attrs = append(attrs, attribute.Float64("media."+key, *value))
		}
	}
	for key, value := range r.Enums() {
		if value != "" {
			attrs = append(attrs, attribute.String("media."+key, value))
		}
	}
	if r.FreezeCount != nil {
		attrs = append(attrs, attribute.Int64("media.freeze_count", *r.FreezeCount))
	}
	return attrs
}
