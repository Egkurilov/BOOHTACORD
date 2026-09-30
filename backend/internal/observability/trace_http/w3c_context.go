package tracehttp

import (
	"context"
	"net/http"
	"strings"

	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/trace"
)

func remoteContext(request *http.Request) context.Context {
	propagator := propagation.TraceContext{}
	extracted := propagator.Extract(request.Context(), propagation.HeaderCarrier(request.Header))
	if trace.SpanContextFromContext(extracted).IsValid() || request.URL.Path != "/api/v1/realtime" || !strings.EqualFold(request.Header.Get("Upgrade"), "websocket") {
		return extracted
	}
	parent := request.URL.Query().Get("traceparent")
	state := request.URL.Query().Get("tracestate")
	if len(parent) != 55 || len(state) > 512 {
		return extracted
	}
	return propagator.Extract(extracted, propagation.MapCarrier{"traceparent": parent, "tracestate": state})
}
