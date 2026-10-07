package ingestclienttraces

import (
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	"testing"
)

func TestMediaIntervalsSurviveRelayWithoutPrivateLayerIDs(t *testing.T) {
	span := flowSpan()
	span.Name = "media.sample"
	span.Attributes = append(span.Attributes, flowAttr("app.media.direction", "sender"),
		flowAttr("app.media.stats_source", "webrtc_interval"), flowAttr("app.media.collection_state", "active"),
		flowAttr("rid", "private-layer"),
		&commonpb.KeyValue{Key: "app.media.stats_window_ms", Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_DoubleValue{DoubleValue: 1000}}},
		&commonpb.KeyValue{Key: "app.media.selected_layer_bitrate_kbps", Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_DoubleValue{DoubleValue: 1800}}})
	output, result := sanitizeBatch(flowBatch(span), "web", "11111111111111111111111111111111", "verified")
	if result.Accepted != 1 || result.Rejected != 0 {
		t.Fatal(result)
	}
	fields := map[string]any{}
	for _, attr := range output.ResourceSpans[0].ScopeSpans[0].Spans[0].Attributes {
		fields[attr.Key] = attributeValue(attr.Value)
	}
	if fields["app.media.selected_layer_bitrate_kbps"] != 1800.0 || fields["app.media.stats_window_ms"] != 1000.0 || fields["rid"] != nil || fields["user.id"] != "verified" {
		t.Fatal("relay omitted safe measurement or leaked identity")
	}
	for _, attr := range span.Attributes {
		if attr.Key == "app.media.stats_source" {
			attr.Value = &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "unsupported"}}
		}
	}
	_, result = sanitizeBatch(flowBatch(span), "web", "11111111111111111111111111111111", "verified")
	if result.Accepted != 0 || result.Rejected != 1 {
		t.Fatal("unsupported source accepted fabricated interval")
	}
}
