package dispatchvoicesfurevocation

import (
	"context"
	"go.opentelemetry.io/otel"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"strings"
	"testing"
	"time"
	cause "voice-platform/backend/internal/observability/causal_reference"
)

func TestWorkerRetryUsesDurableOriginalLinkAndNoCredentials(t *testing.T) {
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	previous := otel.GetTracerProvider()
	otel.SetTracerProvider(provider)
	defer otel.SetTracerProvider(previous)
	defer provider.Shutdown(context.Background())
	c := cause.Cause{TraceID: strings.Repeat("1", 32), SpanID: strings.Repeat("2", 16), FlowID: strings.Repeat("3", 32), Version: 1}
	item := testItem
	item.TraceCause = c.Bytes()
	item.RequestedAt = time.Now().Add(-time.Second)
	item.Attempt = 2
	store := &fakeStore{items: []Item{item}}
	result, err := New(store, removerFunc(func(context.Context, string, string) error { return nil })).Dispatch(context.Background(), 1)
	if err != nil || result.Confirmed != 1 {
		t.Fatal(result, err)
	}
	span := recorder.Ended()[0]
	if len(span.Links()) != 1 || span.Links()[0].SpanContext.TraceID().String() != c.TraceID || span.Parent().IsValid() {
		t.Fatal("worker not linked to original cause")
	}
	item.TraceCause = []byte("invalid")
	if _, err := New(&fakeStore{items: []Item{item}}, removerFunc(func(context.Context, string, string) error { return nil })).Dispatch(context.Background(), 1); err != nil {
		t.Fatal("diagnostics blocked business")
	}
}
