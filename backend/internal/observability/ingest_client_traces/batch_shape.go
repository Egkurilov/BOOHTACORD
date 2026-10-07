package ingestclienttraces

import (
	"bytes"
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	tracepb "go.opentelemetry.io/proto/otlp/trace/v1"
	"time"
	flow "voice-platform/backend/internal/observability/flow_contract"
)

func validShape(span *tracepb.Span, now time.Time) bool {
	if span == nil || len(span.Name) > flow.MaxSpanNameBytes || len(span.TraceId) != 16 || len(span.SpanId) != 8 || bytes.Equal(span.TraceId, make([]byte, 16)) || bytes.Equal(span.SpanId, make([]byte, 8)) {
		return false
	}
	if len(span.ParentSpanId) != 0 && len(span.ParentSpanId) != 8 {
		return false
	}
	for _, event := range span.Events {
		if event == nil || len(event.Name) > flow.MaxSpanNameBytes || !validAttributes(event.Attributes, flow.MaxAttributes) {
			return false
		}
	}
	for _, link := range span.Links {
		if link == nil || !validAttributes(link.Attributes, flow.MaxLinkAttributes) {
			return false
		}
	}
	start, end := span.StartTimeUnixNano, span.EndTimeUnixNano
	instant := uint64(now.UnixNano())
	return validAttributes(span.Attributes, flow.MaxAttributes) && len(span.Events) <= flow.MaxEvents && len(span.Links) <= flow.MaxLinks && start > 0 && end >= start && end-start <= uint64(10*time.Minute) && start >= instant-uint64(24*time.Hour) && end <= instant+uint64(time.Minute)
}
func validAttributes(attributes []*commonpb.KeyValue, maxCount int) bool {
	if len(attributes) > maxCount {
		return false
	}
	for _, attribute := range attributes {
		if attribute == nil || len(attribute.Key) > flow.MaxAttributeKeyBytes {
			return false
		}
		if attribute.Value == nil {
			continue
		}
		switch value := attribute.Value.Value.(type) {
		case *commonpb.AnyValue_StringValue:
			if len(value.StringValue) > flow.MaxAttributeStringBytes {
				return false
			}
		case *commonpb.AnyValue_BytesValue:
			if len(value.BytesValue) > flow.MaxAttributeStringBytes {
				return false
			}
		}
	}
	return true
}
func sameBatchLinks(span *tracepb.Span, spans []*tracepb.Span, sessionID string) []*tracepb.Span_Link {
	links := []*tracepb.Span_Link{}
	for _, link := range span.Links {
		if link == nil {
			continue
		}
		for _, other := range spans {
			if versioned(other) && spanField(other, "session.id") == sessionID && bytes.Equal(other.TraceId, link.TraceId) && bytes.Equal(other.SpanId, link.SpanId) {
				links = append(links, &tracepb.Span_Link{TraceId: bytes.Clone(link.TraceId), SpanId: bytes.Clone(link.SpanId), Attributes: []*commonpb.KeyValue{flowAttrValue("app.provenance", "client_observed")}})
				break
			}
		}
	}
	return links
}
