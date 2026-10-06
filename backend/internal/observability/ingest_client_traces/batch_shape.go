package ingestclienttraces

import (
	"bytes"
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	tracepb "go.opentelemetry.io/proto/otlp/trace/v1"
	"time"
)

func validShape(span *tracepb.Span, now time.Time) bool {
	if span == nil || len(span.TraceId) != 16 || len(span.SpanId) != 8 || bytes.Equal(span.TraceId, make([]byte, 16)) || bytes.Equal(span.SpanId, make([]byte, 8)) {
		return false
	}
	if len(span.ParentSpanId) != 0 && len(span.ParentSpanId) != 8 {
		return false
	}
	for _, event := range span.Events {
		if event == nil || len(event.Attributes) > 32 {
			return false
		}
	}
	for _, link := range span.Links {
		if link == nil || len(link.Attributes) > 8 {
			return false
		}
	}
	start, end := span.StartTimeUnixNano, span.EndTimeUnixNano
	instant := uint64(now.UnixNano())
	return len(span.Attributes) <= 32 && len(span.Events) <= 8 && len(span.Links) <= 8 && start > 0 && end >= start && end-start <= uint64(10*time.Minute) && start >= instant-uint64(24*time.Hour) && end <= instant+uint64(time.Minute)
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
