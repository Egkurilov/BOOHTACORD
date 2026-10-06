package ingestclienttraces

import (
	"bytes"
	collectortrace "go.opentelemetry.io/proto/otlp/collector/trace/v1"
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	tracepb "go.opentelemetry.io/proto/otlp/trace/v1"
	"time"
	causal "voice-platform/backend/internal/observability/causal_reference"
)

func verifiedLinks(input, output *collectortrace.ExportTraceServiceRequest, secret, account string) {
	for _, resource := range input.ResourceSpans {
		for _, scope := range resource.ScopeSpans {
			for _, span := range scope.Spans {
				if !versioned(span) {
					continue
				}
				for _, link := range span.Links {
					if link == nil {
						continue
					}
					var proof string
					for _, attr := range link.Attributes {
						if attr != nil && attr.Key == "app.causal.ref" {
							proof = attr.Value.GetStringValue()
						}
					}
					cause, ok := causal.Verify(secret, account, proof, time.Now())
					if !ok {
						continue
					}
					tid, sid := cause.IDs()
					if !bytes.Equal(tid, link.TraceId) || !bytes.Equal(sid, link.SpanId) {
						continue
					}
					for _, clean := range output.ResourceSpans[0].ScopeSpans[0].Spans {
						if bytes.Equal(clean.TraceId, span.TraceId) && bytes.Equal(clean.SpanId, span.SpanId) && len(clean.Links) < 8 {
							attrs := []*commonpb.KeyValue{flowAttrValue("app.provenance", "server_confirmed")}
							if cause.FlowID != "" {
								attrs = append(attrs, flowAttrValue("app.cause.flow.id", cause.FlowID))
							}
							clean.Links = append(clean.Links, &tracepb.Span_Link{TraceId: tid, SpanId: sid, Attributes: attrs})
						}
					}
				}
			}
		}
	}
}
