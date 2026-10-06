package flowstage

import (
	"context"
	"errors"
	"go.opentelemetry.io/otel"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"go.opentelemetry.io/otel/trace"
	"testing"
)

func TestStorageReplayRemainsCommittedWhenNotificationFails(t *testing.T) {
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	old := otel.GetTracerProvider()
	otel.SetTracerProvider(provider)
	t.Cleanup(func() { otel.SetTracerProvider(old) })
	ctx, parent := provider.Tracer("test").Start(context.Background(), "message.send")
	ctx, store := Begin(ctx, "message.store", "dependency")
	Storage(ctx, "replayed")
	End(store, nil)
	Mark(ctx, "dispatch", "failed")
	ctx, dispatch := Begin(ctx, "message.dispatch", "dispatch")
	denied := errors.New("synthetic permission denial")
	End(dispatch, denied, Reject(denied, "permission_denied"))
	parent.End()
	spans := recorder.Ended()
	if len(spans) != 3 {
		t.Fatal(len(spans))
	}
	attrs := map[string]string{}
	for _, a := range spans[0].Attributes() {
		attrs[string(a.Key)] = a.Value.AsString()
	}
	if attrs["app.storage.result"] != "replayed" || attrs["app.flow.outcome"] != "success" {
		t.Fatal(attrs)
	}
	if spans[0].Parent().SpanID() != parent.SpanContext().SpanID() {
		t.Fatal("store detached from user flow")
	}
	attrs = map[string]string{}
	for _, a := range spans[1].Attributes() {
		attrs[string(a.Key)] = a.Value.AsString()
	}
	if attrs["app.flow.outcome"] != "rejected" || attrs["app.flow.reason"] != "permission_denied" {
		t.Fatal(attrs)
	}
	if trace.SpanFromContext(ctx).SpanContext().TraceID() != parent.SpanContext().TraceID() {
		t.Fatal("request context contaminated")
	}
}
