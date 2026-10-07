package ingestclienttraces

import (
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	tracepb "go.opentelemetry.io/proto/otlp/trace/v1"
	flow "voice-platform/backend/internal/observability/flow_contract"
	"voice-platform/backend/internal/observability/report_client_screen/measurement"
)

func attributeValue(value *commonpb.AnyValue) any {
	if value == nil {
		return nil
	}
	switch v := value.Value.(type) {
	case *commonpb.AnyValue_StringValue:
		return v.StringValue
	case *commonpb.AnyValue_IntValue:
		return v.IntValue
	case *commonpb.AnyValue_DoubleValue:
		return v.DoubleValue
	}
	return nil
}
func spanField(span *tracepb.Span, key string) any {
	for _, attr := range span.Attributes {
		if attr != nil && attr.Key == key {
			return attributeValue(attr.Value)
		}
	}
	return nil
}
func versioned(span *tracepb.Span) bool { return spanField(span, "app.schema.version") != nil }
func cleanFlow(span *tracepb.Span, sessionID, accountID string) ([]*commonpb.KeyValue, bool) {
	for _, key := range []string{"app.schema.version", "session.id", "app.visit.id", "app.flow.id", "app.flow.name", "app.flow.stage", "app.flow.record", "app.flow.outcome", "app.flow.attempt"} {
		if !flow.Valid(key, spanField(span, key)) {
			return nil, false
		}
	}
	clean := []*commonpb.KeyValue{}
	seen := map[string]bool{}
	mediaFields := map[string]any{}
	for _, attr := range span.Attributes {
		if attr == nil || seen[attr.Key] {
			return nil, false
		}
		seen[attr.Key] = true
		if attr.Key == "app.provenance" || attr.Key == "app.media.source" || attr.Key == "app.storage.result" {
			continue
		}
		if flow.Valid(attr.Key, attributeValue(attr.Value)) {
			clean = append(clean, attr)
			mediaFields[attr.Key] = attributeValue(attr.Value)
		} else if _, known := flow.Fields[attr.Key]; known {
			return nil, false
		}
	}
	direction, _ := spanField(span, "app.media.direction").(string)
	if !measurement.FlowValid(direction, mediaFields) {
		return nil, false
	}
	clean = append(clean, flowAttrValue("app.provenance", "client_observed"), flowAttrValue("user.id", accountID))
	if spanField(span, "app.media.source") == "presentation" {
		clean = append(clean, flowAttrValue("app.media.source", "presentation"))
	} else if spanField(span, "app.media.source") != nil {
		clean = append(clean, flowAttrValue("app.media.source", "webrtc"))
	}
	if len(clean) > 32 {
		return nil, false
	}
	return clean, true
}
func flowAttrValue(key, value string) *commonpb.KeyValue {
	return &commonpb.KeyValue{Key: key, Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: value}}}
}
