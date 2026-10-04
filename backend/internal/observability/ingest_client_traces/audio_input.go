package ingestclienttraces

import (
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	tracepb "go.opentelemetry.io/proto/otlp/trace/v1"
)

// Only this outcome span keeps attributes, with a closed value vocabulary.
func audioInputAttributes(span *tracepb.Span, platform string) []*commonpb.KeyValue {
	if span.Name != "audio.input.switch" {
		return nil
	}
	values := map[string]string{"platform": platform}
	for _, attr := range span.Attributes {
		if attr == nil || attr.Value == nil {
			continue
		}
		value := attr.Value.GetStringValue()
		if attr.Key == "phase" && (value == "prejoin" || value == "active" || value == "reconnect") {
			values["phase"] = value
		}
		if attr.Key == "result" && (value == "success" || value == "fallback" || value == "error") {
			values["result"] = value
		}
	}
	var attributes []*commonpb.KeyValue
	for _, key := range []string{"platform", "phase", "result"} {
		if value, ok := values[key]; ok {
			attributes = append(attributes, &commonpb.KeyValue{Key: key, Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: value}}})
		}
	}
	return attributes
}
